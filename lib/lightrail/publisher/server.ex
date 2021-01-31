defmodule Lightrail.Publisher.Server do
  @moduledoc """
  GenServer implementation for publishers.

  """

  require Logger
  use GenServer

  alias Lightrail.MessageBus.RabbitMQ

  @doc false
  @impl GenServer
  def init(%{module: module} = initial_state) do
    # Trap exits so that terminate is called (in most situations). See
    # https://blog.differentpla.net/blog/2014/11/13/erlang-terminate/
    Process.flag(:trap_exit, true)

    new_state = %{
      config: apply(module, :init, []),
      bus: Application.get_env(:lightrail, :message_bus, RabbitMQ)
    }

    state = Map.merge(initial_state, new_state)
    {:ok, state, {:continue, :init}}
  end

  @doc false
  @impl GenServer
  def handle_continue(:init, %{bus: bus} = state) do
    {:ok, state} = bus.setup_publisher(state)
    {:noreply, state}
  end

  @doc false
  @impl GenServer
  def handle_call({:publish, message}, _from, %{bus: bus, config: config} = state) do
    case bus.publish(state, message) do
      :ok -> {:reply, {:ok, config[:exchange]}, state}
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  @doc false
  @impl GenServer
  def handle_info({:DOWN, _ref, :process, _pid, reason}, %{module: module, bus: bus} = state) do
    Logger.info("[#{module}]: RabbitMQ connection is down! Reason: #{inspect(reason)}")
    {:ok, state} = bus.setup_publisher(state)
    {:noreply, state}
  end

  @doc false
  @impl GenServer
  def terminate(reason, %{module: module, bus: bus} = state) do
    Logger.info("[#{module}]: Terminating publisher, reason: #{inspect(reason)}")
    bus.cleanup(state)
    :normal
  end
end
