defmodule Lightrail.Publisher.Server do
  @moduledoc """
  GenServer implementation for publishers.

  """

  require Logger
  use GenServer

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
  def handle_continue(:init, %{module: module, config: config}) do
    {:ok, state} = @message_bus.setup_publisher(%{module: module, config: config})
    {:noreply, state}
  end

  @doc false
  @impl GenServer
  def handle_call({:publish, message}, _from, %{channel: channel, config: config} = state) do
    result = @message_bus.publish(channel, config[:exchange], message)
    {:reply, result, state}
  end

  @doc false
  @impl GenServer
  def handle_info({:DOWN, _ref, :process, _pid, reason}, %{module: module, config: config}) do
    Logger.info("[#{module}]: RabbitMQ connection is down! Reason: #{inspect(reason)}")
    {:ok, state} = @message_bus.setup_publisher(%{module: module, config: config})
    {:noreply, state}
  end

  @doc false
  @impl GenServer
  def terminate(reason, %{module: module} = state) do
    Logger.debug("[#{module}]: Terminating publisher, reason: #{inspect(reason)}")
    @message_bus.cleanup(state)
  end

  @doc false
  @impl GenServer
  def terminate({{:shutdown, {:server_initiated_close, error_code, reason}}, _}, %{module: module}) do
    Logger.error(
      "[#{module}]: Terminating publisher, error_code: #{inspect(error_code)}, reason: #{
        inspect(reason)
      }"
    )
  end

  @doc false
  @impl GenServer
  def terminate(reason, %{module: module}) do
    Logger.error("[#{module}]: Terminating publisher, unexpected reason: #{inspect(reason)}")
  end
end
