defmodule PhoenixApiToolkit.Security.HmacPlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhoenixApiToolkit.Security.HmacPlug
  alias PhoenixApiToolkit.Security.HmacVerificationError
  import PhoenixApiToolkit.TestHelpers
  import PhoenixApiToolkit.CacheBodyReader

  @opts HmacPlug.init(hmac_secret: test_hmac_secret())

  def conn_for_hmac(method, path, raw_body) do
    conn(method, path, raw_body |> Jason.decode!())
    |> application_json()
    |> put_raw_body(raw_body)
  end

  doctest HmacPlug

  defp error_message(reason), do: "HMAC invalid: #{reason}"

  describe "HMAC plug" do
    test "init raises if mandatory parameters are missing" do
      mandatory_params = [:hmac_secret]

      for param <- mandatory_params do
        assert_raise ArgumentError, "key \"#{param}\" not found", fn ->
          @opts |> Map.drop([param]) |> Keyword.new() |> HmacPlug.init()
        end
      end
    end

    test "init uses defaults for optional parameters" do
      optional_params = [:max_age, :hash_algorithm]

      for param <- optional_params do
        assert %{^param => _} = @opts |> Map.drop([param]) |> Keyword.new() |> HmacPlug.init()
      end
    end

    test "should reject a request with a missing authorization header" do
      body = create_hmac_plug_body("/", "POST", %{})
      {:ok, _, conn} = conn_for_hmac(:post, "/", body) |> cache_and_read_body()

      assert_raise HmacVerificationError, error_message("missing authorization header"), fn ->
        conn |> HmacPlug.call(@opts)
      end
    end

    test "should reject a request signed with another algorithm" do
      body = create_hmac_plug_body("/", "POST", %{})
      {:ok, _, conn} = conn_for_hmac(:post, "/", body) |> put_hmac(body) |> cache_and_read_body()

      assert_raise HmacVerificationError, error_message("hash mismatch"), fn ->
        conn |> HmacPlug.call(Map.put(@opts, :hash_algorithm, :sha512))
      end
    end

    test "should reject a request with an invalid signature" do
      body = create_hmac_plug_body("/", "POST", %{})

      {:ok, _, conn} =
        conn_for_hmac(:post, "/", body)
        |> put_req_header("authorization", "nonsense")
        |> cache_and_read_body()

      assert_raise HmacVerificationError, error_message("hash mismatch"), fn ->
        conn |> HmacPlug.call(@opts)
      end
    end

    test "should reject a request with missing fields in the request body" do
      mandatory_fields = ["timestamp", "method", "path"]

      for field <- mandatory_fields do
        body =
          create_hmac_plug_body("/", "POST", %{})
          |> Jason.decode!()
          |> Map.drop([field])
          |> Jason.encode!()

        {:ok, _, conn} =
          conn_for_hmac(:post, "/", body) |> put_hmac(body) |> cache_and_read_body()

        assert_raise HmacVerificationError, error_message("#{field} missing"), fn ->
          conn |> HmacPlug.call(@opts)
        end
      end
    end

    test "should reject a request without a matching path" do
      body = create_hmac_plug_body("/other/path", "POST", %{})
      {:ok, _, conn} = conn_for_hmac(:post, "/", body) |> put_hmac(body) |> cache_and_read_body()

      assert_raise HmacVerificationError, error_message("path mismatch"), fn ->
        conn |> HmacPlug.call(@opts)
      end
    end

    test "should reject a request without a matching method" do
      body = create_hmac_plug_body("/", "PUT", %{})
      {:ok, _, conn} = conn_for_hmac(:post, "/", body) |> put_hmac(body) |> cache_and_read_body()

      assert_raise HmacVerificationError, error_message("method mismatch"), fn ->
        conn |> HmacPlug.call(@opts)
      end
    end

    test "should reject a request with an expired timestamp" do
      timestamp = (DateTime.utc_now() |> DateTime.to_unix()) - @opts[:max_age] - 1
      body = create_hmac_plug_body("/", "POST", %{}, timestamp)
      {:ok, _, conn} = conn_for_hmac(:post, "/", body) |> put_hmac(body) |> cache_and_read_body()

      assert_raise HmacVerificationError, error_message("expired"), fn ->
        conn |> HmacPlug.call(@opts)
      end
    end

    test "should allow a valid request" do
      body = create_hmac_plug_body("/", "POST", %{})
      {:ok, _, conn} = conn_for_hmac(:post, "/", body) |> put_hmac(body) |> cache_and_read_body()
      assert %Plug.Conn{} = conn |> HmacPlug.call(@opts)
    end
  end
end
