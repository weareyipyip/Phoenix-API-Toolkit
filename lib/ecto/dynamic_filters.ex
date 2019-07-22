defmodule PhoenixApiToolkit.Ecto.DynamicFilters do
  @moduledoc """
  Dynamic filtering of Ecto queries is useful for creating list/index functions,
  and ultimately list/index endpoints, that accept a map of filters to apply to the query.
  Such a map can be based on HTTP query parameters, naturally.

  This module complements `PhoenixApiToolkit.Ecto.GenericQueries` by leveraging the generic
  queries provided by that module to filter a query dynamically based on a parameter map.

  Several filtering types are so common that they have been implemented using standard filter
  macro's. This way, you only have to define which fields are filterable in what way.

  ## Example without standard filters

      def list_without_standard_filters(filters \\\\ %{}) do
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

      # filtering is optional
      iex> list_without_standard_filters()
      #Ecto.Query<from u0 in "users", as: :user>

      # multiple literal matches can be combined
      iex> list_without_standard_filters(%{residence: "New York", address: "Main Street"})
      #Ecto.Query<from u0 in "users", as: :user, where: u0.address == ^"Main Street", where: u0.residence == ^"New York">

      # literal matches and sorting can be combined
      iex> list_without_standard_filters(%{residence: "New York", order_by: {:name, :desc}})
      #Ecto.Query<from u0 in "users", as: :user, where: u0.residence == ^"New York", order_by: [desc: u0.name]>

      # other fields are ignored / passed through
      iex> list_without_standard_filters(%{number_of_arms: 3})
      #Ecto.Query<from u0 in "users", as: :user>

  ## Example with standard filters with module attributes

  The easiest to use and recommended form of standard filtering is the `standard_filters/2` macro,
  which reads several module attributes from the module in which it is used to provide its functionality.

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

      def by_username_prefix(query, prefix) do
        from(user in query, where: ilike(user.username, ^"\#{prefix}%"))
      end

      def list_with_standard_filters_and_attributes(filters \\\\ %{}) do
        from(user in "users", as: :user)
        |> apply_filters(filters, fn
          # Add custom filters first and fallback to standard filters
          {:username_prefix, value}, query -> by_username_prefix(query, value)
          filter, query -> standard_filters(query, filter)
        end)
      end

      # filtering is optional
      iex> list_with_standard_filters_and_attributes()
      #Ecto.Query<from u0 in "users", as: :user>

      # let's do some filtering
      iex> list_with_standard_filters_and_attributes(%{username: "Peter", inserted_before: DateTime.from_unix!(155555555)})
      #Ecto.Query<from u0 in "users", as: :user, where: u0.inserted_at < ^~U[1974-12-06 09:52:35Z], where: u0.username == ^"Peter">

      # limit, offset, and order_by are supported
      iex> list_with_standard_filters_and_attributes(%{limit: 10, offset: 1, order_by: {:username, :desc}})
      #Ecto.Query<from u0 in "users", as: :user, order_by: [desc: u0.username], limit: ^10, offset: ^1>

      # complex custom filters can be combined with the standard filters
      iex> list_with_standard_filters_and_attributes(%{username_prefix: "Pete"})
      #Ecto.Query<from u0 in "users", as: :user, where: ilike(u0.username, ^"Pete%")>

      # other fields are ignored / passed through
      iex> list_with_standard_filters_and_attributes(%{number_of_arms: 3, order_by: {:boom, :asc}})
      #Ecto.Query<from u0 in "users", as: :user>

  ## Example with standard filters

  It is possible to use the standard filters macro without using module attributes,
  by specifying (some of) the macro parameters directly.

      def list_with_standard_filters(filters \\\\ %{}) do
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

      # filtering is optional
      iex> list_with_standard_filters()
      #Ecto.Query<from u0 in "users", as: :user>

      # let's do some filtering
      iex> list_with_standard_filters(%{username: "Peter"})
      #Ecto.Query<from u0 in "users", as: :user, where: u0.username == ^"Peter">
  """

  alias PhoenixApiToolkit.Ecto.GenericQueries
  @type filter :: {atom(), any()}

  @doc """
  Applies `filters` to `query` by reducing `filters` using `filter_reductor`.
  Combine with the generic queries from `PhoenixApiToolkit.Ecto.GenericQueries` to write complex
  filterables. Several standard filters have been implemented in
  `standard_filters/2` and `standard_filters/7`.

  See the module docs `#{__MODULE__}` for details and examples.
  """
  @spec apply_filters(Query.t(), map(), (Query.t(), filter -> Query.t())) :: Query.t()
  def apply_filters(query, filters, filter_reductor) do
    Enum.reduce(filters, query, filter_reductor)
  end

  @doc """
  Applies standard filters to the query. Standard
  filters include filters for literal matches, datetime relatives, set membership,
  ordering and pagination.

  See the module docs `#{__MODULE__}` for details and examples.

  This macro requires the following parameters:
    - `main_binding`: the named binding of the Ecto model that generic queries are applied to
    - `literals`: fields comparable by `PhoenixApiToolkit.Ecto.GenericQueries.equals/4`
    - `sets`: fields comparable by `PhoenixApiToolkit.Ecto.GenericQueries.member_of/4`
    - `smaller_than_map`: map of virtual "smaller_than_" fields and the actual fields comparable by `PhoenixApiToolkit.Ecto.GenericQueries.smaller_than/4`
    - `smaller_than`: keys of `smaller_than_map`
    - `greater_than_or_equals_map`: map of virtual "greater_than_or_equals_" fields and the actual fields comparable by `PhoenixApiToolkit.Ecto.GenericQueries.greater_than_or_equals/4`
    - `greater_than_or_equals`: keys of `greater_than_or_equals_map`
  """
  defmacro standard_filters(
             query,
             filter,
             main_binding,
             literals,
             sets,
             smaller_than_map,
             greater_than_or_equals_map
           ) do
    {:%{}, _, my_map_as_keyword_list} = smaller_than_map |> Macro.expand(__CALLER__)
    smaller_than_fields = Keyword.keys(my_map_as_keyword_list)
    {:%{}, _, my_map_as_keyword_list} = greater_than_or_equals_map |> Macro.expand(__CALLER__)
    greater_than_or_equals_fields = Keyword.keys(my_map_as_keyword_list)

    quote generated: true do
      query = unquote(query)
      main_binding = unquote(main_binding)

      case unquote(filter) do
        {:limit, value} ->
          GenericQueries.limit(query, value)

        {:offset, value} ->
          GenericQueries.offset(query, value)

        {:order_by, {field, direction}} when field in unquote(literals) ->
          GenericQueries.order_by(query, main_binding, field, direction)

        {field, value} when field in unquote(literals) ->
          GenericQueries.equals(query, main_binding, field, value)

        {field, value} when field in unquote(sets) ->
          GenericQueries.member_of(query, main_binding, field, value)

        {field, value} when field in unquote(smaller_than_fields) ->
          GenericQueries.smaller_than(
            query,
            main_binding,
            unquote(smaller_than_map)[field],
            value
          )

        {field, value} when field in unquote(greater_than_or_equals_fields) ->
          GenericQueries.greater_than_or_equals(
            query,
            main_binding,
            unquote(greater_than_or_equals_map)[field],
            value
          )

        _ ->
          query
      end
    end
  end

  @doc """
  Applies standard filters to the query. Standard
  filters include filters for literal matches, datetime relatives, set membership,
  ordering and pagination.

  See the module docs `#{__MODULE__}` for details and examples.

  This macro requires that the following module attributes have been set:
    - `@main_binding`: the named binding of the Ecto model that generic queries are applied to
    - `@literals`: fields comparable by `PhoenixApiToolkit.Ecto.GenericQueries.equals/4`
    - `@sets`: fields comparable by `PhoenixApiToolkit.Ecto.GenericQueries.member_of/4`
    - `@smaller_than_map`: map of virtual "smaller_than_" fields and the actual fields comparable by `PhoenixApiToolkit.Ecto.GenericQueries.smaller_than/4`
    - `@greater_than_or_equals_map`: map of virtual "greater_than_or_equals_" fields and the actual fields comparable by `PhoenixApiToolkit.Ecto.GenericQueries.greater_than_or_equals/4`

  If these module attributes cannot be used, please use the fully parameterized version of this
  macro, `standard_filters/7`.
  """
  defmacro standard_filters(query, filter) do
    quote do
      standard_filters(
        unquote(query),
        unquote(filter),
        @main_binding,
        @literals,
        @sets,
        @smaller_than_map,
        @greater_than_or_equals_map
      )
    end
  end
end
