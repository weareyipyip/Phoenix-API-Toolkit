if Code.ensure_loaded?(:jose) do
  defmodule PhoenixApiToolkit.Security.Oauth2Plug do
    @moduledoc """
    Plug to verify an Oauth2 JWT. The JWT must be passed to the application in the `authorization`
    request header prefixed with `Bearer: `. The Plug must be configured with a set of JSON Web Keys used to
    sign the JWT's, a whitelist of algorithms that may be used to sign the JWT and the expected issuer.
    The optional `dummy_verify` setting can be used to skip JWT verification for development and testing.
    Requires `:jose` dependency in your mix.exs file.

    The most important setting is `keyset`, in which a base64-encoded JSON list of JWK's must be provided. In order
    to make the parsing work reliably, do the encoding in IEx or use `echo 'keylist' | base64` in bash.

    This plug verifies the token's signature, issuer and expiration timestamp.
    Depending on the Oauth2 provider used, additional token claims should be verified.
    According to the Oauth2 spec, the "aud" claim must always be verified, for example. In practice, however,
    not all Oauth2 implementations adhere to the specification by including this claim in their tokens,
    so that's why verification of "aud" and other claims is not handled by default by this plug. Please refer
    to your Oauth2 provider's instructions about verifying token claims and take a look at
    `PhoenixApiToolkit.Security.Plugs` for additional claim verification plugs.

    If the token is invalid for any reason, `PhoenixApiToolkit.Security.Oauth2TokenVerificationError` is raised,
    resulting in a 401 Unauthorized response.

    ## Usage example

        plug #{__MODULE__},
          keyset: "W3siYWxnIjoiUlMyNTYiLCJlIjoiQ",
          exp_iss: "https://my_oauth2_auth_server",
          dummy_verify: false,
          alg_whitelist: ["RS256"]

    ## Results examples

        use Plug.Test
        import PhoenixApiToolkit.TestHelpers
        alias PhoenixApiToolkit.Security.Oauth2Plug

        @jwt_defaults %{
          jwk: gen_jwk(),
          jws: gen_jws(),
          payload: gen_payload(iss: "http://my-oauth2-provider")
        }

        def opts do
          Oauth2Plug.init(
            lazy_keyset: fn -> test_jwks() |> Oauth2Plug.process_jwks() end,
            lazy_exp_iss: fn -> @jwt_defaults.payload["iss"] end,
            dummy_verify: false,
            alg_whitelist: ["RS256"]
          )
        end

        a correctly signed request is passed through, with the JWT's payload and JWS assigned
        iex> conn = conn(:get, "/")
        iex> jwt = gen_jwt(@jwt_defaults)
        iex> result = conn |> put_jwt(jwt) |> Oauth2Plug.call(opts())
        iex> result == conn |> put_jwt(jwt) |> assign(:jwt, result.assigns.jwt) |> assign(:jws, result.assigns.jws)
        true

        # requests that are noncompliant result in an Oauth2TokenVerificationError
        iex> conn(:get, "/") |> Oauth2Plug.call(opts())
        ** (PhoenixApiToolkit.Security.Oauth2TokenVerificationError) Oauth2 token invalid: missing authorization header

        iex> conn(:get, "/") |> put_jwt("invalid") |> Oauth2Plug.call(opts())
        ** (PhoenixApiToolkit.Security.Oauth2TokenVerificationError) Oauth2 token invalid: could not decode JWT
    """
    alias Plug.Conn
    alias PhoenixApiToolkit.Security.Oauth2TokenVerificationError
    require Logger

    @doc false
    def init(opts) do
      opts = Keyword.new(opts)

      %{
        lazy_exp_iss: Keyword.fetch!(opts, :lazy_exp_iss),
        dummy_verify: Keyword.get(opts, :dummy_verify, false),
        alg_whitelist: Keyword.fetch!(opts, :alg_whitelist),
        lazy_keyset: Keyword.fetch!(opts, :lazy_keyset)
      }
    end

    @doc false
    def call(
          conn,
          %{
            lazy_keyset: lazy_keyset,
            lazy_exp_iss: lazy_exp_iss,
            dummy_verify: dummy_verify,
            alg_whitelist: alg_whitelist
          }
        ) do
      keyset = lazy_keyset.()
      exp_iss = lazy_exp_iss.()

      with {:ok, raw_jwt} <- parse_auth_header(conn),
           {true, jwt, jws} <- verify_jwt(raw_jwt, keyset, alg_whitelist, dummy_verify),
           :ok <- verify_exp(jwt),
           :ok <- verify_iss(jwt, exp_iss) do
        conn
        |> Conn.assign(:jwt, jwt)
        |> Conn.assign(:jws, jws)
      else
        error ->
          error |> inspect() |> Logger.error()
          raise Oauth2TokenVerificationError, "Oauth2 token invalid: unknown error"
      end
    end

    @doc """
    Process a jwks string to pass to `&call/2`.
    """
    def process_jwks(jwks) do
      jwks
      |> Base.decode64!()
      |> Jason.decode!()
      |> Stream.map(&JOSE.JWK.from/1)
      |> Map.new(fn jwk -> {jwk.fields["kid"], jwk} end)
    end

    ############
    # Privates #
    ############

    defp parse_auth_header(conn) do
      with [auth_header] <- Conn.get_req_header(conn, "authorization"),
           token <- auth_header_to_token(auth_header) do
        {:ok, token}
      else
        _ ->
          raise Oauth2TokenVerificationError, "Oauth2 token invalid: missing authorization header"
      end
    end

    defp auth_header_to_token(<<"Bearer: "::binary, token::binary>>), do: token
    defp auth_header_to_token(<<"Bearer "::binary, token::binary>>), do: token
    defp auth_header_to_token(<<"bearer: "::binary, token::binary>>), do: token
    defp auth_header_to_token(<<"bearer "::binary, token::binary>>), do: token

    defp auth_header_to_token(_) do
      raise Oauth2TokenVerificationError, "Oauth2 token invalid: malformed authorization header"
    end

    defp verify_jwt(raw_jwt, keyset, alg_whitelist, false) do
      with {:ok, key_id} <- peek_protected(raw_jwt),
           %{fields: _} = jwk <- keyset[key_id],
           {true, _jwt, _jws} = result <- JOSE.JWT.verify_strict(jwk, alg_whitelist, raw_jwt) do
        result
      else
        {false, _, _} ->
          raise Oauth2TokenVerificationError, "Oauth2 token invalid: signature mismatch"

        nil ->
          raise Oauth2TokenVerificationError, "Oauth2 token invalid: unknown signing key"

        other ->
          other
      end
    end

    defp verify_jwt(raw_jwt, _keyset, _alg_whitelist, true) do
      Logger.warn("Token signature NOT verified! For dev/test use only!")
      {:ok, jwt} = peek_payload(raw_jwt)
      {true, jwt, "signature"}
    end

    defp peek_protected(raw_jwt) do
      try do
        with %{fields: %{"kid" => key_id}} <- JOSE.JWT.peek_protected(raw_jwt) do
          {:ok, key_id}
        else
          _ -> raise Oauth2TokenVerificationError, "Oauth2 token invalid: no key ID in JWT header"
        end
      rescue
        error ->
          case error do
            %Oauth2TokenVerificationError{} -> reraise error, __STACKTRACE__
            _ -> raise Oauth2TokenVerificationError, "Oauth2 token invalid: could not decode JWT"
          end
      end
    end

    defp peek_payload(raw_jwt) do
      try do
        payload = JOSE.JWT.peek_payload(raw_jwt)
        {:ok, payload}
      rescue
        _ -> raise Oauth2TokenVerificationError, "Oauth2 token invalid: could not decode JWT"
      end
    end

    defp verify_exp(jwt) do
      with %{fields: %{"exp" => exp}} when is_integer(exp) <- jwt,
           true <- exp > DateTime.utc_now() |> DateTime.to_unix(:second) do
        :ok
      else
        _ -> raise Oauth2TokenVerificationError, "Oauth2 token invalid: expired"
      end
    end

    defp verify_iss(jwt, exp_iss) do
      with %{fields: %{"iss" => ^exp_iss}} <- jwt do
        :ok
      else
        _ -> raise Oauth2TokenVerificationError, "Oauth2 token invalid: issuer mismatch"
      end
    end
  end
end
