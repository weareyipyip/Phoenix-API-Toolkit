defmodule PhoenixApiToolkit.Ecto.DynamicFiltersTest do
  use ExUnit.Case, async: true

  alias PhoenixApiToolkit.Ecto.GenericQueries
  import PhoenixApiToolkit.Ecto.DynamicFilters
  import Ecto.Query

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
      {:order_by, {field, direction}}, query ->
        GenericQueries.order_by(query, :user, field, direction)

      {literal, value}, query when literal in [:id, :name, :residence, :address] ->
        GenericQueries.equals(query, :user, literal, value)

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
      {:group_name, value}, query -> by_group_name(query, value)
      filter, query -> standard_filters(query, filter, :user, @filter_definitions)
    end)
  end

  doctest PhoenixApiToolkit.Ecto.DynamicFilters
end
