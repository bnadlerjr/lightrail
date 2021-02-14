defmodule Lightrail.MessageBus.RabbitMQ.Server do
  @moduledoc """
  GenServer implementation for RabbitMQ connection.

  """

  use GenServer
  require Logger

  defstruct [:uri, :adapter, :connection]

  @doc false
  @impl GenServer
  def init(%__MODULE__{} = config) do
    Process.flag(:trap_exit, true)
    {:ok, config, {:continue, :open_connection}}
  end

  @doc false
  @impl GenServer
  def handle_continue(:open_connection, state) do
    %__MODULE__{uri: uri, adapter: adapter} = state
    {:ok, connection} = adapter.connect(uri)
    new_state = Map.put(state, :connection, connection)
    {:noreply, new_state}
  end

  @doc false
  @impl GenServer
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    %__MODULE__{uri: uri, adapter: adapter} = state
    Logger.info("RabbitMQ connection is down! Reason: #{inspect(reason)}")
    new_state = Map.put(state, :connection, adapter.connect(uri))
    {:noreply, new_state}
  end

  @doc false
  @impl GenServer
  def handle_call({:get_connection}, _from, state) do
    %__MODULE__{connection: connection} = state
    {:reply, connection, state}
  end

  @doc false
  @impl GenServer
  def terminate(reason, %__MODULE__{adapter: adapter, connection: connection}) do
    Logger.info("Terminating RabbitMQ connection, reason: #{inspect(reason)}")
    if connection && Process.alive?(connection.pid), do: adapter.disconnect(connection)
    :normal
  end
end
