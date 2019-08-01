defmodule PhoenixApiToolkit.CacheBodyReader do
  @moduledoc """
  Store the raw body for verification purposes.
  Use as `Plug.Parsers` :body_reader option in endpoint pipeline.

  After: [https://hexdocs.pm/plug/Plug.Parsers.html#module-custom-body-reader](https://hexdocs.pm/plug/Plug.Parsers.html#module-custom-body-reader)
  """

  @doc """
  Read the request body and cache the raw version in the conn. The raw version
  can be accessed with `get_raw_request_body/1`.

  ## Examples

      use Plug.Test
      import PhoenixApiToolkit.CacheBodyReader
      import PhoenixApiToolkit.TestHelpers

      # the body is read and cached
      iex> {:ok, raw_body, conn} = conn(:get, "/hello") |> put_raw_body("some rawness") |> cache_and_read_body()
      iex> raw_body
      "some rawness"
      iex> conn.assigns[:raw_body]
      ["some rawness"]

      # Plug.Conn.read_body/2 is used in the background, opts and responses responses are passed through
      iex> result = conn(:get, "/hello") |> put_raw_body("some rawness") |> cache_and_read_body(length: 1)
      iex> result |> elem(0)
      :more

  """
  @spec cache_and_read_body(Plug.Conn.t(), Keyword.t()) ::
          {:ok, binary, Plug.Conn.t()} | {:more, binary, Plug.Conn.t()} | {:error, term}

  def cache_and_read_body(conn, opts \\ []) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
        {:ok, body, conn}

      other ->
        other
    end
  end

  @doc """
  Return the raw request body, after it is cached in the conn by `cache_and_read_body/2`.
  Note that the raw request body is not a string!

  ## Examples

      use Plug.Test
      import PhoenixApiToolkit.CacheBodyReader
      import PhoenixApiToolkit.TestHelpers

      iex> {:ok, _, conn} = conn(:get, "/hello") |> put_raw_body("the rawness") |> cache_and_read_body()
      iex> raw_body = conn |> get_raw_request_body()
      ["the rawness"]
      iex> is_binary(raw_body)
      false
      iex> to_string(raw_body)
      "the rawness"
  """
  @spec get_raw_request_body(Plug.Conn.t()) :: binary | nil
  def get_raw_request_body(conn) do
    conn.assigns[:raw_body]
  end
end
