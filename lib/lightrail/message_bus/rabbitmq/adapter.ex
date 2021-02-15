defmodule Lightrail.MessageBus.RabbitMQ.Adapter do
  @moduledoc """
  RabbitMQ implementation of the message bus.

  This is an internal module, not part of the public API.

  """

  @behaviour Lightrail.MessageBus

  use AMQP

  alias Lightrail.MessageBus
  alias Lightrail.MessageBus.RabbitMQ.Connection, as: BusConnection
  alias Lightrail.MessageBus.RabbitMQ.Telemetry

  def setup_publisher(%MessageBus{exchange: exchange} = state) do
    {:ok, connection} = BusConnection.get(:publisher_connection)
    {:ok, channel} = Channel.open(connection)
    :ok = Exchange.fanout(channel, exchange, options())
    {:ok, Map.merge(state, %{channel: channel})}
  end

  def setup_consumer(%MessageBus{exchange: exchange, queue: queue} = state) do
    {:ok, connection} = BusConnection.get(:consumer_connection)
    {:ok, channel} = Channel.open(connection)

    :ok = Exchange.fanout(channel, exchange, options())
    {:ok, _} = Queue.declare(channel, queue, options())
    :ok = Queue.bind(channel, queue, exchange)
    {:ok, _} = Basic.consume(channel, queue)

    {:ok, Map.merge(state, %{channel: channel})}
  end

  def connect(uri) do
    case Connection.open(uri) do
      {:ok, connection} ->
        Telemetry.emit_connection_open(__MODULE__)
        {:ok, connection}

      {:error, {kind, reason}} ->
        Telemetry.emit_connection_fail(__MODULE__, kind, reason)
        :timer.sleep(5000)
        connect(uri)
    end
  end

  def disconnect(connection) when not is_nil(connection) do
    Connection.close(connection)
  end

  def disconnect(_), do: :ok

  def ack(%{channel: channel}, %{delivery_tag: tag}) do
    :ok = Basic.ack(channel, tag)
  end

  def reject(%{channel: channel}, %{delivery_tag: tag}) do
    :ok = Basic.reject(channel, tag, requeue: false)
  end

  def publish(%{channel: channel, exchange: exchange}, message) do
    start_time = Telemetry.emit_publish_start(__MODULE__, exchange, message)
    routing_key = ""

    case Basic.publish(channel, exchange, routing_key, message, persistent: true) do
      :ok ->
        Telemetry.emit_publish_stop(__MODULE__, start_time, exchange, message)

      {kind, reason} ->
        Telemetry.emit_publish_error(
          __MODULE__,
          start_time,
          exchange,
          message,
          kind,
          reason
        )
    end
  end

  def cleanup(%{channel: channel} = state) when not is_nil(channel) do
    if Process.alive?(channel.pid), do: :ok = Channel.close(channel)
    {:ok, Map.drop(state, [:connection, :channel])}
  end

  def cleanup(state), do: {:ok, state}

  defp options do
    [
      durable: true,
      arguments: [{"x-dead-letter-exchange", :longstr, "lightrail:errors"}]
    ]
  end
end
