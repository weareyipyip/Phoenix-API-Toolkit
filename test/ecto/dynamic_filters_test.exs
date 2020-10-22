defmodule PhoenixApiToolkit.Ecto.DynamicFiltersTest do
  use ExUnit.Case, async: true
  import PhoenixApiToolkit.Ecto.DynamicFilters
  import Ecto.Query
  require Ecto.Query

  @filter_definitions [
    literals: [:id, :username, :address, :balance],
    sets: [:roles],
    smaller_than: [
      inserted_before: :inserted_at,
      balance_lt: :balance
    ],
    greater_than_or_equals: [
      inserted_at_or_after: :inserted_at,
      balance_gte: :balance
    ]
  ]

  def list_without_standard_filters(filters \\ %{}) do
    from(user in "users", as: :user)
    |> apply_filters(filters, fn
      {"order_by", {field, direction}}, query ->
        order_by(query, [user: user], [{^direction, field(user, ^field)}])

      {literal, value}, query when literal in ["id", "name", "residence", "address"] ->
        literal = String.to_atom(literal)
        where(query, [user: user], field(user, ^literal) == ^value)

      _, query ->
        query
    end)
  end

  def by_group_name(query, group_name) do
    from(
      [user: user] in query,
      join: group in assoc(user, :group),
      as: :group,
      where: group.name == ^group_name
    )
  end

  def list_with_standard_filters(filters \\ %{}) do
    from(user in "users", as: :user)
    |> apply_filters(filters, fn
      # Add custom filters first and fallback to standard filters
      {"group_name", value}, query -> by_group_name(query, value)
      filter, query -> standard_filters(query, filter, :user, @filter_definitions)
    end)
  end

  doctest PhoenixApiToolkit.Ecto.DynamicFilters
end
