defmodule PhoenixApiToolkit.Utils do
  @moduledoc """
  Generic utility functions.
  """

  @doc """
  Get a mandatory value from a keyword list.
  Raises an ArgumentError if the key is missing from the list
  (or its value is `nil`).

  ## Examples

      # if the key-value pair is present, its value is returned
      iex> [secret: "supersecret"] |> get_keyword!(:secret)
      "supersecret"

      # if the key-value pair is not present, an error is raised
      iex> [] |> get_keyword!(:secret)
      ** (ArgumentError) key "secret" not found

      # if the value is nil, an error is raised
      iex> [secret: nil] |> get_keyword!(:secret)
      ** (ArgumentError) key "secret" not found
  """
  @spec get_keyword!(Keyword.t(), atom) :: any
  def get_keyword!(keyword_list, key) do
    keyword_list
    |> Keyword.get(key)
    |> case do
      nil -> raise ArgumentError, "key \"#{key}\" not found"
      value -> value
    end
  end
end
