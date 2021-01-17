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

  * cleanup function needs a better name (close?, teardown?); need
    to see how consumer functions will fit in as well

  * What should the publish function return? Should it wrap the results
    from Basic.publish? Thinking yes so that we don't leak AMQP stuff

  * Maybe the cleanup function should return the updated state with channel
    and connection removed (or maybe set to nil?)

  * make prefetch_count configurable

  * which queue options are configurable?

  * configure dead letter exchange for consumers

  * should requeue be configurable when rejecting a message? or is it
    better handled by a proper retry strategy? maybe a retry strategy is
    too high level for this module?

  * setup telemetry

  * make some helper functions to take care of duplication in
    setup_publisher & setup_consumer

  * setup for dead letter exchange/queue

  * check delivery mode of publish -- should be "peristent" or mode #2

  """

  require Logger
  use AMQP

  def setup_publisher(%{module: module, config: config} = state) do
    {:ok, connection} = connect(state)
    {:ok, channel} = Channel.open(connection)
    :ok = Exchange.declare(channel, config[:exchange], :fanout, durable: true)

    # Can I just merge channel and connection into state here instead?
    {:ok, %{channel: channel, module: module, config: config, connection: connection}}
  end

  def setup_consumer(%{config: config} = state) do
    {:ok, connection} = connect(state)
    {:ok, channel} = Channel.open(connection)
    :ok = Basic.qos(channel, prefetch_count: 5)

    # If I add `durable: true` to the call below I get
    # PRECONDITION_FAILED - inequivalent arg 'durable' for queue -- why?
    {:ok, _} = Queue.declare(channel, config[:queue])

    :ok = Exchange.declare(channel, config[:exchange], :fanout, durable: true)
    :ok = Queue.bind(channel, config[:queue], config[:exchange])
    {:ok, _consumer_tag} = Basic.consume(channel, config[:queue])

    # why doesn't this work? channel & connection aren't merged into state
    # {:ok, %{state | channel: channel, connection: connection}}

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

  def cleanup(%{channel: channel, connection: connection}) do
    Channel.close(channel)
    Connection.close(connection)
  end

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
