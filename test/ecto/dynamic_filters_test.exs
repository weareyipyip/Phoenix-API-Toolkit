defmodule PhoenixApiToolkit.Ecto.DynamicFiltersTest do
  use ExUnit.Case, async: true
  import PhoenixApiToolkit.Ecto.DynamicFilters
  import Ecto.Query
  require Ecto.Query

  @filter_definitions [
    atom_keys: true,
    string_keys: true,
    limit: true,
    offset: true,
    order_by: true,
    literals: [:id, :username, :address, :balance, role_name: {:role, :name}],
    or_lists: [:address],
    prefix_search: [username_prefix: {:user, :username}],
    search: [username_search: :username],
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

  def resolve_binding(query, named_binding) do
    if has_named_binding?(query, named_binding) do
      query
    else
      case named_binding do
        :role -> join(query, :left, [user: user], role in "roles", as: :role)
        _ -> query
      end
    end
  end

  def list_without_standard_filters(filters \\ %{}) do
    from(user in "users", as: :user)
    |> apply_filters(filters, fn
      {:order_by, {field, direction}}, query ->
        order_by(query, [user: user], [{^direction, field(user, ^field)}])

      {literal, value}, query when literal in [:id, :name, :residence, :address] ->
        where(query, [user: user], field(user, ^literal) == ^value)

      _, query ->
        query
    end)
  end

  def by_group_name(query, group_name) do
    where(query, [user: user], user.group_name == ^group_name)
  end

  def list_with_standard_filters(filters \\ %{}) do
    from(user in "users", as: :user)
    |> apply_filters(filters, fn
      # Add custom filters first and fallback to standard filters
      {:group_name, value}, query ->
        by_group_name(query, value)

      filter, query ->
        standard_filters(query, filter, :user, @filter_definitions, &resolve_binding/2)
    end)
  end

  doctest PhoenixApiToolkit.Ecto.DynamicFilters
end
