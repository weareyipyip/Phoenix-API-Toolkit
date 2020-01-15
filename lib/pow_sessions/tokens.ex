defmodule PhoenixApiToolkit.PowSessions.Tokens do
  @moduledoc """
  Tokens to be communicated to the client.
  """
  defstruct access_token: nil, refresh_token: nil, access_token_exp: nil, refresh_token_exp: nil

  use PhoenixApiToolkit.PowSessions.Constants

  @type t :: %__MODULE__{
          access_token: String.t(),
          refresh_token: String.t(),
          access_token_exp: integer,
          refresh_token_exp: integer
        }

  @doc """
  Creates a new `%#{__MODULE__}{}` from the values in a conn's `private` map.
  """
  @spec new(Plug.Conn.t()) :: t()
  def new(%{private: private} = _conn) do
    %__MODULE__{
      access_token: private[@private_access_token_key],
      refresh_token: private[@private_refresh_token_key],
      access_token_exp: private[@private_access_token_expiration_key],
      refresh_token_exp: private[@private_refresh_token_expiration_key]
    }
  end
end
