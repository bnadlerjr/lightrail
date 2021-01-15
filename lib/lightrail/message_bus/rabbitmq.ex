defmodule Lightrail.MessageBus.RabbitMQ do
  @moduledoc """
  RabbitMQ implementation of the message bus.

  TODO:
  * if connection is proved in config args, use it; otherwise look for
    connection info in app config and finally fallback to looking for an
    environment variable

  * publish function should probably take state map to be consistent with
    other functions signatures in this module
    ie. `def publish(%{exchange: exchange, channel: channel}, message, routing_key \\ "") do`

  * cleanup function needs a better name (close?, teardown_publisher?); need
    to see how consumer functions will fit in as well

  * What should the publish function return? Should it wrap the results
    from Basic.publish? Thinking yes so that we don't leak AMQP stuff

  * Maybe the cleanup function should return the updated state with channel
    and connection removed (or maybe set to nil?)
  """

  require Logger
  use AMQP

  def setup_publisher(%{module: module, config: config} = state) do
    {:ok, connection} = connect(state)
    {:ok, channel} = Channel.open(connection)
    Exchange.declare(channel, config[:exchange], :fanout, durable: true)

    # Can I just merge channel and connection into state here instead?
    {:ok, %{channel: channel, module: module, config: config, connection: connection}}
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
