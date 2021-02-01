defmodule Lightrail.MessageBus.RabbitMQ do
  @moduledoc """
  RabbitMQ implementation of the message bus.

  This is an internal module, not part of the public API.

  """

  @behaviour Lightrail.MessageBus

  require Logger
  use AMQP

  def setup_publisher(%{config: config} = state) do
    {:ok, connection} = connect(state)
    {:ok, channel} = Channel.open(connection)

    :ok = Exchange.fanout(channel, config[:exchange], options())

    {:ok, Map.merge(state, %{channel: channel, connection: connection})}
  end

  def setup_consumer(%{config: config} = state) do
    {:ok, connection} = connect(state)
    {:ok, channel} = Channel.open(connection)

    :ok = Exchange.fanout(channel, config[:exchange], options())
    {:ok, _} = Queue.declare(channel, config[:queue], options())
    :ok = Queue.bind(channel, config[:queue], config[:exchange])
    {:ok, _} = Basic.consume(channel, config[:queue])

    {:ok, Map.merge(state, %{channel: channel, connection: connection})}
  end

  def ack(%{channel: channel}, %{delivery_tag: tag}) do
    :ok = Basic.ack(channel, tag)
  end

  def reject(%{channel: channel}, %{delivery_tag: tag}) do
    :ok = Basic.reject(channel, tag, requeue: false)
  end

  def publish(%{channel: channel, config: config}, message) do
    Logger.info("Publishing message to #{config[:exchange]}")
    routing_key = ""
    Basic.publish(channel, config[:exchange], routing_key, message, persistent: true)
  end

  def cleanup(%{channel: channel, connection: connection} = state) do
    if Process.alive?(channel.pid), do: :ok = Channel.close(channel)
    if Process.alive?(channel.pid), do: :ok = Connection.close(connection)
    {:ok, Map.drop(state, [:connection, :channel])}
  end

  def cleanup(state), do: {:ok, state}

  defp connect(%{module: module, config: config} = state) do
    case Connection.open(config[:connection]) do
      {:ok, connection} ->
        Logger.info("[#{module}]: Connected to RabbitMQ")
        {:ok, connection}

      {:error, e} ->
        Logger.error("[#{module}]: Failed to connect to RabbitMQ (#{inspect(e)})")
        :timer.sleep(5000)
        connect(state)
    end
  end

  defp options do
    [
      durable: true,
      arguments: [{"x-dead-letter-exchange", :longstr, "lightrail:errors"}]
    ]
  end
end
