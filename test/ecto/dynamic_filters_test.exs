defmodule PhoenixApiToolkit.Ecto.DynamicFiltersTest do
  use ExUnit.Case, async: true

  alias PhoenixApiToolkit.Ecto.GenericQueries
  import PhoenixApiToolkit.Ecto.DynamicFilters
  import Ecto.Query

  @main_binding :user
  @literals ~w(id username residence address)a
  @sets ~w(roles)a
  @smaller_than_map %{
    inserted_before: :inserted_at,
    updated_before: :updated_at
  }
  @greater_than_or_equals_map %{
    inserted_at_or_after: :inserted_at,
    updated_at_or_after: :updated_at
  }

  def base_query, do: from(user in "users", as: :user)

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

  def by_username_prefix(query, prefix) do
    from(user in query, where: ilike(user.username, ^"#{prefix}%"))
  end

  def list_with_standard_filters_and_attributes(filters \\ %{}) do
    from(user in "users", as: :user)
    |> apply_filters(filters, fn
      # Add custom filters first and fallback to standard filters
      {:username_prefix, value}, query -> by_username_prefix(query, value)
      filter, query -> standard_filters(query, filter)
    end)
  end

  def list_with_standard_filters(filters \\ %{}) do
    from(user in "users", as: :user)
    |> apply_filters(filters, fn
      filter, query ->
        standard_filters(
          query,
          filter,
          :user,
          [:username],
          [:roles],
          @smaller_than_map,
          @greater_than_or_equals_map
        )
    end)
  end

  doctest PhoenixApiToolkit.Ecto.DynamicFilters
end
