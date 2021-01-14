defmodule LightrailTest do
  use ExUnit.Case
  doctest Lightrail

  test "greets the world" do
    assert Lightrail.hello() == :world
  end
end
