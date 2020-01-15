defmodule PhoenixApiToolkit.PowSessions.Constants do
  @moduledoc """
  Constants used throughout the `PhoenixApiToolkit.PowSessions` modules.

  When used, this module sets several constants as module attributes.
  The following attributes are set:
    - `@private_session_key`
    - `@private_access_token_payload_key`
    - `@private_access_token_key`
    - `@private_access_token_expiration_key`
    - `@private_refresh_token_payload_key`
    - `@private_refresh_token_key`
    - `@private_refresh_token_expiration_key`
    - `@private_auth_error_key`
    - `@private_token_signature_transport_key`
    - `@private_session_ttl_key`

  ## Example

      defmodule MyModule do
        use #{__MODULE__}

        def my_function(), do: @private_session_key
      end
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      @private_session_key :phoenix_api_toolkit_session
      @private_access_token_payload_key :phoenix_api_toolkit_access_token_payload
      @private_access_token_key :phoenix_api_toolkit_access_token
      @private_access_token_expiration_key :phoenix_api_toolkit_access_token_exp
      @private_refresh_token_payload_key :phoenix_api_toolkit_refresh_token_payload
      @private_refresh_token_key :phoenix_api_toolkit_refresh_token
      @private_refresh_token_expiration_key :phoenix_api_toolkit_refresh_token_exp
      @private_auth_error_key :phoenix_api_toolkit_auth_error
      @private_token_signature_transport_key :phoenix_api_toolkit_token_signature_transport
      @private_session_ttl_key :phoenix_api_toolkit_session_ttl
    end
  end
end
