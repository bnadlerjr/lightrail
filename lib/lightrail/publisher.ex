defmodule Lightrail.Publisher do
  @moduledoc """
  Public interface for a publisher.

  TODO:
  * docstrings for functions since this is a public API

  """

  @callback my_init() :: [
    connection: String.t(),
    exchange: String.t()
  ]

  def start_link(module, options \\ []) do
    GenServer.start_link(Lightrail.Publisher.Server, %{module: module}, options)
  end

  def publish(pid, message) do
    GenServer.call(pid, {:publish, message})
  end
end
