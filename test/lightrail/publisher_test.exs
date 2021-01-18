defmodule Lightrail.PublisherTest do
  # Note that we need to use async: false since tests interact
  # with external Rabbit exhcanges, queues, etc.
  use ExUnit.Case, async: false
  use Test.Support.RabbitCase

  alias Test.Support.Helpers
  alias Test.Support.Message
  alias Test.Support.Publisher

  @timeout _up_to_thirty_seconds = 30_000

  setup_all do
    {:ok, connection} = rmq_open_connection("amqp://guest:guest@localhost:5672")
    start_supervised!(%{id: Publisher, start: {Publisher, :start_link, []}})

    exit_fn = fn ->
      rmq_purge_queue(connection, "lightrail:test:events")
      rmq_close_connection(connection)
    end

    on_exit(exit_fn)
    %{rmq_connection: connection}
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
