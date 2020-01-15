defmodule PhoenixApiToolkit.PowSessions.AbsintheIntegration do
  use PhoenixApiToolkit.PowSessions.Constants

  if Code.ensure_loaded?(Absinthe) do
    @doc """
    Puts the access token payload from `conn.private[#{@private_access_token_payload_key}]` in
    the Absinthe context under key `:access_token_payload`. Use after `PhoenixApiToolkit.PowSessions.SessionPlugs`.
    """
    @spec hydrate_context_plug(Plug.Conn.t(), any) :: Plug.Conn.t()
    def hydrate_context_plug(conn, _opts) do
      Absinthe.Plug.put_options(conn,
        context: %{
          access_token_payload: conn.private[@private_access_token_payload_key],
          conn: conn
        }
      )
    end

    @doc """
    Absinthe middleware to require authentication before access.
    Can be used if the context was hydrated by `&hydrate_context_plug/2`.
    """
    @spec require_authentication_middleware(Absinthe.Resolution.t(), any) ::
            Absinthe.Resolution.t()
    def require_authentication_middleware(%{context: context} = res, _args) do
      if context[:access_token_payload] do
        res
      else
        Absinthe.Resolution.put_result(res, {:error, "unauthorized"})
      end
    end

    @doc """
    Absinthe middleware to update the context after a session is created, refreshed or dropped.

    Gets `resolution.value.resp_cookies` and `resolution.value.access_token_payload`
    and puts them in the context.
    """
    @spec current_session_changed_middleware(Absinthe.Resolution.t(), any) ::
            Absinthe.Resolution.t()
    def current_session_changed_middleware(%{value: value, context: context} = resolution, _args) do
      token_payload = value[:access_token_payload]

      context =
        context
        |> Map.put(:resp_cookies, value[:resp_cookies])
        |> Map.put(:access_token_payload, token_payload)
        |> put_in([:conn, Access.key(:private), @private_access_token_payload_key], token_payload)

      %{resolution | context: context}
    end

    @doc """
    Absinthe helper to send any `resp_cookies` present in the context.
    To be used as a `before_send` handler for `Absinthe.Plug`.
    Response cookies will be set by `&current_session_changed_middleware/2`.
    """
    @spec send_context_cookies(Plug.Conn.t(), map) :: Plug.Conn.t()
    def send_context_cookies(conn, %{execution: %{context: context}}) do
      %{conn | resp_cookies: Map.merge(conn.resp_cookies, context[:resp_cookies] || %{})}
    end

    def send_context_cookies(conn, _), do: conn
  end
end
