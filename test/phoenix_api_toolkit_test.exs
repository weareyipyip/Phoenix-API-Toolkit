defmodule PhoenixApiToolkitTest do
  use ExUnit.Case
  doctest PhoenixApiToolkit

  test "greets the world" do
    assert PhoenixApiToolkit.hello() == :world
  end
end
