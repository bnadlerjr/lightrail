defmodule Lightrail.ConsumerTest do
  # Note that we need to use async: false since tests interact
  # with external Rabbit exhcanges, queues, etc.
  use ExUnit.Case, async: false
  use Test.Support.RabbitCase

  alias Lightrail.Consumer
  alias Lightrail.Message
  alias Test.Support.Helpers
  alias Test.Support.Message, as: Proto

  @timeout _up_to_thirty_seconds = 30_000

  defmodule Subject do
    @behaviour Lightrail.Consumer

    def start_link() do
      Lightrail.Consumer.start_link(__MODULE__, name: __MODULE__)
    end

    @impl Lightrail.Consumer
    def init() do
      [
        exchange: "lightrail:test",
        queue: "lightrail:test:events",
        connection: "amqp://guest:guest@localhost:5672"
      ]
    end

    @impl Lightrail.Consumer
    def handle_message(message) do
      case message.info do
        "this should be acked" -> :ok
        "this should be rejected" -> :error
        _ -> raise "boom"
      end
    end
  end

  setup_all do
    {:ok, connection} = rmq_open_connection("amqp://guest:guest@localhost:5672")

    # Publishers don't know about queues, only exchanges. If we send a
    # message to an exchange that doesn't have a queue bound to it, the
    # message will be lost. In production, this isn't an issue since
    # consumers are started first and they create the exchange / queue
    # binding. These tests, however, publish messages _before_ the consumer
    # is started. We need to setup the exchange / queue binding ourselves
    # so that the published messages aren't lost.
    rmq_create_and_bind_queue(connection, "lightrail:test:events", "lightrail:test")

    exit_fn = fn ->
      rmq_delete_queue(connection, "lightrail:test:events")
      rmq_delete_exchange(connection, "lightrail:test")
      rmq_close_connection(connection)
    end

    on_exit(exit_fn)
    %{rmq_connection: connection}
  end

  setup context do
    exit_fn = fn ->
      rmq_purge_queue(context.rmq_connection, "lightrail:test:events")
    end
    on_exit(exit_fn)
  end

  test "starting a new consumer" do
    {:ok, pid} = start_supervised(%{id: Subject, start: {Subject, :start_link, []}})
    assert Process.alive?(pid)
  end

  @tag :rabbit
  test "acknowledging a message", %{rmq_connection: connection} do
    # Make sure the queue is empty
    Helpers.wait_for_passing(@timeout, fn ->
      assert 0 == rmq_queue_count("lightrail:test:events")
    end)

    # Publish a message
    msg = Proto.new(info: "this should be acked")
    {:ok, encoded} = Message.prepare_for_publishing(msg)
    rmq_publish_message(connection, "lightrail:test", encoded)

    # Make sure it arrived in the queue
    Helpers.wait_for_passing(@timeout, fn ->
      assert 1 == rmq_queue_count("lightrail:test:events")
    end)

    # Start the consumer
    start_supervised!(%{id: Subject, start: {Subject, :start_link, []}})

    # Assert the consumer processed the message
    Helpers.wait_for_passing(@timeout, fn ->
      assert 0 == rmq_queue_count("lightrail:test:events")
    end)
  end

  @tag :rabbit
  test "rejecting a message", %{rmq_connection: connection} do
    # Make sure the queue is empty
    Helpers.wait_for_passing(@timeout, fn ->
      assert 0 == rmq_queue_count("lightrail:test:events")
    end)

    # Publish a message
    msg = Proto.new(info: "this should be rejected")
    {:ok, encoded} = Message.prepare_for_publishing(msg)
    rmq_publish_message(connection, "lightrail:test", encoded)

    # Make sure it arrived in the queue
    Helpers.wait_for_passing(@timeout, fn ->
      assert 1 == rmq_queue_count("lightrail:test:events")
    end)

    # Start the consumer
    start_supervised!(%{id: Subject, start: {Subject, :start_link, []}})

    # Assert the consumer rejected the message
    Helpers.wait_for_passing(@timeout, fn ->
      assert 1 == rmq_queue_count("lightrail:test:events")
    end)
  end

  @tag :rabbit
  test "error handling", %{rmq_connection: connection} do
    # Make sure the queue is empty
    Helpers.wait_for_passing(@timeout, fn ->
      assert 0 == rmq_queue_count("lightrail:test:events")
    end)

    # Publish a message
    msg = Proto.new(info: "this should blow up")
    {:ok, encoded} = Message.prepare_for_publishing(msg)
    rmq_publish_message(connection, "lightrail:test", encoded)

    # Make sure it arrived in the queue
    Helpers.wait_for_passing(@timeout, fn ->
      assert 1 == rmq_queue_count("lightrail:test:events")
    end)

    # Start the consumer
    start_supervised!(%{id: Subject, start: {Subject, :start_link, []}})

    # Assert the consumer rejected the message
    Helpers.wait_for_passing(@timeout, fn ->
      assert 1 == rmq_queue_count("lightrail:test:events")
    end)
  end

  test "stopping a consumer" do
    pid = start_supervised!(%{id: Subject, start: {Subject, :start_link, []}})
    Consumer.stop(pid)
    assert not Process.alive?(pid)
  end
end
