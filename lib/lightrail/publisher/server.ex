defmodule Lightrail.Publisher.Server do
  @moduledoc """
  GenServer implementation for publishers.

  """

  require Logger
  use GenServer

  alias Lightrail.MessageBus

  @doc false
  @impl GenServer
  def init(%{module: module} = initial_state) do
    # Trap exits so that terminate is called (in most situations). See
    # https://blog.differentpla.net/blog/2014/11/13/erlang-terminate/
    Process.flag(:trap_exit, true)

    config = apply(module, :init, [])

    new_state = %{
      adapter: Application.get_env(:lightrail, :message_bus),
      bus: %MessageBus{exchange: config[:exchange]}
    }

    state = Map.merge(initial_state, new_state)
    {:ok, state, {:continue, :init}}
  end

  @doc false
  @impl GenServer
  def handle_continue(:init, %{adapter: adapter, bus: bus} = state) do
    {:ok, bus_state} = adapter.setup_publisher(bus)
    {:noreply, Map.put(state, :bus, bus_state)}
  end

  @doc false
  @impl GenServer
  def handle_call({:publish, message}, _from, %{adapter: adapter, bus: bus} = state) do
    case adapter.publish(bus, message) do
      :ok -> {:reply, {:ok, bus.exchange}, state}
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  @doc false
  @impl GenServer
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    %{module: module, adapter: adapter, bus: bus} = state
    Logger.info("[#{module}]: Publisher is down! Reason: #{inspect(reason)}")
    {:ok, bus_state} = adapter.setup_publisher(bus)
    {:noreply, Map.put(state, :bus, bus_state)}
  end

  @doc false
  @impl GenServer
  def terminate(reason, %{module: module, adapter: adapter, bus: bus}) do
    Logger.info("[#{module}]: Terminating publisher, reason: #{inspect(reason)}")
    adapter.cleanup(bus)
    :normal
  end
end
