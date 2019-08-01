defmodule PhoenixApiToolkit.Security do
  @moduledoc false

  defmodule MissingContentTypeError do
    @moduledoc "Error raised when a content-carrying request does not have a content-type header."
    defexception message: "missing 'content-type' header", plug_status: 415
  end

  defmodule Oauth2TokenVerificationError do
    @moduledoc "Error raised when an Oauth2 token is invalid"
    defexception message: "Oauth2 token invalid", plug_status: 401

    def exception([]), do: %Oauth2TokenVerificationError{}

    def exception(message) do
      %Oauth2TokenVerificationError{message: message}
    end
  end

  defmodule HmacVerificationError do
    @moduledoc "Error raised the HMAC used to sign a request body is invalid"
    defexception message: "HMAC invalid", plug_status: 401

    def exception([]), do: %HmacVerificationError{}

    def exception(message) do
      %HmacVerificationError{message: message}
    end
  end
end
