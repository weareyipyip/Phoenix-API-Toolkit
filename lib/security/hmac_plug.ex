defmodule PhoenixApiToolkit.Security.HmacPlug do
  @moduledoc """
  Checks HMAC authentication. Expects a HMAC-<some_algorithm> of the request body to be present in the
  "authorization" header. Supported algorithms are those supported by `:crypto.mac/4`.
  Relies on `PhoenixApiToolkit.CacheBodyReader` being called by `Plug.Parsers`.

  To be considered a valid request by the plug, a request has to meet the following criteria:
   - the request path must match the `"path"` stated in the request body
   - the request HTTP method must match the `"method"` stated in the request body
   - the request `"timestamp"` must not be older than `max_age`

  If the token is invalid for any reason, `PhoenixApiToolkit.Security.HmacVerificationError` is raised,
  resulting in a 401 Unauthorized response.

  ## Configuration options

  - `hmac_secret` as a binary (mandatory): the secret used to create the HMAC
  - `hash_algorithm` as an atom (optional, defaults to `:sha256`) the hashing algorithm used to create the HMAC
  - `max_age` in seconds (optional, defaults to `120`) the maximum age of the request before it is considered invalid

  ## Request body format example

  ```
  {
    "path": "/api/v2/accounts",
    "method": "POST",
    "timestamp": 1321321545,
    "contents": {
      "key1": "value1",
      "something": "else"
    }
  }
  ```

  ## Examples

      use Plug.Test

      alias PhoenixApiToolkit.Security.HmacPlug
      import PhoenixApiToolkit.TestHelpers
      import PhoenixApiToolkit.CacheBodyReader

      @secret "supersecretkey"

      def opts, do: HmacPlug.init(lazy_hmac_secret: fn -> @secret end)

      def conn_for_hmac(method, path, raw_body) do
        conn(method, path, raw_body |> Jason.decode!())
        |> application_json()
        |> put_raw_body(raw_body)
      end

      # a correctly signed request is passed through
      iex> body = create_hmac_plug_body("/", "POST", %{hello: "world"})
      iex> {:ok, _raw_body, conn} = conn_for_hmac(:post, "/", body) |> put_hmac(body, @secret) |> cache_and_read_body()
      iex> conn = HmacPlug.call(conn, opts())
      iex> conn.body_params["contents"]
      %{"hello" => "world"}

      # requests that are noncompliant result in a PhoenixApiToolkit.Security.HmacVerificationError
      iex> body = create_hmac_plug_body("/", "PUT", %{hello: "world"})
      iex> {:ok, _raw_body, conn} = conn_for_hmac(:post, "/", body) |> put_hmac(body, @secret) |> cache_and_read_body()
      iex> HmacPlug.call(conn, opts())
      ** (PhoenixApiToolkit.Security.HmacVerificationError) HMAC invalid: method mismatch

      iex> body = create_hmac_plug_body("/", "POST", %{hello: "world"}, 12345)
      iex> {:ok, _raw_body, conn} = conn_for_hmac(:post, "/", body) |> put_hmac(body, @secret) |> cache_and_read_body()
      iex> HmacPlug.call(conn, opts())
      ** (PhoenixApiToolkit.Security.HmacVerificationError) HMAC invalid: expired
  """
  import Plug.Conn
  alias PhoenixApiToolkit.Security.HmacVerificationError
  alias PhoenixApiToolkit.CacheBodyReader
  alias PhoenixApiToolkit.Internal
  require Logger

  @doc false
  def init(opts) do
    opts = Keyword.new(opts)

    %{
      lazy_hmac_secret: Keyword.fetch!(opts, :lazy_hmac_secret),
      max_age: Keyword.get(opts, :max_age, 120),
      hash_algorithm: Keyword.get(opts, :hash_algorithm, :sha256)
    }
  end

  @doc false
  def call(conn, %{
        lazy_hmac_secret: lazy_hmac_secret,
        max_age: max_age,
        hash_algorithm: hash_algorithm
      }) do
    hmac_secret = lazy_hmac_secret.()

    with hmac <- parse_auth_header(conn),
         body = CacheBodyReader.get_raw_request_body(conn) || "",
         message_hmac = Internal.hmac(hash_algorithm, hmac_secret, body) |> Base.encode64(),
         {:hmac_matches, true} <- {:hmac_matches, Plug.Crypto.secure_compare(hmac, message_hmac)},
         :ok <- verify_method(conn),
         :ok <- verify_path(conn),
         :ok <- verify_timestamp(conn, max_age) do
      conn
    else
      {:hmac_matches, false} ->
        raise HmacVerificationError, "HMAC invalid: hash mismatch"

      error ->
        error |> inspect() |> Logger.error()
        raise HmacVerificationError, "HMAC invalid: unknown error"
    end
  end

  ############
  # Privates #
  ############

  defp parse_auth_header(conn) do
    case get_req_header(conn, "authorization") do
      [hmac] -> hmac
      _ -> raise HmacVerificationError, "HMAC invalid: missing authorization header"
    end
  end

  defp verify_timestamp(%{body_params: body_params}, max_age) do
    with timestamp when is_integer(timestamp) <- body_params["timestamp"],
         true <- timestamp + max_age >= DateTime.utc_now() |> DateTime.to_unix(:second) do
      :ok
    else
      false -> raise HmacVerificationError, "HMAC invalid: expired"
      _ -> raise HmacVerificationError, "HMAC invalid: timestamp missing"
    end
  end

  defp verify_method(%{method: exp_method, body_params: body_params}) do
    with method when not is_nil(method) <- body_params["method"],
         true <- method == exp_method do
      :ok
    else
      false -> raise HmacVerificationError, "HMAC invalid: method mismatch"
      nil -> raise HmacVerificationError, "HMAC invalid: method missing"
    end
  end

  defp verify_path(%{request_path: exp_path, body_params: body_params}) do
    with path when not is_nil(path) <- body_params["path"],
         true <- path == exp_path do
      :ok
    else
      false -> raise HmacVerificationError, "HMAC invalid: path mismatch"
      _ -> raise HmacVerificationError, "HMAC invalid: path missing"
    end
  end
end
