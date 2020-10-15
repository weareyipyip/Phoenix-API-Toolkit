defmodule PhoenixApiToolkit.GenericRequestValidator do
  @moduledoc """
  Request validator for generic (REST) requests.
  Meant to supplement database-level Ecto changesets.
  For example when creating a new entity,
  your database contexts / changesets will do their own validations and it would
  be useless to do so an extra time.

  Suppose you have the following "users" resource:

   - GET    /api/users
   - GET    /api/users/{id}

  You could have the following resource request validator and controller. The users context
  is not present here, but if it uses `PhoenixApiToolkit.Ecto.DynamicFilters` the processed
  query parameters can be passed straight on and will result in a single filtered query.

  ```
  defmodule MyUsersRequestValidator do
    import Ecto.Changeset
    import PhoenixApiToolkit.Ecto.Validators
    import PhoenixApiToolkit.GenericRequestValidator

    @schema resource_schema(%{username: :string}, %{date_of_birth: :date})
    @entity_fields @schema |> get_entity_fields()

    def index_query(attrs) do
      @schema
      |> query_order_by(attrs)
      |> query_pagination(attrs)
      |> cast(attrs, @entity_fields)
      |> to_tuple()
    end
  end

  defmodule MyUsersController do
    use MyAppWeb, :controller
    import Plug.Conn

    alias MyUsersRequestValidator, as: ReqVal
    alias PhoenixApiToolkit.GenericRequestValidator, as: GenReqVal

    def index(conn, _params) do
      with {:ok, query_params} <- ReqVal.index_query(conn.query_params),
           users <- MyUsersContext.list(query_params) do
        conn |> send_resp(200, Jason.encode!(users))
      else
        _ -> conn |> send_resp(400, "idiot, your request is bad")
      end
    end

    def show(conn, _params) do
      with {:ok, %{id: id}} <- GenReqVal.path_param(conn.path_params),
           user when not is_nil(user) <- MyUsersContext.get(id) do
        conn |> send_resp(200, Jason.encode!(user))
      else
        _ -> conn |> send_resp(400, "idiot, your request is bad")
      end
    end
  end
  ```

  """
  import Ecto.Changeset

  import PhoenixApiToolkit.Ecto.Validators

  @typedoc "A simple Ecto schema, embedded only, not coupled to a module or database entity"
  @type schema :: {%{}, %{required(atom) => atom}}

  @doc """
  Creates a generic schema for a REST resource.

  In general, REST resources will support an integer `id` as a path parameter,
  and the index endpoint will support `order_by`, `limit` and `offset`.
  Additionally, some endpoints will support a `lock_version` for
  optimistic locking using `Ecto.Changeset.optimistic_lock/3`.

  Additional fields can be passed along to the `extra_fields` parameter. Fields that
  can (usefully) be compared with smaller than / greater than comparisons can be passed
  in `comparables`. The value you pass AND a "_lt" (smaller than) and "_gte"
  (greater than or equal to) variant will be added to the schema.

  ## Examples

      # the result can be fed to cast/3
      iex> resource_schema() |> Ecto.Changeset.cast(%{}, [])
      #Ecto.Changeset<action: nil, changes: %{}, errors: [], data: %{}, valid?: true>

      # an extended schema can be created by providing a map of fields
      iex> resource_schema(%{first_name: :string})
      {%{}, %{first_name: :string, id: :integer, limit: :integer, lock_version: :integer, offset: :integer, order_by: :string}}

      # fields passed to the "comparables" parameter are added literally AND with _lt and _gte variants
      iex> resource_schema(%{}, %{date_of_birth: :date}) |> elem(1) |> Map.has_key?(:date_of_birth_lt)
      true
  """
  @spec resource_schema(map) :: schema
  def resource_schema(extra_fields \\ %{}, comparables \\ %{}) do
    {
      %{},
      %{
        id: :integer,
        order_by: :string,
        limit: :integer,
        offset: :integer,
        lock_version: :integer
      }
      |> Map.merge(extra_fields)
      |> Map.merge(comparables)
      |> Map.merge(comparables |> create_comparables("lt"))
      |> Map.merge(comparables |> create_comparables("gte"))
    }
  end

  defp create_comparables(comparables, postfix) do
    comparables
    |> Stream.map(fn {field, type} -> {"#{field}_#{postfix}", type} end)
    |> Enum.map(fn {field, type} -> {String.to_atom(field), type} end)
    |> Enum.into(%{})
  end

  @doc """
  Get all the "non-meta" fields from a schema, that is, fields `[:limit, :offset, :order_by, :lock_version]`
  are filtered out.

  ## Examples

      iex> resource_schema(%{first_name: :string}) |> get_entity_fields()
      [:first_name, :id]
  """
  @spec get_entity_fields(schema) :: [atom]
  def get_entity_fields(schema) do
    schema
    |> elem(1)
    |> Map.drop([:limit, :offset, :order_by, :lock_version])
    |> Map.keys()
  end

  @doc """
  Validates the path parameter of a generic GET request of a RESTful resource.

  Returns an `:ok` or `:error` tuple.

  ## Examples

      # "id" is a required parameter
      iex> path_param(%{}) |> elem(0)
      :error

      # "id" must be an integer
      iex> path_param(%{"id" => "boom"}) |> elem(0)
      :error

      # "id" must be greater than 0
      iex> path_param(%{"id" => 0}) |> elem(0)
      :error

      iex> path_param(%{"id" => 1}) |> elem(0)
      :ok

  """
  @spec path_param(map()) :: {:error, Ecto.Changeset.t()} | {:ok, map()}
  def path_param(attrs) do
    {%{}, %{id: :integer}}
    |> cast(attrs, [:id])
    |> validate_required([:id])
    |> validate_number(:id, greater_than: 0)
    |> to_tuple()
  end

  @doc """
  Validates the `order_by` query parameter of an index endpoint.

  ## Examples

      iex> resource_schema() |> query_order_by(%{"order_by" => "asc:last_name"}, ~w(last_name) |> MapSet.new())
      #Ecto.Changeset<action: nil, changes: %{order_by: {:last_name, :asc}}, errors: [], data: %{}, valid?: true>

  See `PhoenixApiToolkit.Ecto.Validators.validate_order_by/2` for more examples.
  """
  @spec query_order_by(map() | Ecto.Changeset.t() | schema, map(), Enum.t()) :: Ecto.Changeset.t()
  def query_order_by(changeset, attrs, orderables) do
    changeset
    |> cast(attrs, [:order_by])
    |> validate_order_by(orderables)
  end

  @doc """
  Validates the `limit` and `offset` query parameters of an index endpoint. If `max_limit == nil`, no maximum limit is enforced.

  ## Examples

      # the requested limit and offset should be in the range 0 - max_limit
      iex> resource_schema() |> query_pagination(%{"limit" => 10}, 100)
      #Ecto.Changeset<action: nil, changes: %{limit: 10}, errors: [], data: %{}, valid?: true>

      iex> cs = resource_schema() |> query_pagination(%{"limit" => 150}, 100)
      iex> cs.valid?
      false

      # a default limit can be set so that a default number of results is returned
      iex> resource_schema() |> query_pagination(%{}, 100, 50)
      #Ecto.Changeset<action: nil, changes: %{limit: 50}, errors: [], data: %{}, valid?: true>

      # no max limit is enforced if `max_limit == nil`
      iex> resource_schema() |> query_pagination(%{"limit" => 1_000_000}, nil)
      #Ecto.Changeset<action: nil, changes: %{limit: 1000000}, errors: [], data: %{}, valid?: true>

      # default limit can be disabled
      iex> resource_schema() |> query_pagination(%{}, nil, nil)
      #Ecto.Changeset<action: nil, changes: %{}, errors: [], data: %{}, valid?: true>
  """
  @spec query_pagination(
          map() | Ecto.Changeset.t() | schema,
          map(),
          integer() | nil,
          integer() | nil
        ) :: Ecto.Changeset.t()
  def query_pagination(changeset, attrs, max_limit \\ 100, default_limit \\ 50) do
    changeset
    |> cast(attrs, [:limit, :offset])
    |> validate_default_limit(default_limit)
    |> validate_number(:limit, greater_than_or_equal_to: 0)
    |> validate_number(:offset, greater_than_or_equal_to: 0)
    |> validate_max_limit(max_limit)
  end

  ###########
  # Private #
  ###########

  defp validate_max_limit(cs, nil), do: cs

  defp validate_max_limit(cs, max_limit) do
    cs
    |> validate_required(:limit)
    |> validate_number(:limit, less_than_or_equal_to: max_limit)
  end

  defp validate_default_limit(cs, nil), do: cs

  defp validate_default_limit(cs, default_limit),
    do: put_change_if_unchanged(cs, :limit, default_limit)
end
