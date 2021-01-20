defmodule Lightrail.MessageBus.RabbitMQ do
  @moduledoc """
  RabbitMQ implementation of the message bus.

  TODO:
  * if connection is provided in config args, use it; otherwise look for
    connection info in app config and finally fallback to looking for an
    environment variable

  * can/should connection be re-used/shared? it's own
    module (agent, genserver)?

  * publish function should probably take state map to be consistent with
    other functions signatures in this module; something like:
    `def publish(%{exchange: exchange, channel: channel}, message, routing_key \\ "") do`

  * What should the publish function return? Should it wrap the results
    from Basic.publish? Thinking yes so that we don't leak AMQP stuff

  * which queue options are configurable?

  * setup telemetry

  * setup for dead letter exchange/queue

  * check delivery mode of publish -- should be "peristent" or mode #2

  """

  require Logger
  use AMQP

  def setup_publisher(%{config: config} = state) do
    {:ok, connection} = connect(state)
    {:ok, channel} = Channel.open(connection)

    :ok = Exchange.declare(channel, config[:exchange], :fanout, durable: true)

    {:ok, Map.merge(state, %{channel: channel, connection: connection})}
  end

  def setup_consumer(%{config: config} = state) do
    {:ok, connection} = connect(state)
    {:ok, channel} = Channel.open(connection)

    :ok = Exchange.declare(channel, config[:exchange], :fanout, durable: true)
    {:ok, _} = Queue.declare(channel, config[:queue], durable: true)
    :ok = Queue.bind(channel, config[:queue], config[:exchange])
    {:ok, _consumer_tag} = Basic.consume(channel, config[:queue])

    {:ok, Map.merge(state, %{channel: channel, connection: connection})}
  end

  def ack(%{channel: channel}, %{delivery_tag: tag}) do
    Basic.ack(channel, tag)
  end

  def reject(%{channel: channel}, %{delivery_tag: tag}) do
    Basic.reject(channel, tag, requeue: false)
  end

  def publish(channel, exchange, message, routing_key \\ "") do
    Logger.info("Publishing message to #{exchange}")
    Basic.publish(channel, exchange, routing_key, message)
  end

  def cleanup(%{channel: channel, connection: connection} = state) do
    Channel.close(channel)
    Connection.close(connection)
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
end
