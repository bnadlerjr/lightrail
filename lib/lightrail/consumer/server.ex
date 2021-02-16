defmodule Lightrail.Consumer.Server do
  @moduledoc """
  GenServer implmentation for Consumers.

  """

  use GenServer

  alias Lightrail.Consumer.Telemetry
  alias Lightrail.MessageBus

  @doc false
  @impl GenServer
  def init(%{module: module} = initial_state) do
    # Trap exits so that terminate is called (in most situations). See
    # https://blog.differentpla.net/blog/2014/11/13/erlang-terminate/
    Process.flag(:trap_exit, true)

    config = apply(module, :init, [])

    new_state = %{
      adapter: Application.fetch_env!(:lightrail, :message_bus),
      bus: %MessageBus{exchange: config[:exchange], queue: config[:queue]}
    }

    state = Map.merge(initial_state, new_state)
    {:ok, state, {:continue, :init}}
  end

  @doc false
  @impl GenServer
  def handle_continue(:init, %{adapter: adapter, bus: bus} = state) do
    {:ok, bus_state} = adapter.setup_consumer(bus)
    {:noreply, Map.put(state, :bus, bus_state)}
  end

  @doc false
  @impl GenServer
  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, state) do
    %{module: module, bus: %{exchange: exchange}} = state
    Telemetry.emit_consumer_confirmed(module, consumer_tag, exchange)
    {:noreply, state}
  end

  @doc false
  @impl GenServer
  def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, %{module: module} = state) do
    Telemetry.emit_consumer_cancelled(module, consumer_tag)
    {:stop, :cancelled, state}
  end

  @doc false
  @impl GenServer
  def handle_info({:basic_deliver, payload, attributes}, state) do
    %{module: module, bus: bus, adapter: adapter} = state
    info = %{module: module, exchange: bus.exchange, queue: bus.queue}

    case Lightrail.Consumer.process(payload, attributes, info) do
      {:error, error} ->
        adapter.reject(bus, attributes)
        {:noreply, :error, error}

      _ ->
        adapter.ack(bus, attributes)
        {:noreply, state}
    end
  end

  @doc false
  @impl GenServer
  def terminate(reason, %{adapter: adapter, bus: bus} = state) do
    Telemetry.emit_consumer_down(state.module, reason)
    adapter.cleanup(bus)
    :normal
  end
end
