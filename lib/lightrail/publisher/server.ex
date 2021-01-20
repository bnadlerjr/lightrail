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
    # Trap exits so that terminate is called (in most situations). See
    # https://blog.differentpla.net/blog/2014/11/13/erlang-terminate/
    Process.flag(:trap_exit, true)

    config = apply(module, :init, [])
    state = Map.merge(initial_state, %{config: config})
    {:ok, state, {:continue, :init}}
  end

  @doc false
  @impl GenServer
  def handle_continue(:init, state) do
    {:ok, state} = @message_bus.setup_publisher(state)
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
  def handle_info({:DOWN, _ref, :process, _pid, reason}, %{module: module} = state) do
    Logger.info("[#{module}]: RabbitMQ connection is down! Reason: #{inspect(reason)}")
    {:ok, state} = @message_bus.setup_publisher(state)
    {:noreply, state}
  end

  @doc false
  @impl GenServer
  def terminate(reason, %{module: module} = state) do
    Logger.info("[#{module}]: Terminating publisher, reason: #{inspect(reason)}")
    @message_bus.cleanup(state)
    :normal
  end
end
