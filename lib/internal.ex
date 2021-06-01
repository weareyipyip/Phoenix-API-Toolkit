defmodule PhoenixApiToolkit.Internal do
  @moduledoc false
  # helper functions for macros that cannot be defp because they cannot be expanded
  # put in separate module to prevent accidental import into lib users' code

  @doc false
  def parse_order_by({dir, {bnd, fld}}, _def_bnd, _aliases) do
    {dir, bnd, fld}
  end

  def parse_order_by({dir, fld}, def_bnd, aliases) do
    {bnd, fld} = Keyword.get(aliases, fld, {def_bnd, fld})
    {dir, bnd, fld}
  end

  def parse_order_by(fld, def_bnd, aliases) do
    parse_order_by({:asc, fld}, def_bnd, aliases)
  end

  # OTP 22 introduced a new crypto API, and the old one is hard deprecated in OTP 24
  # we differentiate between the two at compile time
  if :erlang.system_info(:otp_release) |> to_string() |> String.to_integer() < 22 do
    @doc false
    def hmac(alg, secret, body), do: :crypto.hmac(alg, secret, body)
  else
    @doc false
    def hmac(alg, secret, body), do: :crypto.mac(:hmac, alg, secret, body)
  end
end
