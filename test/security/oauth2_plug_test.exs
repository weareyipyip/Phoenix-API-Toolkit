defmodule PhoenixApiToolkit.Security.Oauth2PlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhoenixApiToolkit.Security.Oauth2Plug
  alias PhoenixApiToolkit.Security.Oauth2TokenVerificationError
  import PhoenixApiToolkit.TestHelpers

  @other_keypair [
    d:
      "YV8fkMrXORGBK-cDtqet6_ErPkhFYBxRZeJBegRGwI-pelOzppktyyoGQa3X5SUEL3QsBLRVuwVm8aSYXqQZJ-0PUKMT3mszum9daiHNUvVvJMcI1BF207UNPuus75KiN3bdOnYnNnqmZPnP31kHhTN1WFZ-O6OCulqG5eOvuyH7H8KvpO2dqRV2ds0sGN2NllCETM__VrTxCQgCBN4zbyikmOVjDsarn7oMk9-TZPuSmGiIhEZp7Sk9CMz_niP2NWrWeFpFlup7B6tBHBv27SC8x52tOkJUKSFhJ1Y_TGegUMhOwF9-Qi3j7FEsZt0jvLZrbVYjEa5CXeiXZNX-MQ",
    n:
      "h-81k77YajBASjVA9kjYy4ISDAyExr7LJLFP-8GN5CAkLSiqEJfXO9vSBF--qk7fDIcmI5FQQxHLJ0QSfjjalfbCFpmkFAp1w95BPT2Rqg_WLNkW3wl87DAaMmzbFVBtjhxOSxCzi1Vt0dsyEnKWUB-kc2N8U_eBhJnlVg9apyIs0UXVp8PR_fBr4_sHlWuMolcqIpyJWIiktvEn_NGjH-muDhx5jiSlE7nShXasJUMPTXtSbFg9H16ix2fOYdDWk5sYUwzVNuOM1OdfjOnC8CI4cEqJwjmIqXgNfCB1-fBdzna1VC-1_y3Ld65rnY09Dj_LpRYCGrRUxQKz5sOxNw"
  ]
  @jwt_defaults %{
    jwk: gen_jwk(),
    jws: gen_jws(),
    payload: gen_payload(iss: "http://my-oauth2-provider")
  }

  @opts Oauth2Plug.init(
          keyset: test_jwks(),
          exp_iss: @jwt_defaults.payload["iss"],
          dummy_verify: false,
          alg_whitelist: ["RS256"]
        )
  @dummy_opts @opts |> Map.put(:dummy_verify, true)

  doctest Oauth2Plug

  defp error_message(reason), do: "Oauth2 token invalid: #{reason}"

  describe "Oauth2 plug" do
    test "init defaults to non-dummy mode" do
      assert false ==
               Oauth2Plug.init(
                 keyset: test_jwks(),
                 exp_iss: "",
                 alg_whitelist: ["RS256"]
               ).dummy_verify
    end

    test "init raises if mandatory parameters are missing" do
      mandatory_params = [:keyset, :exp_iss, :alg_whitelist]

      for param <- mandatory_params do
        opts = @opts |> Map.drop([param]) |> Keyword.new()

        assert_raise KeyError, "key :#{param} not found in: #{inspect(opts)}", fn ->
          opts |> Oauth2Plug.init()
        end
      end
    end

    test "should reject a request with a missing authentication header" do
      err_message = error_message("missing authorization header")

      assert_raise Oauth2TokenVerificationError, err_message, fn ->
        conn(:get, "/") |> Oauth2Plug.call(@opts)
      end
    end

    test "should reject a request with a malformed authentication header" do
      headers = ["bear jwt", "Bearerjwt", "", "Bear jwt", "Bearer", "bearer; jwt"]
      err_message = error_message("malformed authorization header")

      for header <- headers do
        assert_raise Oauth2TokenVerificationError, err_message, fn ->
          conn(:get, "/") |> put_req_header("authorization", header) |> Oauth2Plug.call(@opts)
        end
      end
    end

    test "should reject a request with a malformed bearer token JWT" do
      headers = ["Bearer: jwt", "Bearer jwt", "bearer: jwt", "bearer jwt"]
      err_message = error_message("could not decode JWT")

      for header <- headers do
        assert_raise Oauth2TokenVerificationError, err_message, fn ->
          conn(:get, "/") |> put_req_header("authorization", header) |> Oauth2Plug.call(@opts)
        end
      end
    end

    test "should reject a request with a missing key ID in the JWT header" do
      [gen_jwt(@jwt_defaults |> Map.put(:jws, @jwt_defaults.jws |> Map.drop(["kid"])))]
      |> expect_token_error("no key ID in JWT header")
    end

    test "should reject a request with an unknown key ID in the JWT header" do
      [gen_jwt(@jwt_defaults, jws: [kid: "unknown kid"])]
      |> expect_token_error("unknown signing key")
    end

    test "should reject a request signed with an incorrect algorithm" do
      [
        gen_jwt(@jwt_defaults, jws: [alg: "RS384"]),
        gen_jwt(@jwt_defaults, jws: [alg: "RS512"])
      ]
      |> expect_token_error("signature mismatch")
    end

    test "should reject a request signed with an incorrect key" do
      [gen_jwt(@jwt_defaults, jwk: @other_keypair)]
      |> expect_token_error("signature mismatch")
    end

    test "should reject a request with jwt claim exp missing, malformed or expired" do
      [
        gen_jwt(@jwt_defaults, payload: [exp: "boom"]),
        gen_jwt(@jwt_defaults, payload: [exp: 1])
      ]
      |> expect_token_error("expired")
    end

    test "should reject a request with jwt claim iss missing, malformed or mismatched" do
      [
        gen_jwt(@jwt_defaults |> Map.put(:payload, @jwt_defaults.payload |> Map.drop(["iss"]))),
        gen_jwt(@jwt_defaults, payload: [iss: 12]),
        gen_jwt(@jwt_defaults, payload: [iss: "boom"])
      ]
      |> expect_token_error("issuer mismatch")
    end

    test "should allow a correctly authorized request" do
      result = conn(:get, "/") |> put_jwt(gen_jwt(@jwt_defaults)) |> Oauth2Plug.call(@opts)
      assert %Plug.Conn{} = result
      assert %JOSE.JWT{} = result.assigns.jwt
      assert %JOSE.JWS{} = result.assigns.jws
    end
  end

  describe "Oauth2 plug in dummy verification mode" do
    @tag :capture_log
    test "should allow incorrectly signed requests" do
      jwt = gen_jwt(@jwt_defaults, jwk: @other_keypair)
      assert %Plug.Conn{} = conn(:get, "/") |> put_jwt(jwt) |> Oauth2Plug.call(@dummy_opts)
    end

    @tag :capture_log
    test "should reject a request with a malformed bearer token JWT" do
      expect_token_error(["invalid jwt"], "could not decode JWT", @dummy_opts)
    end
  end

  defp expect_token_error(jwts, message, opts \\ @opts) do
    for jwt <- jwts do
      assert_raise Oauth2TokenVerificationError, error_message(message), fn ->
        conn(:get, "/") |> put_jwt(jwt) |> Oauth2Plug.call(opts)
      end
    end
  end
end
