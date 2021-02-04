defmodule Lightrail.Consumer.Server do
  @moduledoc """
  GenServer implmentation for Consumers.

  """

  require Logger
  use GenServer

  alias Lightrail.MessageBus.Adapter

  @doc false
  @impl GenServer
  def init(%{module: module} = initial_state) do
    # Trap exits so that terminate is called (in most situations). See
    # https://blog.differentpla.net/blog/2014/11/13/erlang-terminate/
    Process.flag(:trap_exit, true)

    new_state = %{
      config: apply(module, :init, []),
      bus: Application.get_env(:lightrail, :message_bus, Adapter)
    }

    state = Map.merge(initial_state, new_state)
    {:ok, state, {:continue, :init}}
  end

  @doc false
  @impl GenServer
  def handle_continue(:init, %{bus: bus} = state) do
    {:ok, state} = bus.setup_consumer(state)
    {:noreply, state}
  end

  @doc false
  @impl GenServer
  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, %{module: module} = state) do
    Logger.info("[#{module}]: Broker confirmed consumer with tag #{consumer_tag}")
    {:noreply, state}
  end

  @doc false
  @impl GenServer
  def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, %{module: module} = state) do
    Logger.warn("[#{module}]: The consumer was unexpectedly cancelled, tag: #{consumer_tag}")
    {:stop, :cancelled, state}
  end

  @doc false
  @impl GenServer
  def handle_info({:basic_deliver, payload, attributes}, state) do
    %{module: module, config: config, bus: bus} = state
    info = %{module: module, exchange: config[:exchange], queue: config[:queue]}

    case Lightrail.Consumer.process(payload, attributes, info) do
      :error ->
        bus.reject(state, attributes)
        {:noreply, :error}

      _ ->
        bus.ack(state, attributes)
        {:noreply, state}
    end
  end

  @doc false
  @impl GenServer
  def terminate(reason, %{bus: bus} = state) do
    Logger.info("[#{state.module}]: Terminating consumer, reason: #{inspect(reason)}")
    bus.cleanup(state)
    :normal
  end
end
