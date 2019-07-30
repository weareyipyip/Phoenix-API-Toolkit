defmodule PhoenixApiToolkit.CacheBodyReaderTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import PhoenixApiToolkit.CacheBodyReader
  import PhoenixApiToolkit.TestHelpers

  doctest PhoenixApiToolkit.CacheBodyReader
end
