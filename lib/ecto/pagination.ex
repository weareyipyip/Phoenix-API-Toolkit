defmodule PhoenixApiToolkit.Ecto.Pagination do
  @moduledoc """
  Helper functions for pagination.
  """
  import Ecto.Query

  @doc """
  Paginate the query by specifying a limit and/or offset.

  Note: must be called after all filters have been added to the query.

  The limit and/or offset will be applied to the primary model.

      iex> base_query()
      ...> |> paginate(%{})
      #Ecto.Query<from u0 in "users", as: :user>

      iex> base_query()
      ...> |> paginate(%{limit: 10})
      #Ecto.Query<from u0 in "users", as: :user, where: u0.id in subquery(from u0 in "users",
        as: :user,
        limit: ^10,
        select: u0.id)>

      iex> base_query()
      ...> |> paginate(%{offset: 10})
      #Ecto.Query<from u0 in "users", as: :user, where: u0.id in subquery(from u0 in "users",
        as: :user,
        offset: ^10,
        select: u0.id)>

      iex> base_query()
      ...> |> paginate(%{limit: 10, offset: 10})
      #Ecto.Query<from u0 in "users", as: :user, where: u0.id in subquery(from u0 in "users",
        as: :user,
        limit: ^10,
        offset: ^10,
        select: u0.id)>

      iex> query = base_query()
      ...> |> join(:left, [u], e in assoc(u, :email_addresses), as: :email_addresses)
      ...> |> where([email_addresses: e], e.is_verified)
      ...> |> paginate(%{offset: 20, limit: 10})
      #Ecto.Query<from u0 in "users", as: :user, left_join: e1 in assoc(u0, :email_addresses), as: :email_addresses, where: e1.is_verified, where: u0.id in subquery(from u0 in "users",
        as: :user,
        left_join: e1 in assoc(u0, :email_addresses),
        as: :email_addresses,
        where: e1.is_verified,
        limit: ^10,
        offset: ^20,
        select: u0.id)>
  """
  @spec paginate(Ecto.Query.t(), map) :: Ecto.Query.t()
  def paginate(query, filters) do
    offset = Map.get(filters, :offset)
    limit = Map.get(filters, :limit)

    paginate(query, offset, limit)
  end

  defp paginate(query, nil, nil), do: query

  defp paginate(query, offset, limit) do
    ids_query =
      query
      |> maybe_filter_offset(offset)
      |> maybe_filter_limit(limit)
      |> select([m], m.id)

    query
    |> where([m], m.id in subquery(ids_query))
  end

  defp maybe_filter_offset(query, nil), do: query
  defp maybe_filter_offset(query, offset), do: offset(query, ^offset)

  defp maybe_filter_limit(query, nil), do: query
  defp maybe_filter_limit(query, limit), do: limit(query, ^limit)
end
