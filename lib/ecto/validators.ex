defmodule PhoenixApiToolkit.Ecto.Validators do
  @moduledoc """
  Generic validators and helper functions for validating Ecto changesets.

  ## Examples

  The examples in this module use the following basic schema and changeset:

      @schema %{
        first_name: :string,
        last_name: :string,
        last_name_prefix: :string,
        order_by: :string,
        file: :string,
        mime_type: :string
      }

      def changeset(changes \\\\ %{}) do
        {%{}, @schema} |> cast(changes, [:first_name, :last_name, :order_by, :file])
      end
  """
  alias Ecto.Changeset
  import Ecto.Changeset
  require Logger

  @order_by_format ~r/^(asc|desc|asc_nulls_last|desc_nulls_last|asc_nulls_first|desc_nulls_first):(\w+)$/

  @doc """
  If the changeset does not contain a change for `field` - even if the field already
  has a value in the changeset data - set it to `change`. Useful for setting default changes.

  ## Examples
  For the implementation of `changeset/1`, see `#{__MODULE__}`.

      iex> changeset() |> default_change(:first_name, "Peter")
      #Ecto.Changeset<action: nil, changes: %{first_name: "Peter"}, errors: [], data: %{}, valid?: true>

      iex> changeset(%{first_name: "Jason"}) |> default_change(:first_name, "Peter")
      #Ecto.Changeset<action: nil, changes: %{first_name: "Jason"}, errors: [], data: %{}, valid?: true>
  """
  @spec default_change(Ecto.Changeset.t(), atom, any) :: Ecto.Changeset.t()
  def default_change(changeset, field, value)
  def default_change(cs, fld, val), do: put_change(cs, fld, get_change(cs, fld, val))

  @doc """
  Validates that `field` is a suitable parameter for an (i)like query.

  User input for (i)like queries should not contain metacharacters because this creates
  a denial-of-service attack vector: introducing a lot of metacharacters rapidly
  increases the performance costs of such queries. The metacharacters for (i)like queries
  are '_', '%' and the escape character of the database, which defaults to '\\'.

  ## Examples
  For the implementation of `changeset/1`, see `#{__MODULE__}`.

      iex> changeset(%{first_name: "Peter", last_name: "Pan"}) |> validate_ilike_safe([:first_name, :last_name])
      #Ecto.Changeset<action: nil, changes: %{first_name: "Peter", last_name: "Pan"}, errors: [], data: %{}, valid?: true>

      iex> changeset(%{first_name: "Peter%"}) |> validate_ilike_safe(:first_name)
      #Ecto.Changeset<action: nil, changes: %{first_name: "Peter%"}, errors: [first_name: {"may not contain _ % or \\\\", [validation: :format]}], data: %{}, valid?: false>

      iex> changeset(%{first_name: "Pet_er"}) |> validate_ilike_safe(:first_name)
      #Ecto.Changeset<action: nil, changes: %{first_name: "Pet_er"}, errors: [first_name: {"may not contain _ % or \\\\", [validation: :format]}], data: %{}, valid?: false>

      iex> changeset(%{first_name: "Pet\\\\er"}) |> validate_ilike_safe(:first_name)
      #Ecto.Changeset<action: nil, changes: %{first_name: "Pet\\\\er"}, errors: [first_name: {"may not contain _ % or \\\\", [validation: :format]}], data: %{}, valid?: false>
  """
  @spec validate_ilike_safe(Changeset.t(), atom | [atom]) :: Changeset.t()
  def validate_ilike_safe(changeset, fields) when is_list(fields),
    do: Enum.reduce(fields, changeset, &validate_ilike_safe(&2, &1))

  def validate_ilike_safe(changeset, field),
    do: validate_format(changeset, field, ~r/^[^\%_\\]*$/, message: "may not contain _ % or \\")

  @doc """
  Validates that `field` (or multiple fields) contains plaintext.

  ## Examples
  For the implementation of `changeset/1`, see `#{__MODULE__}`.

      iex> changeset(%{first_name: "Peter", last_name: "Pan"}) |> validate_plaintext([:first_name, :last_name])
      #Ecto.Changeset<action: nil, changes: %{first_name: "Peter", last_name: "Pan"}, errors: [], data: %{}, valid?: true>

      iex> changeset(%{first_name: "Peter{}"}) |> validate_plaintext(:first_name)
      #Ecto.Changeset<action: nil, changes: %{first_name: "Peter{}"}, errors: [first_name: {"can only contain a-Z 0-9 _ . , - ! ? and whitespace", [validation: :format]}], data: %{}, valid?: false>

  """
  @spec validate_plaintext(Changeset.t(), atom() | [atom()]) :: Changeset.t()
  def validate_plaintext(changeset, fields) when is_list(fields),
    do: Enum.reduce(fields, changeset, &validate_plaintext(&2, &1))

  def validate_plaintext(changeset, field) do
    changeset
    |> validate_format(field, ~r/^[\w\s\.\,\-\!\?]*$/,
      message: "can only contain a-Z 0-9 _ . , - ! ? and whitespace"
    )
  end

  @doc """
  Validate the value of an `order_by` query parameter. The format of the parameter
  is expected to match `#{@order_by_format |> inspect()}` (may be repeated, comma-separated).
  The supported fields should be passed as a list or `MapSet` (which performs better) to `orderables`.

  If the change is valid, the original change is replaced with a keyword list of
  `{:field, :direction}`, which is supported by `PhoenixApiToolkit.Ecto.DynamicFilters.standard_filters/6`.

  ## Examples
  For the implementation of `changeset/1`, see `#{__MODULE__}`.

      @orderables ~w(first_name last_name) |> MapSet.new()

      iex> changeset(%{order_by: "asc:last_name"}) |> validate_order_by(@orderables)
      #Ecto.Changeset<action: nil, changes: %{order_by: [asc: :last_name]}, errors: [], data: %{}, valid?: true>

      iex> changeset(%{order_by: "invalid"}) |> validate_order_by(@orderables)
      #Ecto.Changeset<action: nil, changes: %{order_by: []}, errors: [order_by: {"format is asc|desc:field", []}], data: %{}, valid?: false>

      iex> changeset(%{order_by: "asc:eye_count"}) |> validate_order_by(@orderables)
      #Ecto.Changeset<action: nil, changes: %{order_by: []}, errors: [order_by: {"unknown field eye_count", []}], data: %{}, valid?: false>

      iex> changeset(%{order_by: nil}) |> validate_order_by(@orderables)
      #Ecto.Changeset<action: nil, changes: %{}, errors: [], data: %{}, valid?: true>

      iex> changeset(%{order_by: "asc:last_name,desc_nulls_last:first_name"}) |> validate_order_by(@orderables)
      #Ecto.Changeset<action: nil, changes: %{order_by: [asc: :last_name, desc_nulls_last: :first_name]}, errors: [], data: %{}, valid?: true>
  """
  @spec validate_order_by(Changeset.t(), Enum.t()) :: Changeset.t()
  def validate_order_by(changeset, orderable_fields) do
    with order_by when is_binary(order_by) <- get_change(changeset, :order_by) do
      order_by
      |> String.split(",", trim: true)
      |> Enum.reduce(put_change(changeset, :order_by, []), fn string, cs ->
        with [dir, field] <- Regex.run(@order_by_format, string, capture: :all_but_first),
             {true, field} <- {field in orderable_fields, field} do
          update_change(cs, :order_by, &[{String.to_atom(dir), String.to_atom(field)} | &1])
        else
          nil -> add_error(cs, :order_by, "format is asc|desc:field")
          {false, field} -> add_error(cs, :order_by, "unknown field " <> field)
        end
      end)
      |> update_change(:order_by, &Enum.reverse/1)
    else
      _ -> delete_change(changeset, :order_by)
    end
  end

  @doc """
  Move a change to another field in the changeset (if its value is not nil).
  Like `Ecto.Changeset.put_change/3`, the change is moved without additional validation.
  Optionally, the value can be mapped using `value_mapper`, which defaults to the identity function.

  ## Examples
  For the implementation of `changeset/1`, see `#{__MODULE__}`.

      # there is no effect when there is no change to the field
      iex> changeset() |> move_change(:first_name, :last_name)
      #Ecto.Changeset<action: nil, changes: %{}, errors: [], data: %{}, valid?: true>

      # a change is moved to another field name as-is by default
      iex> changeset(%{first_name: "Pan"}) |> move_change(:first_name, :last_name)
      #Ecto.Changeset<action: nil, changes: %{last_name: "Pan"}, errors: [], data: %{}, valid?: true>

      # an optional value_mapper can be passed to do some processing on the change along the way
      iex> changeset(%{first_name: "Pan"}) |> move_change(:first_name, :last_name, & String.upcase(&1))
      #Ecto.Changeset<action: nil, changes: %{last_name: "PAN"}, errors: [], data: %{}, valid?: true>
  """
  @spec move_change(Changeset.t(), atom(), atom(), (any -> any)) :: Changeset.t()
  def move_change(%{changes: changes} = changeset, field, new_field, value_mapper \\ & &1) do
    case Map.get(changes, field) do
      nil ->
        changeset

      value ->
        new_changes = changes |> Map.delete(field) |> Map.put(new_field, value_mapper.(value))
        Map.put(changeset, :changes, new_changes)
    end
  end

  @doc """
  Validate a searchable field. If the value of `field` is postfixed with '\\*',
  a fuzzy search instead of a equal_to match is considered to be intended. In this case, the value
  must be at least 4 characters long and must be (i)like safe (as per `validate_ilike_safe/2`),
  and is moved to `search_field`. The postfix '\\*' is stripped from the search string.

  The purpose is to pass the changes along to a `list`-query which supports searching by
  `search_field`, and equal_to filtering by `field`.
  See `PhoenixApiToolkit.Ecto.DynamicFilters` for more info on dynamic filtering.

  The minimum length for a search string can be overridden with option `:min_length`.

  ## Examples
  For the implementation of `changeset/1`, see `#{__MODULE__}`.

      # a last_name value postfixed with '*' is search query
      iex> changeset(%{last_name: "Smit*"}) |> validate_searchable(:last_name, :last_name_prefix)
      #Ecto.Changeset<action: nil, changes: %{last_name_prefix: "Smit"}, errors: [], data: %{}, valid?: true>

      # values without postfix '*' are passed through
      iex> changeset(%{last_name: "Smit"}) |> validate_searchable(:last_name, :last_name_prefix)
      #Ecto.Changeset<action: nil, changes: %{last_name: "Smit"}, errors: [], data: %{}, valid?: true>

      # to prevent too-broad, expensive ilike queries, search parameters must be >=4 characters long
      iex> changeset(%{last_name: "Smi*"}) |> validate_searchable(:last_name, :last_name_prefix)
      #Ecto.Changeset<action: nil, changes: %{last_name: "Smi"}, errors: [last_name: {"should be at least %{count} character(s)", [count: 4, validation: :length, kind: :min, type: :string]}], data: %{}, valid?: false>

      # the min_length value can be overridden
      iex> changeset(%{last_name: "Smi*"}) |> validate_searchable(:last_name, :last_name_prefix, min_length: 5)
      #Ecto.Changeset<action: nil, changes: %{last_name: "Smi"}, errors: [last_name: {"should be at least %{count} character(s)", [count: 5, validation: :length, kind: :min, type: :string]}], data: %{}, valid?: false>

      # additionally, search parameters must be ilike safe, as per validate_ilike_safe/2
      iex> changeset(%{last_name: "Sm_it*"}) |> validate_searchable(:last_name, :last_name_prefix)
      #Ecto.Changeset<action: nil, changes: %{last_name: "Sm_it"}, errors: [last_name: {"may not contain _ % or \\\\", [validation: :format]}], data: %{}, valid?: false>
  """
  @spec validate_searchable(Changeset.t(), atom(), atom(), keyword) :: Changeset.t()
  def validate_searchable(changeset, field, search_field, opts \\ []) do
    with value when not is_nil(value) <- get_change(changeset, field),
         true <- String.ends_with?(value, "*") do
      changeset
      |> put_change(field, String.trim_trailing(value, "*"))
      # to prevent useless, expensive lookups
      |> validate_length(field, min: opts[:min_length] || 4)
      |> validate_ilike_safe(field)
      |> map_if_valid(&move_change(&1, field, search_field))
    else
      _ -> changeset
    end
  end

  @doc """
  For verifying files uploaded as base64-encoded binaries. Attempts to decode `field` and
  validate its file signature. The file signature, also known as a file's "magic bytes",
  can be looked up on the internet (for example [here](https://en.wikipedia.org/wiki/List_of_file_signatures))
  and may be a list of allowed magic byte types.

  ## Examples
  For the implementation of `changeset/1`, see `#{__MODULE__}`.

      @pdf_signature "255044462D" |> Base.decode16!()
      @png_signature "89504E470D0A1A0A" |> Base.decode16!()
      @png_file "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
      @gif_file "R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="
      @txt_file "some text" |> Base.encode64()

      # if the signature checks out, the uploaded file is decoded and the changeset valid
      iex> cs = changeset(%{file: @png_file}) |> validate_upload(:file, @png_signature)
      iex> {cs.valid?, cs.changes.file}
      {true, @png_file |> Base.decode64!()}

      # multiple signatures can be provided
      iex> cs = changeset(%{file: @png_file}) |> validate_upload(:file, [@pdf_signature, @png_signature])
      iex> cs.valid?
      true

      # if the signature does not check out, an error is added to the changeset and the decoded file is discarded
      iex> cs = changeset(%{file: @gif_file}) |> validate_upload(:file, [@pdf_signature, @png_signature])
      iex> {cs.valid?, cs.errors, cs.changes.file}
      {false, [file: {"invalid file type", []}], @gif_file}

      # decoding errors are handled gracefully
      iex> cs = changeset(%{file: "a"}) |> validate_upload(:file, @pdf_signature)
      iex> {cs.valid?, cs.errors}
      {false, [file: {"invalid base64 encoding", []}]}

      # it is possible to provide a custom validator function (which should return `true` if valid)
      iex> cs = changeset(%{file: @txt_file}) |> validate_upload(:file, &String.starts_with?(&1, "some"))
      iex> cs.valid?
      true
  """
  @spec validate_upload(Changeset.t(), atom, binary | [binary]) :: Changeset.t()
  def validate_upload(changeset, field, file_signature)
      when not is_list(file_signature),
      do: validate_upload(changeset, field, [file_signature])

  def validate_upload(changeset, field, file_signatures) do
    with change when not is_nil(change) <- get_change(changeset, field),
         {:base64, {:ok, binary}} <- {:base64, Base.decode64(change)},
         {:valid, true} <-
           {:valid, Enum.find_value(file_signatures, &file_signature_matches?(binary, &1))} do
      put_change(changeset, field, binary)
    else
      nil -> changeset
      {:base64, :error} -> add_error(changeset, field, "invalid base64 encoding")
      {:valid, _} -> add_error(changeset, field, "invalid file type")
      _too_short_binary -> add_error(changeset, field, "invalid file")
    end
  end

  @doc """
  Like `validate_upload/3`, but sets the mime type to `mime_field`. Parameter
  `file_sig_mime_map` should be a map of file type signatures to mime types.

  ## Examples
  For the implementation of `changeset/1`, see `#{__MODULE__}`.

      def is_valid_text(binary), do: String.starts_with?(binary, "some")

      @signatures %{
        ("89504E470D0A1A0A" |> Base.decode16!()) => "image/png",
        &__MODULE__.is_valid_text/1 => "text/plain"
      }
      @png_file "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
      @gif_file "R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="
      @txt_file "some text" |> Base.encode64()

      iex> cs = changeset(%{file: @png_file}) |> validate_upload(:file, :mime_type, @signatures)
      iex> {cs.valid?, cs.changes.file, cs.changes.mime_type}
      {true, @png_file |> Base.decode64!(), "image/png"}

      iex> cs = changeset(%{file: @txt_file}) |> validate_upload(:file, :mime_type, @signatures)
      iex> {cs.valid?, cs.changes.file, cs.changes.mime_type}
      {true, @txt_file |> Base.decode64!(), "text/plain"}

      iex> cs = changeset(%{file: @gif_file}) |> validate_upload(:file, :mime_type, @signatures)
      iex> {cs.valid?, cs.errors, cs.changes.file, cs.changes[:mime_type]}
      {false, [file: {"invalid file type", []}], @gif_file, nil}
  """
  @spec validate_upload(Ecto.Changeset.t(), atom, atom, map) :: Ecto.Changeset.t()
  def validate_upload(changeset, field, mime_field, file_sig_mime_map) do
    with base64_data when not is_nil(base64_data) <- get_change(changeset, field),
         {:base64, {:ok, decoded}} <- {:base64, Base.decode64(base64_data)},
         %{valid?: true} = changeset <-
           validate_file_signature(changeset, field, mime_field, file_sig_mime_map, decoded) do
      put_change(changeset, field, decoded)
    else
      nil -> changeset
      {:base64, _} -> add_error(changeset, field, "invalid base64 encoding")
      %Ecto.Changeset{} = changeset -> changeset
    end
  end

  @doc """
  If `changeset` is valid, apply the first function `then_do` to it,
  else apply the second function `else_do` to it, which defaults to the
  identity function.

  ## Examples

      # function then_do is applied to the changeset if it is valid
      iex> %Ecto.Changeset{valid?: true} |> map_if_valid(& &1.changes)
      %{}

      # if the changeset is invalid and else_do is provided, apply it to the changeset
      iex> %Ecto.Changeset{valid?: false} |> map_if_valid(& &1.changes, & &1.errors)
      []

      # else_do defaults to identity, returning the changeset
      iex> %Ecto.Changeset{valid?: false} |> map_if_valid(& &1.changes)
      #Ecto.Changeset<action: nil, changes: %{}, errors: [], data: nil, valid?: false>

  """
  @spec map_if_valid(Changeset.t(), (Changeset.t() -> any), (Changeset.t() -> any)) ::
          Changeset.t()
  def map_if_valid(changeset, then_do, else_do \\ & &1)
  def map_if_valid(%{valid?: true} = cs, then_do, _else_do), do: then_do.(cs)
  def map_if_valid(cs, _then_do, else_do), do: else_do.(cs)

  @doc """
  Apply `function` to multiple fields of the changeset.
  Convenience wrapper for validators that don't support multiple fields.

  ## Examples / doctests
  For the implementation of `changeset/1`, see `#{__MODULE__}`.

      iex> changeset(%{first_name: "Luke", last_name: "Skywalker"})
      ...> |> multifield_apply([:first_name, :last_name], &validate_length(&1, &2, max: 3))
      ...> |> Map.take([:valid?, :errors])
      %{valid?: false, errors: [
        {:last_name, {"should be at most %{count} character(s)", [count: 3, validation: :length, kind: :max, type: :string]}},
        {:first_name, {"should be at most %{count} character(s)", [count: 3, validation: :length, kind: :max, type: :string]}}
      ]}
  """
  @spec multifield_apply(Changeset.t(), [atom], (Changeset.t(), atom -> Changeset.t())) ::
          Changeset.t()
  def multifield_apply(changeset, fields, function) do
    Enum.reduce(fields, changeset, &function.(&2, &1))
  end

  ###########
  # Private #
  ###########

  defp file_signature_matches?(binary, file_signature) when is_function(file_signature),
    do: file_signature.(binary)

  defp file_signature_matches?(binary, file_signature) do
    byte_count = byte_size(file_signature)

    with <<head::binary-size(byte_count), _rest::binary>> <- binary do
      head == file_signature
    else
      other -> other
    end
  end

  #
  # validate that the uploaded file starts with known magic bytes
  # field is used for errors  # sets :image_mime to mime type if recognized
  #
  defp validate_file_signature(changeset, field, mime_field, allowed_mimes, data) do
    Enum.find_value(
      allowed_mimes,
      add_error(changeset, field, "invalid file type"),
      fn {signature, mime_type} ->
        case file_signature_matches?(data, signature) do
          true -> put_change(changeset, mime_field, mime_type)
          _ -> false
        end
      end
    )
  end
end
