defmodule PhoenixApiToolkit.TestHelpers do
  @moduledoc """
  Various helper functions for writing tests.
  """
  alias Plug.Conn
  require Logger

  if Code.ensure_loaded?(:jose) do
    @doc """
    Returns an example jwks for use by `gen_jwt/2`, as base64-encoded JSON.

    ## Examples

        # the keyset is returned as base64-encoded JSON string with a list of keys
        iex> test_jwks() |> Base.decode64!() |> Jason.decode!() |> List.first() |> Map.get("kid")
        "my_test_key"
    """
    @spec test_jwks :: binary
    def test_jwks() do
      """
      [
        {
          "kty": "RSA",
          "d": "PHxWm6NfF7KucMLkInmy07mPYOCAbd-Kv5Su25dGNYxm3iWqzByIl-CHk-rBdI5lOg7w3QQgXUynjjRSQPpUEx6Na6gokMOeWET-xXVx3MTlSItO_iEx0V_UpY6jrKAxM1Mp-IQOxzwyAAg2SxCgNdhinzpn8Fj-71ezrAfDUfPOWq0hVzvTwcG_mJdbuYbVYh19EXRv3kY-FKssJS8OqoZwSKF6xcmTND8kixXaFZ86fjI9xuh1Nuk-fU7kdO4LHCnAHsi0Vpaou0AfSXHjsM1A31_K79aeV6fP40hzDgLpmHLhN4CywqpI0v4A-8wXlp1474B0Ut8P_QfwWfudoQ",
          "e": "AQAB",
          "use": "sig",
          "kid": "my_test_key",
          "alg": "RS256",
          "n": "oIU4cfgBMV-HSXshwcyocv0pINmgYjDfvaYQpsGkw0o3xv1ttMDS27f31fpQCvIIu7fBWDfzqG9DBzQTVilqIvZVbAD_W0IJGcD7jreqhTI_MC3bQWIePAn5BwK9ONE23V6Q5jK556tsIpBjOGna2fi6Qr__x5236kH7lMNsBqxTK3kNRkrLlKUwni419Jpgh9A5Gl3pfSKjvtEDA3FLaWzUHzuoizUr9VnKwxpe4rKx0boQgxsCteBp1-sOLegRSeYvzK9x3p9XEUxEdUlQw_SiPUKC5XlMfbIWcTrSCR9SztTqa6I6COu3ohdwryna2oPcm2sS4M_T9jfzzb8Nkw"
        }
      ]
      """
      |> Base.encode64()
    end

    @typedoc "Options for use by `gen_jwt/2`"
    @type gen_jwt_opts :: [
            jwk: map(),
            payload: map(),
            jws: map()
          ]

    @typedoc "Defaults for use by `gen_jwt/2`"
    @type gen_jwt_defaults :: %{
            jwk: map(),
            payload: map(),
            jws: map()
          }

    @doc """
    Generate a JSON Web Token for testing purposes, with an "exp" claim 5 minutes in the future.
    It is possible to override parts of the signing key, payload and signature to test with different
    scopes, expiration times, issuers, key ID's etc, override the entire signing key, payload or signature.
    The defaults should generate a valid JWT. For use with endpoints secured with `PhoenixApiToolkit.Security.Oauth2Plug`.

    ## Examples

        @jwt_defaults %{
          jwk: gen_jwk(),
          jws: gen_jws(),
          payload: gen_payload(iss: "http://my-oauth2-provider")
        }

        # the defaults as created above generate a valid JWT, provided that the claims match those verified
        # the header, payload and signature can be inspected using JOSE.JWS.peek* functions
        iex> jwt = gen_jwt(@jwt_defaults)
        iex> jwt |> JOSE.JWS.peek_protected() |> Jason.decode!()
        %{"alg" => "RS256", "kid" => "my_test_key", "typ" => "JWT"}
        iex> jwt |> JOSE.JWS.peek_payload() |> Jason.decode!() |> Map.drop(["exp"])
        %{"iss" => "http://my-oauth2-provider"}

        # parts of the jwk, payload and jws can be overridden for testing purposes
        iex> gen_jwt(@jwt_defaults, payload: [iss: "boom"]) |> JOSE.JWS.peek_payload() |> Jason.decode!() |> Map.drop(["exp"])
        %{"iss" => "boom"}
        iex> gen_jwt(@jwt_defaults, jws: [kid: "other key"]) |> JOSE.JWS.peek_protected() |> Jason.decode!()
        %{"alg" => "RS256", "kid" => "other key", "typ" => "JWT"}
        iex> gen_jwt(@jwt_defaults, payload: [exp: 12345]) |> JOSE.JWS.peek_payload() |> Jason.decode!() |> Map.get("exp")
        12345
    """
    @spec gen_jwt(gen_jwt_defaults, gen_jwt_opts) :: binary
    def gen_jwt(defaults, overrides \\ []) do
      jwk = defaults.jwk |> Map.merge((overrides[:jwk] || []) |> Map.new() |> to_string_map())
      jws = defaults.jws |> Map.merge((overrides[:jws] || []) |> Map.new() |> to_string_map())

      payload =
        defaults.payload
        |> Map.merge(%{"exp" => (DateTime.utc_now() |> DateTime.to_unix(:second)) + 300})
        |> Map.merge((overrides[:payload] || []) |> Map.new() |> to_string_map())

      JOSE.JWT.sign(jwk, jws, payload)
      |> JOSE.JWS.compact()
      |> elem(1)
    end

    @doc """
    Generate a JSON Web Key for testing purposes. See `gen_jwt/2` for details.

    The default is the first key of `test_jwks/0`.

    ## Examples

        iex> gen_jwk()["kid"]
        "my_test_key"

        iex> gen_jwk(kid: "other key")["kid"]
        "other key"
    """
    @spec gen_jwk(map | keyword) :: map
    def gen_jwk(overrides \\ []) do
      Map.merge(
        test_jwks() |> Base.decode64!() |> Jason.decode!() |> List.first(),
        overrides |> Map.new() |> to_string_map()
      )
    end

    @doc """
    Generate a JSON Web Token payload for testing purposes. See `gen_jwt/2` for details.

    The default payload is empty.

    ## Examples

        iex> gen_payload()
        %{}

        iex> gen_payload(iss: "something")["iss"]
        "something"
    """
    @spec gen_payload(map | keyword) :: map
    def gen_payload(overrides \\ []) do
      overrides |> Map.new() |> to_string_map()
    end

    @doc """
    Generate a JSON Web Signature for testing purposes. See `gen_jwt/2` for details.

    The defaults are the "alg" and "kid" values of the first key of `test_jwks/0`.

    ## Examples

    iex> gen_jws()
    %{"alg" => "RS256", "kid" => "my_test_key"}

    iex> gen_jws(alg: "RS512")["alg"]
    "RS512"
    """
    @spec gen_jws(map | keyword) :: map
    def gen_jws(overrides \\ []) do
      default_jwk = test_jwks() |> Base.decode64!() |> Jason.decode!() |> List.first()

      Map.merge(
        %{"alg" => default_jwk["alg"], "kid" => default_jwk["kid"]},
        overrides |> Map.new() |> to_string_map()
      )
    end

    @doc """
    Add JWT to the conn. A valid, signed JWT can be generated by `gen_jwt/2`.

    ## Examples

        use Plug.Test

        iex> conn(:get, "/") |> put_jwt("my_jwt") |> get_req_header("authorization")
        ["Bearer: my_jwt"]
    """
    @spec put_jwt(Conn.t(), binary()) :: Conn.t()
    def put_jwt(conn, jwt),
      do: conn |> Conn.put_req_header("authorization", "Bearer: #{jwt}")
  end

  @doc """
  Adds a HMAC-SHA256 signature to the connection's `authorization` header for the request body.
  Use `create_hmac_plug_body/4` to generate a valid body. For use with endpoints secured
  with `PhoenixApiToolkit.Security.HmacPlug`.

  It is possible to override the HMAC secret. The default generates a valid signature, so
  overrides are not necessary unless you wish to test the HMAC verification itself.

  ## Examples

      use Plug.Test

      iex> body = %{greeting: "world"} |> Jason.encode!()
      iex> conn = conn(:post, "/hello", body)
      iex> put_hmac(conn, body, "supersecretkey") |> get_req_header("authorization")
      ["oseq9TrQc/cyOBU7ujrkKM07tFewcVoaLRK0MgslSos="]
  """
  @spec put_hmac(Conn.t(), binary, binary) :: Conn.t()
  def put_hmac(conn, body, secret) do
    conn
    |> Conn.put_req_header(
      "authorization",
      :crypto.hmac(:sha256, secret, body) |> Base.encode64()
    )
  end

  @doc """
  Generate a request body for an endpoint secured with `PhoenixApiToolkit.Security.HmacPlug`.
  Use `put_hmac/3` to generate a valid signature.

  It is possible to override the timestamp set in the request body. The default generates a valid
  request body, so overrides are not necessary unless you wish to test the HMAC verification itself.

  ## Examples

      iex> create_hmac_plug_body("/hello", "GET", %{hello: "world"}, 12345) |> Jason.decode!()
      %{
        "contents" => %{"hello" => "world"},
        "method" => "GET",
        "path" => "/hello",
        "timestamp" => 12345
      }
  """
  @spec create_hmac_plug_body(binary, binary, any, integer) :: binary
  def create_hmac_plug_body(
        path,
        method,
        contents \\ %{},
        timestamp \\ DateTime.utc_now() |> DateTime.to_unix(:second)
      ) do
    %{
      path: path,
      method: method,
      timestamp: timestamp,
      contents: contents
    }
    |> Jason.encode!()
  end

  @doc """
  Put a raw request body in `conn.assigns.raw_body` for testing purposes.

  ## Examples

      use Plug.Test

      iex> body = %{hello: "world"}
      iex> raw_body = body |> Jason.encode!()
      iex> conn = conn(:post, "/") |> put_raw_body(raw_body)
      iex> conn.adapter |> elem(1) |> Map.get(:req_body) |> Jason.decode!()
      %{"hello" => "world"}
  """
  @spec put_raw_body(Conn.t(), binary) :: Conn.t()
  def put_raw_body(%{adapter: {adapter, state}} = conn, raw_body) do
    conn |> Map.put(:adapter, {adapter, Map.put(state, :req_body, raw_body)})
  end

  @doc """
  Remove volatile fields from maps in the data.
  Volatile fields like "id" mess up test comparisons.
  Recursively cleans maps and lists.

  ## Examples

      iex> my_data = [
      ...>   %{
      ...>     "updated_at" => 12345
      ...>   },
      ...>   %{
      ...>     "some_thing" => [
      ...>       %{
      ...>         "id" => 1
      ...>       },
      ...>       12345
      ...>     ]
      ...>   }
      ...> ]
      iex> clean_volatile_fields(my_data)
      [%{}, %{"some_thing" => [%{}, 12345]}]
  """
  @spec clean_volatile_fields(any) :: any
  def clean_volatile_fields(data) when is_map(data) do
    data
    |> Map.drop(["id", "inserted_at", "updated_at"])
    |> Stream.map(fn {k, v} -> {k, clean_volatile_fields(v)} end)
    |> Enum.into(%{})
  end

  def clean_volatile_fields(data) when is_list(data),
    do: data |> Enum.map(&clean_volatile_fields/1)

  def clean_volatile_fields(data), do: data

  @doc """
  Put a whole map (or keyword list) of query params on a `%Conn{}`.

  ## Examples

      use Plug.Test

      iex> conn(:get, "/") |> put_query_params(user: "Peter") |> Map.get(:query_params)
      %{user: "Peter"}
  """
  @spec put_query_params(Conn.t(), map | keyword) :: Conn.t()
  def put_query_params(conn, params), do: conn |> Map.put(:query_params, params |> Map.new())

  @doc """
  Put request header "content-type: application/json" on the conn.

  ## Examples

      use Plug.Test

      iex> conn(:post, "/") |> application_json() |> get_req_header("content-type")
      ["application/json"]
  """
  @spec application_json(Conn.t()) :: Conn.t()
  def application_json(conn),
    do: conn |> Conn.put_req_header("content-type", "application/json")

  @doc """
  Converts a map with atoms in it as keys or values to a map with just strings.
  Works on nested maps as well.

  ## Examples

      iex> %{first_name: "Peter", stuff: %{"things" => :indeed}} |> to_string_map()
      %{"first_name" => "Peter", "stuff" => %{"things" => "indeed"}}
  """
  @spec to_string_map(map) :: map
  def to_string_map(map), do: map |> Jason.encode!() |> Jason.decode!()

  @doc """
  Sets the request header "x-csrf-token", to comply with `PhoenixApiToolkit.Security.Plugs.ajax_csrf_protect()`

  ## Examples / doctests

      iex> conn(:post, "/") |> put_ajax_csrf_header() |> Map.get(:req_headers)
      [{"x-csrf-token", "anything"}]
  """
  @spec put_ajax_csrf_header(Plug.Conn.t()) :: Plug.Conn.t()
  def put_ajax_csrf_header(conn) do
    Plug.Conn.put_req_header(conn, "x-csrf-token", "anything")
  end
end
