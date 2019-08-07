defmodule PhoenixApiToolkit.SecurityTest do
  use ExUnit.Case, async: true

  alias PhoenixApiToolkit.Security.{HmacVerificationError, Oauth2TokenVerificationError}

  test "the def exception things" do
    for error <- [HmacVerificationError, Oauth2TokenVerificationError] do
      assert %error{} = error.exception([])
    end
  end
end
