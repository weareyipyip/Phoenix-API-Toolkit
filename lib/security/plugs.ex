defmodule PhoenixApiToolkit.Security.Plugs do
  @moduledoc """
  Security-related plugs.

  Several of these plugs are based on recommendations for API's by the [OWASP guidelines](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html).
  """
  alias Plug.Conn
  import Plug.Conn
  alias PhoenixApiToolkit.Security.{MissingContentTypeError, Oauth2TokenVerificationError}
  require Logger

  # DELETE should not have a request body
  @unsafe_methods ~w(PUT POST PATCH)

  @doc """
  Checks if the request's `content-type` header is present. Content matching is done by `Plug.Parsers`.

  The filter is only applied to methods which are expected to carry contents, to `put`, `post` and `patch`
  methods, that is. Only one `content-type` header is allowed. A noncompliant request causes a
  `PhoenixApiToolkit.Security.MissingContentTypeError` to be raised,
  resulting in a 415 Unsupported Media Type response.

  ## Examples

      use Plug.Test

      # safe methods pass through
      iex> conn = conn(:get, "/")
      iex> conn == require_content_type(conn)
      true

      # compliant unsafe methods (put, post and patch) pass through
      iex> conn = conn(:post, "/") |> put_req_header("content-type", "application/json")
      iex> conn == require_content_type(conn)
      true

      # noncompliant unsafe methods cause a MissingContentTypeError to be raised
      iex> conn(:post, "/") |> require_content_type()
      ** (PhoenixApiToolkit.Security.MissingContentTypeError) missing 'content-type' header

  """
  @spec require_content_type(Conn.t(), Plug.opts()) :: Conn.t()
  def require_content_type(conn, _opts \\ []) do
    with {:unsafe_method, true} <- {:unsafe_method, conn.method in @unsafe_methods},
         {:header, [_header]} <- {:header, get_req_header(conn, "content-type")} do
      conn
    else
      {:header, _} -> raise MissingContentTypeError
      {:unsafe_method, false} -> conn
    end
  end

  @doc """
  Adds security headers to the response as recommended for API's by OWASP. Sets
  `x-frame-options: deny` and `x-content-type-options: nosniff`.

  ## Examples

      use Plug.Test

      # it does what it says it does
      iex> conn = conn(:get, "/")
      iex> put_security_headers(conn).resp_headers -- conn.resp_headers
      [{"x-frame-options", "deny"}, {"x-content-type-options", "nosniff"}]
  """
  @spec put_security_headers(Conn.t(), Plug.opts()) :: Conn.t()
  def put_security_headers(conn, _opts \\ []) do
    conn
    |> put_resp_header("x-frame-options", "deny")
    |> put_resp_header("x-content-type-options", "nosniff")
  end

  @doc """
  Assign the clients IP to the conn as `client_ip`. Prefers IP in header `x-forwarded-for` over
  the directly detected remote IP.

  ## Examples

      use Plug.Test

      def conn_with_ip, do: conn(:get, "/") |> Map.put(:remote_ip, {127, 0, 0, 12})

      # by default, the value of `remote_ip` is used
      iex> (conn_with_ip() |> assign_client_ip()).assigns.client_ip
      "127.0.0.12"

      # if header "x-forwarded-for" is set, its value is preferred
      iex> (conn_with_ip() |> put_req_header("x-forwarded-for", "10.0.0.1") |> assign_client_ip()).assigns.client_ip
      "10.0.0.1"
  """
  @spec assign_client_ip(Conn.t(), Plug.opts()) :: Conn.t()
  def assign_client_ip(conn, _opts \\ []) do
    forwarded_ip =
      case get_req_header(conn, "x-forwarded-for") do
        [ip] -> ip
        _ -> nil
      end

    assign(conn, :client_ip, forwarded_ip || conn.remote_ip |> :inet.ntoa() |> to_string())
  end

  @doc """
  Check if the JWT in `conn.assigns.jwt` has a scope that matches the `exp_scopes` parameter.
  This assign is set by `PhoenixApiToolkit.Security.Oauth2Plug` and should contain a `JOSE.JWT` struct.

  If not, a `PhoenixApiToolkit.Security.Oauth2TokenVerificationError` is raised,
  resulting in a 401 Unauthorized response.

  ## Examples

      use Plug.Test

      def conn_with_scope(scope), do: conn(:get, "/") |> assign(:jwt, %{fields: %{"scope", scope}})

      # if there is a matching scope, the conn is passed through
      iex> conn = conn_with_scope("admin read:phone")
      iex> conn == conn |> verify_oauth2_scope(["admin"])
      true

      # an error is raised if there is no matching scope
      iex> conn_with_scope("admin read:phone") |> verify_oauth2_scope(["user"])
      ** (PhoenixApiToolkit.Security.Oauth2TokenVerificationError) Oauth2 token invalid: scope mismatch
  """
  @spec verify_oauth2_scope(Conn.t(), [binary]) :: Conn.t()
  def verify_oauth2_scope(conn, exp_scopes) do
    with %{jwt: %{fields: %{"scope" => scope}}} when is_binary(scope) <- conn.assigns,
         true <- exp_scopes -- String.split(scope, " ") != exp_scopes do
      conn
    else
      _ -> raise Oauth2TokenVerificationError, "Oauth2 token invalid: scope mismatch"
    end
  end

  @doc """
  Check if the JWT in `conn.assigns.jwt` has an "aud" claim that matches the `exp_aud` parameter.
  This assign is set by `PhoenixApiToolkit.Security.Oauth2Plug` and should contain a `JOSE.JWT` struct.

  If not, a `PhoenixApiToolkit.Security.Oauth2TokenVerificationError` is raised,
  resulting in a 401 Unauthorized response.

  ## Examples

      use Plug.Test

      def conn_with_aud(aud), do: conn(:get, "/") |> assign(:jwt, %{fields: %{"aud", aud}})

      # if aud matches, the conn is passed through
      iex> conn = conn_with_aud("my resource server")
      iex> conn == conn |> verify_oauth2_aud("my resource server")
      true

      # an error is raised if aud does not match
      iex> conn_with_aud("my resource server") |> verify_oauth2_aud("another server")
      ** (PhoenixApiToolkit.Security.Oauth2TokenVerificationError) Oauth2 token invalid: aud mismatch
  """
  @spec verify_oauth2_aud(Conn.t(), binary()) :: Conn.t()
  def verify_oauth2_aud(conn, exp_aud) do
    with %{jwt: %{fields: %{"aud" => ^exp_aud}}} <- conn.assigns do
      conn
    else
      _ -> raise Oauth2TokenVerificationError, "Oauth2 token invalid: aud mismatch"
    end
  end
end
