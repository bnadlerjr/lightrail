defmodule Test.Support.RabbitCase do
  @moduledoc """
  Test helpers for dealing with RabbitMQ.

  """

  defmacro __using__([]) do
    quote do
      use AMQP

      @doc """
      Opens a new RabbitMQ connection.

      """
      def rmq_open_connection(uri) do
        AMQP.Connection.open(uri)
      end

      @doc """
      Closes a RabbitMQ connection.

      """
      def rmq_close_connection(connection) do
        AMQP.Connection.close(connection)
      end

      @doc """
      Open a RabbitMQ channel.

      """
      def rmq_open_channel(connection) do
        AMQP.Channel.open(connection)
      end

      @doc """
      Close a RabbitMQ channel.

      """
      def rmq_close_channel(channel) do
        AMQP.Channel.close(channel)
      end

      @doc """
      Purges all message fromthe given queue.

      """
      def rmq_purge_queue(connection, queue) do
        {:ok, channel} = AMQP.Channel.open(connection)
        AMQP.Queue.purge(channel, queue)
        AMQP.Channel.close(channel)
      catch
        :exit, _ ->
          :ok
      end

      @doc """
      Publish a message. Expects message to be already encoded.

      """
      def rmq_publish_message(connection, exchange, message, routing_key \\ "") do
        {:ok, channel} = AMQP.Channel.open(connection)
        AMQP.Exchange.declare(channel, exchange, :fanout, durable: true)
        AMQP.Basic.publish(channel, exchange, routing_key, message)
        AMQP.Channel.close(channel)
      end

      @doc """
      Get the number of messages in the given queue.

      """
      def rmq_queue_count(connection, queue) do
        {:ok, channel} = AMQP.Channel.open(connection)
        {:ok, %{message_count: count}} = AMQP.Queue.declare(channel, queue, passive: true)
        AMQP.Channel.close(channel)
        count
      end
    end
  end
end
