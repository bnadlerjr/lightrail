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
      Delete the specified exchange and all bindings to it.

      """
      def rmq_delete_exchange(connection, exchange) do
        {:ok, channel} = AMQP.Channel.open(connection)
        AMQP.Exchange.delete(channel, exchange)
        AMQP.Channel.close(channel)
      end

      @doc """
      Creates an exchange, a queue, and binds them. The exchange may or may
      not already exist; if it does a new one won't be created. This will
      throw an error if the queue already exists, however (maybe? double
      check that part about the queue is true).

      """
      def rmq_create_and_bind_queue(connection, queue, exchange) do
        {:ok, channel} = AMQP.Channel.open(connection)
        AMQP.Exchange.declare(channel, exchange, :fanout, durable: true)
        AMQP.Queue.declare(channel, queue)
        AMQP.Queue.bind(channel, queue, exchange)
        AMQP.Channel.close(channel)
      end

      @doc """
      Delete the specified queue.

      """
      def rmq_delete_queue(connection, queue) do
        {:ok, channel} = AMQP.Channel.open(connection)
        AMQP.Queue.delete(channel, queue)
        AMQP.Channel.close(channel)
      end

      @doc """
      Purges all message from the given queue.

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
      def rmq_queue_count(queue) do
        %{messages: message_count} = get_queue_info(queue)
        message_count
      end

      defp get_queue_info(queue_name) do
        url = "http://guest:guest@localhost:15672/api/queues"
        {:ok, {a, b, resp}} = :httpc.request(String.to_charlist(url))
        {:ok, results} = Jason.decode(resp, keys: :atoms)
        Enum.find(results, fn q -> queue_name == q.name end)
      end
    end
  end
end
