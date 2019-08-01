defmodule PhoenixApiToolkit.Ecto.GenericQueries do
  @moduledoc """
  Generic queries are applicable to any named binding in a query. By using
  generic queries, it is not necessary to implement standard queries for every Ecto model.

  For example, instead of implementing in a User model:

      def by_username(query, username) do
        from [user: user] in query, where: user.username == ^username
      end

      User.by_username(query, "some username")

  ...you can use generic query `equals/4` instead:

      GenericQueries.equals(query, :user, :username, "some username")

  Such generic queries can be combined together in complex ways:

      iex> base_query()
      #Ecto.Query<from u0 in "users", as: :user>

      iex> base_query()
      ...> |> equals(:user, :name, "Peter")
      ...> |> smaller_than(:user, :balance, 50.00)
      #Ecto.Query<from u0 in "users", as: :user, where: u0.name == ^"Peter", where: u0.balance < ^50.0>

  Most of these generic queries rely on named bindings to do their work. That's why it's probably
  a good idea to always name all bindings in your queries, and not rely on positional bindings
  to separate models in your queries.
  """
  alias Ecto.Query
  require Ecto.Query

  @typedoc "The directions supported by `order_by/4`"
  @type order_directions ::
          :asc | :asc_nulls_first | :asc_nulls_last | :desc | :desc_nulls_first | :desc_nulls_last

  @doc """
  Narrow down the query to results in which the value contained in
  `binding.field` is smaller than `value`.

      iex> base_query()
      #Ecto.Query<from u0 in "users", as: :user>

      iex> smaller_than(base_query(), :user, :balance, 50.00)
      #Ecto.Query<from u0 in "users", as: :user, where: u0.balance < ^50.0>
  """
  @spec smaller_than(Query.t(), atom, atom, any) :: Query.t()
  def smaller_than(query, binding, field, value),
    do: Query.from([{^binding, bd}] in query, where: field(bd, ^field) < ^value)

  @doc """
  Narrow down the query to results in which the value contained in
  `binding.field` is greater than or equal to `value`.

      iex> base_query()
      #Ecto.Query<from u0 in "users", as: :user>

      iex> greater_than_or_equals(base_query(), :user, :balance, 50.00)
      #Ecto.Query<from u0 in "users", as: :user, where: u0.balance >= ^50.0>
  """
  @spec greater_than_or_equals(Query.t(), atom, atom, any) :: Query.t()
  def greater_than_or_equals(query, binding, field, value),
    do: Query.from([{^binding, bd}] in query, where: field(bd, ^field) >= ^value)

  @doc """
  Narrow down the query to results in which the value of `binding.field` is
  equal to `value`. If `value` is a list, results that are equal to any list
  element are returned.

      iex> base_query()
      #Ecto.Query<from u0 in "users", as: :user>

      iex> equals(base_query(), :user, :name, "Peter")
      #Ecto.Query<from u0 in "users", as: :user, where: u0.name == ^"Peter">

      iex> equals(base_query(), :user, :name, ["Peter", "Patrick"])
      #Ecto.Query<from u0 in "users", as: :user, where: u0.name in ^["Peter", "Patrick"]>
  """
  @spec equals(Query.t(), atom, atom, any) :: Query.t()
  def equals(query, binding, field, value) when is_list(value),
    do: Query.from([{^binding, bd}] in query, where: field(bd, ^field) in ^value)

  def equals(query, binding, field, value),
    do: Query.from([{^binding, bd}] in query, where: field(bd, ^field) == ^value)

  @doc """
  Narrow down the query to results in which `value` is a member of the set of
  values contained in `field.binding`. Use with array-type Ecto fields.

      iex> base_query()
      #Ecto.Query<from u0 in "users", as: :user>

      iex> member_of(base_query(), :user, :roles, "admin")
      #Ecto.Query<from u0 in "users", as: :user, where: ^"admin" in u0.roles>
  """
  @spec member_of(Query.t(), atom, atom, any) :: Query.t()
  def member_of(query, binding, field, value),
    do: Query.from([{^binding, bd}] in query, where: ^value in field(bd, ^field))

  @doc """
  Order the query by `binding.field` in `direction`.

      iex> base_query()
      #Ecto.Query<from u0 in "users", as: :user>

      iex> order_by(base_query(), :user, :name, :asc_nulls_first)
      #Ecto.Query<from u0 in "users", as: :user, order_by: [asc_nulls_first: u0.name]>
  """
  @spec order_by(Query.t(), atom, atom, order_directions) :: Query.t()
  def order_by(query, binding, field, direction),
    do: Query.from([{^binding, bd}] in query, order_by: [{^direction, field(bd, ^field)}])

  @doc """
  Offset the query results by `value`.

      iex> base_query()
      #Ecto.Query<from u0 in "users", as: :user>

      iex> offset(base_query(), 10)
      #Ecto.Query<from u0 in "users", as: :user, offset: ^10>
  """
  @spec offset(Query.t(), integer) :: Query.t()
  def offset(query, value), do: Query.offset(query, ^value)

  @doc """
  Limit the query result set size to `value`.

      iex> base_query()
      #Ecto.Query<from u0 in "users", as: :user>

      iex> limit(base_query(), 10)
      #Ecto.Query<from u0 in "users", as: :user, limit: ^10>
  """
  @spec limit(Query.t(), integer) :: Query.t()
  def limit(query, value), do: Query.limit(query, ^value)
end
