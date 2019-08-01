defmodule PhoenixApiToolkit.Security.PlugsTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import PhoenixApiToolkit.Security.Plugs
  alias PhoenixApiToolkit.Security.Oauth2TokenVerificationError

  def conn_with_ip, do: conn(:get, "/") |> Map.put(:remote_ip, {127, 0, 0, 12})
  def conn_with_scope(scope), do: conn(:get, "/") |> assign(:jwt, %{fields: %{"scope" => scope}})
  def conn_with_aud(aud), do: conn(:get, "/") |> assign(:jwt, %{fields: %{"aud" => aud}})

  doctest PhoenixApiToolkit.Security.Plugs

  describe "verify_oauth2_scope" do
    test "should raise predictably if conn.assigns map is malformed" do
      assigns = [
        %{jwt: %{fields: %{"scope" => nil}}},
        %{jwt: %{fields: %{"scope" => true}}},
        %{jwt: %{fields: %{"scope" => 1}}},
        %{jwt: %{fields: nil}},
        %{jwt: nil},
        %{}
      ]

      for assigns <- assigns do
        assert_raise Oauth2TokenVerificationError, fn ->
          conn(:get, "/") |> Map.put(:assigns, assigns) |> verify_oauth2_scope(["admin"])
        end
      end
    end
  end
end
