defmodule Lightrail.Consumer.Server do
  @moduledoc """
  GenServer implmentation for Consumers.

  TODO:

  * is Process.flag(:trap_exit, true) needed in init function? what
    does it do?
  * consider default timeouts for server & messages
  * setup telemetry
  * research how Elixir Tasks might work w/ processing messages
  * are all needed GenServer handlers present?

  """

  require Logger
  use GenServer

  @message_bus Application.compile_env(:lightrail, :message_bus, Lightrail.MessageBus.RabbitMQ)

  def init(%{module: module} = initial_state) do
    config = apply(module, :init, [])
    state = Map.merge(initial_state, %{config: config})
    {:ok, state, {:continue, :init}}
  end

  def handle_continue(:init, state) do
    {:ok, state} = @message_bus.setup_consumer(state)
    {:noreply, state}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, %{module: module} = state) do
    Logger.info("[#{module}]: Broker confirmed consumer with tag #{consumer_tag}")
    {:noreply, state}
  end

  def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, %{module: module} = state) do
    Logger.warn("[#{module}]: The consumer was unexpectedly cancelled, tag: #{consumer_tag}")
    {:stop, :cancelled, state}
  end

  def handle_info({:basic_cancel_ok, %{consumer_tag: consumer_tag}}, %{module: module} = state) do
    Logger.info("[#{module}]: Consumer was cancelled, tag: #{consumer_tag}")
    {:noreply, state}
  end

  def handle_info({:basic_deliver, payload, attributes}, %{module: module} = state) do
    apply(module, :handle_message, [payload])
    @message_bus.ack(state, attributes)
    {:noreply, state}
  rescue
    reason ->
      full_error = {reason, __STACKTRACE__}
      apply(module, :handle_error, [payload, full_error])
      @message_bus.reject(state, attributes)
      {:noreply, :error}
  end

  def terminate(:connection_closed = reason, %{module: module}) do
    Logger.info("[#{module}]: Terminating consumer, reason: #{inspect(reason)}")
  end

  def terminate(reason, %{module: module} = state) do
    Logger.info("[#{module}]: Terminating consumer, reason: #{inspect(reason)}")
    @message_bus.cleanup(state)
  end

  def terminate({{:shutdown, {:server_initiated_close, error_code, reason}}, _}, %{module: module}) do
    Logger.error("[#{module}]: Terminating consumer, error_code: #{inspect(error_code)}, reason: #{inspect(reason)}")
  end

  def terminate(reason, %{module: module}) do
    Logger.error("[#{module}]: Terminating consumer, unexpected reason: #{inspect(reason)}")
  end
end
