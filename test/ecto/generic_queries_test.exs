defmodule PhoenixApiToolkit.Ecto.GenericQueriesTest do
  use ExUnit.Case, async: true

  import PhoenixApiToolkit.Ecto.GenericQueries
  require Ecto.Query

  def base_query(), do: Ecto.Query.from(user in "users", as: :user)

  doctest PhoenixApiToolkit.Ecto.GenericQueries
end
