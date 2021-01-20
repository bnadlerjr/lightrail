defmodule Lightrail.PublisherTest do
  # Note that we need to use async: false since tests interact
  # with external Rabbit exchanges, queues, etc.
  use ExUnit.Case, async: false
  use Test.Support.RabbitCase

  alias Test.Support.Helpers
  alias Test.Support.Message
  alias Test.Support.Publisher

  @timeout _up_to_thirty_seconds = 30_000

  setup_all do
    {:ok, connection} = rmq_open_connection("amqp://guest:guest@localhost:5672")

    # Publishers don't know about queues, only exchanges. If we send a
    # message to an exchange that doesn't have a queue bound to it, the
    # message will be lost. In production, this isn't an issue since
    # consumers will take care of the binding. However, here we have to
    # setup the queue ourselves since no consumer is set up otherwise the
    # test message will be lost.
    rmq_create_and_bind_queue(connection, "lightrail:test:events", "lightrail:test")

    start_supervised!(%{id: Publisher, start: {Publisher, :start_link, []}})

    exit_fn = fn ->
      rmq_delete_queue(connection, "lightrail:test:events")
      rmq_delete_exchange(connection, "lightrail:test")
      rmq_close_connection(connection)
    end

    on_exit(exit_fn)
    %{connection: connection}
  end

  setup context do
    exit_fn = fn ->
      rmq_purge_queue(context.connection, "lightrail:test:events")
    end

    on_exit(exit_fn)
  end

  describe "#publish" do
    @tag :rabbit
    test "successfully publish a message" do
      # Make sure the queue is empty
      Helpers.wait_for_passing(@timeout, fn ->
        assert 0 == rmq_queue_count("lightrail:test:events")
      end)

      # Publish a message
      proto = Message.new(uuid: "abc123")
      assert :ok == Publisher.publish_message(proto)

      # Make sure it arrived in the queue
      Helpers.wait_for_passing(@timeout, fn ->
        assert 1 == rmq_queue_count("lightrail:test:events")
      end)
    end

    @tag :rabbit
    test "error handling when protobuf can't be encoded" do
      # Make sure the queue is empty
      Helpers.wait_for_passing(@timeout, fn ->
        assert 0 == rmq_queue_count("lightrail:test:events")
      end)

      # Try to publish a bad message
      expected = {
        :error,
        "An error occurred while attempting to publish a message. Argument Error: Valid Protobuf required"
      }

      assert expected == Publisher.publish_message("not a protobuf")

      # Make sure the queue is empty
      Helpers.wait_for_passing(@timeout, fn ->
        assert 0 == rmq_queue_count("lightrail:test:events")
      end)
    end
  end
end
