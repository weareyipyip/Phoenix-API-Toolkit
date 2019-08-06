defmodule PhoenixApiToolkit.TestHelpersTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import PhoenixApiToolkit.TestHelpers

  @jwt_defaults %{
    jwk: gen_jwk(),
    jws: gen_jws(),
    payload: gen_payload(iss: "http://my-oauth2-provider")
  }

  doctest PhoenixApiToolkit.TestHelpers
end
