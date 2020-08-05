defmodule PhoenixApiToolkit.Ecto.PaginationTest do
  use ExUnit.Case, async: true

  import PhoenixApiToolkit.Ecto.Pagination
  import Ecto.Query

  def base_query(), do: Ecto.Query.from(user in "users", as: :user)

  doctest PhoenixApiToolkit.Ecto.Pagination
end
