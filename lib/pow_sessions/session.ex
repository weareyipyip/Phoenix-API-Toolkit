defmodule PhoenixApiToolkit.PowSessions.Session do
  @moduledoc """
  A session as stored in Mnesia by `PhoenixApiToolkit.PowSessions.MnesiaSessionStore`.
  """
  defstruct id: nil,
            user_id: nil,
            refresh_token_id: nil,
            created_at: nil,
            refreshed_at: nil,
            last_known_ip: nil,
            token_signature_transport: nil,
            expires_at: nil

  use PhoenixApiToolkit.PowSessions.Constants

  @type t :: %__MODULE__{
          id: String.t(),
          user_id: pos_integer,
          refresh_token_id: String.t(),
          created_at: integer,
          refreshed_at: integer,
          last_known_ip: String.t(),
          token_signature_transport: atom,
          expires_at: integer | nil
        }

  @doc """
  Gets a `%#{__MODULE__}{}` from a conn's `private` map.
  """
  @spec get_from_conn(Plug.Conn.t()) :: t() | nil
  def get_from_conn(conn) do
    conn.private[@private_session_key]
  end
end
