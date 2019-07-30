defmodule PhoenixApiToolkit.TestHelpersTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import PhoenixApiToolkit.TestHelpers

  doctest PhoenixApiToolkit.TestHelpers
end
