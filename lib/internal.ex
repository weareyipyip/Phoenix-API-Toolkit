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
end
