defmodule Test.Support.FakeRabbitMQ do
  @moduledoc """
  Fake implementation of the `Lightrail.MessageBus` behaviour.

  """

  @behaviour Lightrail.MessageBus

  require Logger

  @impl Lightrail.MessageBus
  def setup_publisher(state) do
    Logger.info("[#{__MODULE__}] Setting up publisher")
    {:ok, state}
  end

  @impl Lightrail.MessageBus
  def setup_consumer(state) do
    Logger.info("[#{__MODULE__}] Setting up consumer")
    {:ok, state}
  end

  @impl Lightrail.MessageBus
  def ack(_state, _delivery_info) do
    Logger.info("[#{__MODULE__}] Acknowledging message")
    :ok
  end

  @impl Lightrail.MessageBus
  def reject(_state, _delivery_info) do
    Logger.info("[#{__MODULE__}] Rejecting message")
    :ok
  end

  @impl Lightrail.MessageBus
  def publish(_state, _message) do
    Logger.info("[#{__MODULE__}] Publishing message")
    :ok
  end

  @impl Lightrail.MessageBus
  def cleanup(state), do: {:ok, state}
end
