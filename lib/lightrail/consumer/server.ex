defmodule Lightrail.Consumer.Server do
  @moduledoc """
  GenServer implmentation for Consumers.

  """

  require Logger
  use GenServer

  alias Lightrail.Message

  @message_bus Application.compile_env(:lightrail, :message_bus, Lightrail.MessageBus.RabbitMQ)

  @doc false
  @impl GenServer
  def init(%{module: module} = initial_state) do
    config = apply(module, :init, [])
    state = Map.merge(initial_state, %{config: config})
    {:ok, state, {:continue, :init}}
  end

  @doc false
  @impl GenServer
  def handle_continue(:init, state) do
    {:ok, state} = @message_bus.setup_consumer(state)
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
  def handle_info({:basic_cancel_ok, %{consumer_tag: consumer_tag}}, %{module: module} = state) do
    Logger.info("[#{module}]: Consumer was cancelled, tag: #{consumer_tag}")
    {:noreply, state}
  end

  @doc false
  @impl GenServer
  def handle_info({:basic_deliver, payload, attributes}, %{module: module} = state) do
    # Think about pulling this ack / reject /rescue logic up into the
    # Message module. Maybe something like:
    #
    # case Message.consume(payload, module) do
    #   :ack ->
    #     @message_bus.ack(state, attributes)
    #     {:noreply, state}
    #
    #   :reject ->
    #     @message_bus.reject(state, attributes)
    #     {:noreply, state}
    #
    #   :error ->
    #     @message_bus.reject(state, attributes)
    #     {:noreply, :error}
    # end

    case Message.consume(payload, module) do
      :error ->
        @message_bus.reject(state, attributes)

      _ ->
        @message_bus.ack(state, attributes)
    end

    {:noreply, state}
  rescue
    reason ->
      full_error = {reason, __STACKTRACE__}

      Logger.error("[#{module}]: Unhandled exception while consuming message.
        #{inspect(full_error)}")

      @message_bus.reject(state, attributes)
      {:noreply, :error}
  end

  @doc false
  @impl GenServer
  def terminate(:connection_closed = reason, %{module: module}) do
    Logger.info("[#{module}]: Terminating consumer, reason: #{inspect(reason)}")
  end

  @doc false
  @impl GenServer
  def terminate(reason, %{module: module} = state) do
    Logger.info("[#{module}]: Terminating consumer, reason: #{inspect(reason)}")
    @message_bus.cleanup(state)
  end

  @doc false
  @impl GenServer
  def terminate({{:shutdown, {:server_initiated_close, error_code, reason}}, _}, %{module: module}) do
    Logger.error("[#{module}]: Terminating consumer, 
        error_code: #{inspect(error_code)},
        reason: #{inspect(reason)}")
  end

  @doc false
  @impl GenServer
  def terminate(reason, %{module: module}) do
    Logger.error("[#{module}]: Terminating consumer, unexpected reason: #{inspect(reason)}")
  end
end
