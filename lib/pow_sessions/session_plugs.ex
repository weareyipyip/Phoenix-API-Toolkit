defmodule PhoenixApiToolkit.PowSessions.SessionPlugs do
  use PhoenixApiToolkit.PowSessions.Constants

  @moduledoc """
  Pow session manager implementation.

  This implementation attempts to achieve:
   - parity with the security provided by session cookies in browsers, which means it should
     not be possible to steal a valid auth token from JavaScript code
   - not being limited to the 4kB limit for cookies in browsers
   - short lived stateless access tokens separate from long-lived refresh tokens
   - ability to revoke other sessions in the form of revoking refresh tokens so that token renewal is not possible
   - native clients do not need to handle cookies but can use simple bearer tokens for access / refresh

  ## Token handling

  This implementation uses asymmetric Phoenix tokens (refresh and access),
  where the refresh token is tracked using `session_store(config)` so that sessions can be
  forcibly logged out and so that refresh tokens are single-use only.
  Access tokens are stateless and are not tracked server-side.

  All tokens are passed using the "authorization" header. However, the signatures needed to verify the integrity
  of the tokens is either transported to the client as part of the token itself
  (token format "header.payload.signature") or separately as a cookie (in which case the token format will be "header.payload").
  This behaviour is set for the lifetime of the session when the session is created, by specifying `:bearer` or `:cookie` as
  `conn.private[:#{@private_token_signature_transport_key}]` and is enforced when a token is verified. This means
  that the signature of a refresh token of a session with transport mechanism "bearer" MUST be passed to `refresh/2`
  as part of the bearer token, and will be rejected when passed using a cookie, and vice-versa.

  For native apps or other clients that have a secure way of storing tokens, "bearer" is recommended.
  For browser clients, it is recommended to use the "cookie" signature transport mechanism, which will prevent the client
  from having to use an insecure storage mechanism like LocalStorage for token signatures. The rest of the token,
  however, can simply be held in memory or stored in whatever way the client fancies.
  In case of a successful XSS breach of the web application only the token payloads will be exposed.
  Those payloads cannot be used as authentication tokens because they have no validity without their signature
  components, which cannot be accessed from JavaScript. The signature is a HMAC, which cannot be generated without
  the server-side secret key, and the payload cannot be altered without invalidating the signature.
  Splitting the token signature from the header and payload also means that tokens can (really shouldn't, but can)
  grow larger than the 4kB limit for a cookie without problems,
  because only the signature is held in a cookie and not the payload.

  Note that this does not mean that all security issues have been solved. It is still possible to use XSS attacks
  to make API requests with a valid auth header while the XSS code has access to the browser context in which the
  tokens live, because the signature cookie is sent automatically by the browser.

  ## Cross-site request forgery

  Cross-site request forgery issues are left for controllers to deal with when applicable.
  As per [OWASP guidelines](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html#use-of-custom-request-headers),
  setting a custom header is sufficient to protect against CSRF for an API. Since the "authorization" header with
  a bearer token qualifies, such issues (apart from [login-CSRF](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html#login-csrf)!)
  should not arrise when using this implentation to secure an API, but can and will arise when using this implementation
  to secure Phoenix HTML applications. So use `Plug.CSRFProtection` in that case.

  ## Config values

  The following values must be set in the config (or in the application environment under the matching otp_app)
  (example or - in case of optionals - default values):

      phoenix_api_toolkit: [
        access_token_ttl: 30 * 60,
        refresh_token_ttl: 2 * 30 * 24 * 60 * 60,
        refresh_signature_cookie_name: "_phoenix_api_toolkit_refresh_signature",
        access_signature_cookie_name: "_phoenix_api_toolkit_access_signature",
        refresh_path: "/api/v1/current_session/refresh",
        session_store: MyMnesiaCacheModule,
        # optional (defaults shown first)
        session_ttl: nil || 365 * 24 * 60 * 60,
        access_token_salt: "access_token",
        refresh_token_salt: "refresh_token",
        refresh_token_key_digest: :sha512 || :sha256 || :sha384,
        access_token_key_digest: :sha256 || :sha384 || :sha512
      ]

  The *_ttl values are in seconds, except for session_ttl which can also be nil.
  The salts are not cryptographic salts but behave like token namespaces, separating refresh and access tokens.

  ## Maximum session age

  A session can optionally have an absolute maximum age, which is set when the session is first created and is not
  affected by refreshes. It is calculated as session_ttl + session creation timestamp.
  By default, no maximum age is set (it defaults to `nil`). The maximum age can be set globally in the config, as shown above.
  It can also, however, be set using `conn.private[:#{@private_session_ttl_key}]`, permitting
  advanced handling by controllers. This makes it possible to have a different session max age for users with different
  credential levels, session types, access levels etc etc.
  Note that the value of `conn.private[:#{@private_session_ttl_key}]` overrides the global config value.
  """
  use Pow.Plug.Base

  import Plug.Conn
  alias Pow.Config
  alias Phoenix.Token
  alias PhoenixApiToolkit.PowSessions.{Session}
  import PhoenixApiToolkit.PowSessions.Config

  require Logger

  @doc """
  Fetch the session state from the access token in the "authorization" header. The token
  must not be older than access_ttl seconds and correctly signed. The signature must
  originate from the correct signature transport channel. The token payload
  is put in `conn.private.#{@private_access_token_payload_key}` and the user is assigned to
  `conn.assigns.current_user`.

  The user is NOT fetched from the database, it is left for controllers to decide if this is needed.
  """
  @impl true
  @spec fetch(Plug.Conn.t(), Config.t()) :: {Plug.Conn.t(), map() | nil}
  def fetch(conn, config) do
    proc_conf = process_config(config)

    with {sig_transport, token} <- get_token(conn, access_sig_cookie_name(proc_conf)),
         {:ok, %{uid: user_id, tst: exp_sig_trans, sid: session_id, exp: expires_at} = payload} <-
           Token.verify(conn, access_salt(proc_conf), token, access_verify_opts(proc_conf)),
         {:transport_matches, true} <- {:transport_matches, sig_transport == exp_sig_trans},
         {:session_expired, false} <- session_expired?(session_id, expires_at, config) do
      {put_private(conn, @private_access_token_payload_key, payload), %{id: user_id}}
    else
      nil ->
        auth_error(conn, "bearer token not found")

      {:error, :expired} ->
        auth_error(conn, "bearer token expired")

      {:error, :invalid} ->
        auth_error(conn, "bearer token invalid")

      {:ok, _} ->
        auth_error(conn, "invalid bearer token payload")

      {:transport_matches, false} ->
        auth_error(conn, "token signature transport invalid")

      {:session_expired, true} ->
        auth_error(conn, "session expired")

      error ->
        Logger.error("Unexpected auth error: #{inspect(error)}")
        auth_error(conn, "unexpected error")
    end
  end

  @doc """
  Create or update a session. If `conn.private.#{@private_session_key}` exists,
  the session is updated, otherwise a new one is created.
  These values are set by `refresh/2` when appropriate.

  In both cases, new access / refresh tokens are created and stored in the conn's private map.
  The server-side session stored in `session_store(config)` is created / updated as well.

  The tokens' signatures are split off and sent as cookies if the session's token signature
  transport mechanism is set to `:cookie`.

  The session can optionally have a maximum age set when it is created.

  For access token signatures, a cookie named "access_sig_cookie_name" is sent with the following options:
  `[http_only: true, extra: "SameSite=Strict", secure: true]`.

  For refresh token signatures, a cookie named "refresh_sig_cookie_name" is sent with the following options:
  `[http_only: true, extra: "SameSite=Strict", secure: true]`.
  """
  @impl true
  @spec create(Plug.Conn.t(), map(), Config.t()) :: {Plug.Conn.t(), map()}
  def create(conn, %{id: uid} = user, config) do
    proc_conf = process_config(config)
    now = System.system_time(:second)

    # the refresh token id is renewed every time so that refresh tokens are single-use only
    rtid = Pow.UUID.generate()

    # update the existing session (as set by &refresh/2) or create a new one
    session = %{
      (Session.get_from_conn(conn) || new_session(conn, proc_conf, now, uid))
      | refresh_token_id: rtid,
        refreshed_at: now,
        last_known_ip: conn.remote_ip |> :inet.ntoa() |> to_string()
    }

    session_store(config).put(config, session.id, session)

    # create access and refresh tokens and put them on the conn
    tst = session.token_signature_transport
    refresh_payload = %{id: rtid, uid: uid, sid: session.id, tst: tst, exp: session.expires_at}
    access_payload = %{uid: uid, sid: session.id, tst: tst, exp: session.expires_at}
    refresh_opts = Keyword.put(refresh_opts(proc_conf), :signed_at, now)
    refresh_token = Token.sign(conn, refresh_salt(proc_conf), refresh_payload, refresh_opts)
    refresh_ttl = calc_ttl(session, now, refresh_ttl(proc_conf))
    access_opts = Keyword.put(access_opts(proc_conf), :signed_at, now)
    access_token = Token.sign(conn, access_salt(proc_conf), access_payload, access_opts)
    access_ttl = calc_ttl(session, now, access_ttl(proc_conf))

    conn =
      conn
      |> add_tokens(proc_conf, tst, access_token, refresh_token, access_ttl, refresh_ttl)
      |> put_privates([
        {@private_session_key, session},
        {@private_access_token_expiration_key, now + access_ttl},
        {@private_access_token_payload_key, access_payload},
        {@private_refresh_token_expiration_key, now + refresh_ttl},
        {@private_refresh_token_payload_key, refresh_payload}
      ])

    Logger.debug(fn ->
      operation = if session.created_at == now, do: "CREATED", else: "REFRESHED"
      "#{operation} session #{session.id}: #{inspect(session)}"
    end)

    {conn, user}
  end

  @doc """
  Delete the persistent session identified by the session_id in the access token payload.

  Note that the access token remains valid until it expires, it is left up to the client to drop
  the access token. It will no longer be possible to refresh the session, however.
  """
  @impl true
  @spec delete(Plug.Conn.t(), Config.t()) :: Plug.Conn.t()
  def delete(conn, config) do
    proc_conf = process_config(config)
    %{sid: session_id} = conn.private[@private_access_token_payload_key]
    session_store(config).delete(config, session_id)

    conn
    |> delete_resp_cookie(refresh_sig_cookie_name(proc_conf), refresh_sig_cookie_opts(proc_conf))
    |> delete_resp_cookie(access_sig_cookie_name(proc_conf), access_sig_cookie_opts(proc_conf))
  end

  @doc """
  Create new access / refresh tokens if a valid refresh token is found.

  The token is read from the authorization header, and the token's signature either from the header or
  from cookie "@refresh_sig_cookie_name". The token signature source (bearer or cookie) must match
  the `token_signature_transport` specified in the token payload.

  A refresh token can only be used to refresh a session once. A single refresh token id is stored in the
  server-side session by `create/2` to enforce this.
  """
  @spec refresh(Plug.Conn.t(), Config.t()) :: {Plug.Conn.t(), map() | nil}
  def refresh(conn, config) do
    proc_conf = process_config(config)

    with {:token, {sig_transport, token}} <-
           {:token, get_token(conn, refresh_sig_cookie_name(proc_conf))},
         {:ok, %{uid: uid, sid: sid, id: rtid, tst: tst, exp: exp} = payload} <-
           Token.verify(conn, refresh_salt(proc_conf), token, refresh_verify_opts(proc_conf)),
         {:transport_matches, true} <- {:transport_matches, sig_transport == tst},
         {:session_expired, false} <- session_expired?(sid, exp, config),
         {:session, %Session{} = session} <- {:session, session_store(config).get(config, sid)},
         {:token_fresh, true} <- {:token_fresh, session.refresh_token_id == rtid},
         %{id: _} = user <- Pow.Operations.get_by([id: uid], proc_conf),
         {:status, "active"} <- {:status, user.status} do
      conn
      |> put_privates([
        {@private_session_key, session},
        {@private_refresh_token_payload_key, payload}
      ])
      |> create(user, proc_conf)
    else
      {:token, nil} ->
        auth_error(conn, "refresh token not found")

      {:error, :expired} ->
        auth_error(conn, "refresh token expired")

      {:error, :invalid} ->
        auth_error(conn, "refresh token invalid")

      {:ok, _} ->
        auth_error(conn, "invalid refresh token payload")

      {:transport_matches, false} ->
        auth_error(conn, "token signature transport invalid")

      {:session, :not_found} ->
        auth_error(conn, "session not found")

      {:session_expired, true} ->
        auth_error(conn, "session expired")

      {:token_fresh, false} ->
        auth_error(conn, "refresh token stale")

      nil ->
        auth_error(conn, "user not found")

      {:status, _other} ->
        auth_error(conn, "user is not active")

      error ->
        Logger.error("Unexpected auth error: #{inspect(error)}")
        auth_error(conn, "unexpected error")
    end
  end

  ############
  # Privates #
  ############

  defp calc_ttl(session, now, ttl)
  defp calc_ttl(%{expires_at: nil}, _now, ttl), do: ttl
  defp calc_ttl(%{expires_at: timestamp}, now, ttl), do: min(timestamp - now, ttl)

  defp session_expired?(session_id, expires_at, config) do
    # this also works if expires_at is an atom like nil, because of https://hexdocs.pm/elixir/master/operators.html#term-ordering
    if expires_at > System.system_time(:second) do
      {:session_expired, false}
    else
      session_store(config).delete(config, session_id)
      {:session_expired, true}
    end
  end

  defp add_tokens(conn, config, :cookie, access_token, refresh_token, access_ttl, refresh_ttl) do
    [at_header, at_payload, at_signature] = String.split(access_token, ".", parts: 3)
    access_token = at_header <> "." <> at_payload
    [rt_header, rt_payload, rt_signature] = String.split(refresh_token, ".", parts: 3)
    refresh_token = rt_header <> "." <> rt_payload
    access_sig_cookie_opts = Keyword.put(access_sig_cookie_opts(config), :max_age, access_ttl)
    refresh_sig_cookie_opts = Keyword.put(refresh_sig_cookie_opts(config), :max_age, refresh_ttl)

    conn
    |> put_privates([
      {@private_access_token_key, access_token},
      {@private_refresh_token_key, refresh_token}
    ])
    |> put_resp_cookie(
      access_sig_cookie_name(config),
      "." <> at_signature,
      access_sig_cookie_opts
    )
    |> put_resp_cookie(
      refresh_sig_cookie_name(config),
      "." <> rt_signature,
      refresh_sig_cookie_opts
    )
  end

  defp add_tokens(conn, _config, :bearer, access_token, refresh_token, _, _) do
    conn
    |> put_privates([
      {@private_access_token_key, access_token},
      {@private_refresh_token_key, refresh_token}
    ])
  end

  defp put_privates(%{private: private} = conn, keyword_or_map) do
    private = Map.merge(private, Map.new(keyword_or_map))
    %{conn | private: private}
  end

  defp get_token(conn, signature_cookie_name) do
    bearer_token = token_from_auth_header(conn)

    cookie_signature =
      conn |> fetch_cookies() |> Map.get(:cookies, %{}) |> Map.get(signature_cookie_name)

    cond do
      bearer_token && cookie_signature -> {:cookie, bearer_token <> cookie_signature}
      bearer_token -> {:bearer, bearer_token}
      true -> nil
    end
  end

  defp token_from_auth_header(conn) do
    conn
    |> get_req_header("authorization")
    |> List.first()
    |> auth_header_to_token()
  end

  defp auth_header_to_token(<<"Bearer "::binary, token::binary>>), do: token
  defp auth_header_to_token(<<"Bearer: "::binary, token::binary>>), do: token
  defp auth_header_to_token(_), do: nil

  defp new_session(conn, config, timestamp, user_id) do
    %Session{
      created_at: timestamp,
      id: Pow.UUID.generate(),
      user_id: user_id,
      token_signature_transport: Map.fetch!(conn.private, @private_token_signature_transport_key),
      expires_at:
        case conn.private[@private_session_ttl_key] || config[:session_ttl] do
          ttl when is_integer(ttl) -> ttl + timestamp
          _ -> nil
        end
    }
  end

  defp auth_error(conn, error), do: {put_private(conn, @private_auth_error_key, error), nil}
end
