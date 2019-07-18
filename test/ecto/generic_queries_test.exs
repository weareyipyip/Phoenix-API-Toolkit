defmodule PhoenixApiToolkit.Ecto.GenericQueriesTest do
  use ExUnit.Case, async: true

  import PhoenixApiToolkit.Ecto.GenericQueries
  require Ecto.Query

  doctest PhoenixApiToolkit.Ecto.GenericQueries

  def base_query(), do: Ecto.Query.from(user in "users", as: :user)
end
