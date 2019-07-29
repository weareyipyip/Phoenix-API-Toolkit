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

  ## Example with standard filters

  Standard filters can be applied using the `standard_filters/4` macro. It supports various filtering styles:
  literal matches, set membership, smaller/greater than comparisons, ordering and pagination. These filters must
  be configured at compile time.


      @filter_definitions [
        literals: [:id, :username, :residence, :address],
        sets: [:roles],
        smaller_than: [
          inserted_before: :inserted_at,
          updated_before: :updated_at
        ],
        greater_than_or_equals: [
          inserted_at_or_after: :inserted_at,
          updated_at_or_after: :updated_at
        ]
      ]

      def by_username_prefix(query, prefix) do
        from(user in query, where: ilike(user.username, ^"\#{prefix}%"))
      end

      def list_with_standard_filters(filters \\\\ %{}) do
        from(user in "users", as: :user)
        |> apply_filters(filters, fn
          # Add custom filters first and fallback to standard filters
          {:username_prefix, value}, query -> by_username_prefix(query, value)
          filter, query -> standard_filters(query, filter, :user, @filter_definitions)
        end)
      end

      # filtering is optional
      iex> list_with_standard_filters()
      #Ecto.Query<from u0 in "users", as: :user>

      # let's do some filtering
      iex> list_with_standard_filters(%{username: "Peter", inserted_before: DateTime.from_unix!(155555555)})
      #Ecto.Query<from u0 in "users", as: :user, where: u0.inserted_at < ^~U[1974-12-06 09:52:35Z], where: u0.username == ^"Peter">

      # limit, offset, and order_by are supported
      iex> list_with_standard_filters(%{limit: 10, offset: 1, order_by: {:address, :desc}})
      #Ecto.Query<from u0 in "users", as: :user, order_by: [desc: u0.address], limit: ^10, offset: ^1>

      # complex custom filters can be combined with the standard filters
      iex> list_with_standard_filters(%{username_prefix: "Pete", updated_at_or_after: DateTime.from_unix!(155555555)})
      #Ecto.Query<from u0 in "users", as: :user, where: u0.updated_at >= ^~U[1974-12-06 09:52:35Z], where: ilike(u0.username, ^"Pete%")>

      # other fields are ignored / passed through
      iex> list_with_standard_filters(%{number_of_arms: 3, order_by: {:boom, :asc}})
      #Ecto.Query<from u0 in "users", as: :user>
  """

  import PhoenixApiToolkit.Ecto.GenericQueries

  @typedoc "Format of a filter that can be applied to a query to narrow it down"
  @type filter :: {atom(), any()}

  @doc """
  Applies `filters` to `query` by reducing `filters` using `filter_reductor`.
  Combine with the generic queries from `PhoenixApiToolkit.Ecto.GenericQueries` to write complex
  filterables. Several standard filters have been implemented in
  `standard_filters/4`.

  See the module docs `#{__MODULE__}` for details and examples.
  """
  @spec apply_filters(Query.t(), map(), (Query.t(), filter -> Query.t())) :: Query.t()
  def apply_filters(query, filters, filter_reductor) do
    Enum.reduce(filters, query, filter_reductor)
  end

  @typedoc """
  Filter definitions supported by `standard_filters/4`.
  A keyword list of filter types and the fields for which they should be generated.
  """
  @type filter_definitions :: [
          literals: [atom],
          sets: [atom],
          smaller_than: keyword(atom),
          greater_than_or_equals: keyword(atom)
        ]

  @doc """
  Applies standard filters to the query. Standard
  filters include filters for literal matches, set membership, smaller/greater than comparisons,
  ordering and pagination.

  See the module docs `#{__MODULE__}` for details and examples.

  Mandatory parameters:
  - `query`: the Ecto query that is narrowed down
  - `filter`: the current filter that is being applied to `query`
  - `main_binding`: the named binding of the Ecto model that generic queries are applied to
  - `filter_definitions`: keyword list of filter types and the fields for which they should be generated

  The options supported by the `filter_definitions` parameter are:
  - `literals`: fields comparable by `PhoenixApiToolkit.Ecto.GenericQueries.equals/4`, also the fields by which the query can be ordered by `PhoenixApiToolkit.Ecto.GenericQueries.order_by/4`
  - `sets`: fields comparable by `PhoenixApiToolkit.Ecto.GenericQueries.member_of/4`
  - `smaller_than`: keyword list of virtual "smaller_than" fields and the actual fields comparable by `PhoenixApiToolkit.Ecto.GenericQueries.smaller_than/4`
  - `greater_than_or_equals`: keyword list of virtual "greater_than_or_equals" fields and the actual fields comparable by `PhoenixApiToolkit.Ecto.GenericQueries.greater_than_or_equals/4`
  """
  @spec standard_filters(Query.t(), filter, atom, filter_definitions) :: any
  defmacro standard_filters(query, filter, main_binding, filter_definitions) do
    # Call Macro.expand/2 in case filter_definitions is a module attribute
    filters = filter_definitions |> Macro.expand(__CALLER__)

    # create clauses for the eventual case statement (as raw AST!)
    clauses =
      []
      |> add_clause(quote(do: {:limit, val}), quote(do: limit(query, val)))
      |> add_clause(quote(do: {:offset, val}), quote(do: offset(query, val)))
      |> add_clause_for_each(filters[:literals] || [], fn literal, clauses ->
        clauses
        |> add_clause(
          quote(do: {unquote(literal), val}),
          quote(do: equals(query, main_binding, unquote(literal), val))
        )
        |> add_clause(
          quote(do: {:order_by, {unquote(literal), direction}}),
          quote(do: order_by(query, main_binding, unquote(literal), direction))
        )
      end)
      |> add_clause_for_each(filters[:sets] || [], fn set, clauses ->
        add_clause(
          clauses,
          quote(do: {unquote(set), val}),
          quote(do: member_of(query, main_binding, unquote(set), val))
        )
      end)
      |> add_clause_for_each(filters[:smaller_than] || [], fn {fld, real_fld}, clauses ->
        add_clause(
          clauses,
          quote(do: {unquote(fld), val}),
          quote(do: smaller_than(query, main_binding, unquote(real_fld), val))
        )
      end)
      |> add_clause_for_each(
        filters[:greater_than_or_equals] || [],
        fn {fld, real_fld}, clauses ->
          add_clause(
            clauses,
            quote(do: {unquote(fld), val}),
            quote(do: greater_than_or_equals(query, main_binding, unquote(real_fld), val))
          )
        end
      )
      |> add_clause(quote(do: _), quote(do: query))

    # create the case statement based on the clauses
    quote generated: true do
      query = unquote(query)
      main_binding = unquote(main_binding)

      case unquote(filter), do: unquote(clauses)
    end
  end

  ############
  # Privates #
  ############

  defp add_clause(clauses, clause, block) do
    clauses ++ [{:->, [], [[clause], block]}]
  end

  defp add_clause_for_each(clauses, enumerable, reductor) do
    Enum.reduce(enumerable, clauses, reductor)
  end
end
