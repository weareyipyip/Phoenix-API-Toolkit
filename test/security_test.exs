defmodule PhoenixApiToolkit.SecurityTest do
  use ExUnit.Case, async: true

  alias PhoenixApiToolkit.Security.{HmacVerificationError, Oauth2TokenVerificationError}

  test "the def exception things" do
    assert %HmacVerificationError{} = HmacVerificationError.exception([])
    assert %Oauth2TokenVerificationError{} = Oauth2TokenVerificationError.exception([])
  end
end
