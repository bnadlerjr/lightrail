defmodule Test.Support.RabbitCase do
  @moduledoc """
  Test helpers for dealing with RabbitMQ.

  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use AMQP

      import Test.Support.Helpers
      import Test.Support.RabbitCase

      alias Lightrail.MessageBus.RabbitMQ
    end
  end

  setup do
    # We need to stop and restart app w/ a real RabbitMQ
    :ok = Application.stop(:lightrail)
    Application.put_env(:lightrail, :message_bus, Lightrail.MessageBus.RabbitMQ)
    :ok = Application.start(:lightrail)

    {:ok, connection} = open_connection("amqp://guest:guest@localhost:5672")

    # Publishers don't know about queues, only exchanges. If we send a
    # message to an exchange that doesn't have a queue bound to it, the
    # message will be lost. In production, this isn't an issue since
    # consumers will take care of the binding. However, some tests publish a
    # message before a consumer is started. This sets up the queue so that no
    # messages are lost if a consumer hasn't started yet.
    :ok = create_and_bind_queue(connection, "lightrail:test:events", "lightrail:test")

    exit_fn = fn ->
      :ok = delete_queue(connection, "lightrail:test:events")
      :ok = delete_exchange(connection, "lightrail:test")
      :ok = close_connection(connection)

      # Put the fake RabbitMQ back for future tests
      :ok = Application.stop(:lightrail)
      Application.put_env(:lightrail, :message_bus, Test.Support.FakeRabbitMQ)
      :ok = Application.start(:lightrail)
    end

    on_exit(exit_fn)
    %{connection: connection}
  end

  @doc """
  Opens a new RabbitMQ connection.

  """
  def open_connection(uri) do
    AMQP.Connection.open(uri)
  end

  @doc """
  Closes a RabbitMQ connection.

  """
  def close_connection(connection) do
    AMQP.Connection.close(connection)
  end

  @doc """
  Open a RabbitMQ channel.

  """
  def open_channel(connection) do
    AMQP.Channel.open(connection)
  end

  @doc """
  Close a RabbitMQ channel.

  """
  def close_channel(channel) do
    AMQP.Channel.close(channel)
  end

  @doc """
  Delete the specified exchange and all bindings to it.

  """
  def delete_exchange(connection, exchange) do
    {:ok, channel} = AMQP.Channel.open(connection)
    :ok = AMQP.Exchange.delete(channel, exchange)
    AMQP.Channel.close(channel)
  end

  @doc """
  Creates an exchange, a queue, and binds them. The exchange may or may
  not already exist; if it does a new one won't be created. This will
  throw an error if the queue already exists, however (maybe? double
  check that part about the queue is true).

  """
  def create_and_bind_queue(connection, queue, exchange) do
    {:ok, channel} = AMQP.Channel.open(connection)
    :ok = AMQP.Exchange.fanout(channel, exchange, options())
    {:ok, _state} = AMQP.Queue.declare(channel, queue, options())
    :ok = AMQP.Queue.bind(channel, queue, exchange)
    AMQP.Channel.close(channel)
  end

  @doc """
  Delete the specified queue.

  """
  def delete_queue(connection, queue) do
    {:ok, channel} = AMQP.Channel.open(connection)
    {:ok, _count} = AMQP.Queue.delete(channel, queue)
    AMQP.Channel.close(channel)
  end

  @doc """
  Purges all message from the given queue.

  """
  def purge_queue(connection, queue) do
    {:ok, channel} = AMQP.Channel.open(connection)
    {:ok, _count} = AMQP.Queue.purge(channel, queue)
    AMQP.Channel.close(channel)
  catch
    :exit, _ ->
      :ok
  end

  @doc """
  Publish a message. Expects message to be already encoded.

  """
  def publish_message(connection, exchange, message, routing_key \\ "") do
    {:ok, channel} = AMQP.Channel.open(connection)
    :ok = AMQP.Exchange.fanout(channel, exchange, options())
    :ok = AMQP.Basic.publish(channel, exchange, routing_key, message)
    AMQP.Channel.close(channel)
  end

  @doc """
  Get the number of messages in the given queue.

  """
  def queue_count(queue) do
    %{messages: message_count} = get_queue_info(queue)
    message_count
  end

  @doc """
  Retrieve information about the given queue using the Rabbit API.

  """
  def get_queue_info(queue_name) do
    results = make_api_request(:queues)
    Enum.find(results, fn q -> queue_name == q.name end)
  end

  @doc """
  Retrieve information about the given exchange using the Rabbit API.

  """
  def get_exchange_info(exchange_name) do
    results = make_api_request(:exchanges)
    Enum.find(results, fn q -> exchange_name == q.name end)
  end

  @doc """
  Retrieve information about the binding between the given queue and
  exchange. Returns nil if no binding can be found.

  """
  def get_binding_info(exchange_name, queue_name) do
    finder = fn binding ->
      exchange_name == binding.source and queue_name == binding.destination
    end

    results = make_api_request(:bindings)
    Enum.find(results, finder)
  end

  defp make_api_request(resource) do
    url = "http://guest:guest@localhost:15672/api/#{resource}"
    {:ok, {_, _, resp}} = :httpc.request(String.to_charlist(url))
    Jason.decode!(resp, keys: :atoms)
  end

  defp options do
    [
      durable: true,
      arguments: [{"x-dead-letter-exchange", :longstr, "lightrail:errors"}]
    ]
  end
end
