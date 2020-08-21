defmodule PhoenixApiToolkit.Security.Plugs do
  @moduledoc """
  Security-related plugs.

  Several of these plugs are based on recommendations for API's by the [OWASP guidelines](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html).
  """
  alias Plug.Conn
  import Plug.Conn

  alias PhoenixApiToolkit.Security.{
    MissingContentTypeError,
    Oauth2TokenVerificationError,
    AjaxCSRFError
  }

  require Logger

  @doc """
  Protect AJAX-requests / API endpoints (ONLY those requests, not HTML forms!) against CSRF-attacks by requiring header `x-csrf-token` to be set to any value.

  This defense relies on the same-origin policy (SOP) restriction that only JavaScript can be used to add a custom header, and only within its origin. https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html#use-of-custom-request-headers

  ## Examples / doctests

      # requests that don't (shouldn't) change server state pass through
      iex> conn(:get, "/") |> ajax_csrf_protect() |> Map.get(:halted)
      false

      # state-changing requests with the header pass through
      iex> conn(:post, "/") |> put_req_header("x-csrf-token", "anything") |> ajax_csrf_protect() |> Map.get(:halted)
      false

      # state-changing requests without the header are rejected
      iex> conn(:post, "/") |> ajax_csrf_protect()
      ** (PhoenixApiToolkit.Security.AjaxCSRFError) missing 'x-csrf-token' header
  """
  @spec ajax_csrf_protect(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def ajax_csrf_protect(conn, _opts \\ nil)

  def ajax_csrf_protect(%{method: method} = conn, _) when method in ~w(POST PUT PATCH DELETE) do
    if (conn |> get_req_header("x-csrf-token") |> List.first()) in [nil, ""] do
      raise AjaxCSRFError
    else
      conn
    end
  end

  def ajax_csrf_protect(conn, _), do: conn

  @doc """
  Checks if the request's `"content-type"` header is present. Content matching is done by `Plug.Parsers`.

  The filter is only applied to methods which are expected to carry contents, to `PUT`, `POST` and `PATCH`
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
  def require_content_type(conn, _opts \\ nil)

  def require_content_type(%{method: method} = conn, _) when method in ~w(PUT POST PATCH) do
    if (conn |> get_req_header("content-type") |> List.first()) in [nil, ""] do
      raise MissingContentTypeError
    else
      conn
    end
  end

  def require_content_type(conn, _), do: conn

  @doc """
  Adds security headers to the response as recommended for API's by OWASP. Sets
  `"x-frame-options": "deny"` and `"x-content-type-options": "nosniff"`.

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
  Set `conn.remote_ip` to the value in header `"x-forwarded-for"`, if present.

   ## Examples

      use Plug.Test

      def conn_with_ip, do: conn(:get, "/") |> Map.put(:remote_ip, {127, 0, 0, 12})

      # by default, the value of `remote_ip` is left alone
      iex> conn = conn_with_ip() |> set_forwarded_ip()
      iex> conn.remote_ip
      {127, 0, 0, 12}

      # if header "x-forwarded-for" is set, remote ip is overwritten
      iex> conn = conn_with_ip() |> put_req_header("x-forwarded-for", "10.0.0.1") |> set_forwarded_ip()
      iex> conn.remote_ip
      {10, 0, 0, 1}
  """
  @spec set_forwarded_ip(Conn.t(), Plug.opts()) :: Conn.t()
  def set_forwarded_ip(conn, _opts \\ []) do
    with [ip] <- get_req_header(conn, "x-forwarded-for"),
         {:ok, parsed} <- ip |> to_charlist() |> :inet.parse_address() do
      %{conn | remote_ip: parsed}
    else
      _ -> conn
    end
  end

  @doc """
  Check if the JWT in `conn.assigns.jwt` has a `"scope"` claim that matches the `exp_scopes` parameter.
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
      iex> conn == conn |> verify_oauth2_scope(["admin", "not:a:match"])
      true
      iex> conn == conn |> verify_oauth2_scope(["admin", "read:phone"])
      true

      # an error is raised if there is no matching scope
      iex> conn_with_scope("admin read:phone") |> verify_oauth2_scope(["not:a:match"])
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
  Check if the JWT in `conn.assigns.jwt` has an `"aud"` claim that matches the `exp_aud` parameter.
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
