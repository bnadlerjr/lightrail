defmodule Lightrail.Integration.PublisherTest do
  # Note that we need to use async: false since tests interact
  # with external Rabbit exchanges, queues, etc.
  use ExUnit.Case, async: false
  use Test.Support.RabbitCase

  alias Ecto.Adapters.SQL.Sandbox
  alias Test.Support.Helpers
  alias Test.Support.Message
  alias Test.Support.Publisher
  alias Test.Support.Repo

  @moduletag :integration
  @timeout _up_to_thirty_seconds = 30_000

  setup_all do
    Application.stop(:lightrail)
    Application.put_env(:lightrail, :message_bus, Lightrail.MessageBus.RabbitMQ)
    Application.start(:lightrail)
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
      Application.stop(:lightrail)
      Application.put_env(:lightrail, :message_bus, Test.Support.FakeRabbitMQ)
      Application.start(:lightrail)
    end

    on_exit(exit_fn)
    %{connection: connection}
  end

  setup context do
    exit_fn = fn ->
      rmq_purge_queue(context.connection, "lightrail:test:events")
    end

    on_exit(exit_fn)
    :ok = Sandbox.checkout(Repo)
  end

  describe "#publish" do
    test "successfully publish a message" do
      # Make sure the queue is empty
      Helpers.wait_for_passing(@timeout, fn ->
        assert 0 == rmq_queue_count("lightrail:test:events")
      end)

      # Get the current message count
      count_before = Repo.aggregate("lightrail_published_messages", :count, :uuid)

      # Publish a message
      proto = Message.new(uuid: UUID.uuid4())
      :ok = Publisher.publish_message(proto)

      # Make sure it arrived in the queue
      Helpers.wait_for_passing(@timeout, fn ->
        assert 1 == rmq_queue_count("lightrail:test:events")
      end)

      # Make sure the message was persisted
      count_after = Repo.aggregate("lightrail_published_messages", :count, :uuid)
      assert 1 == count_after - count_before
    end

    test "error handling when protobuf can't be encoded" do
      # Make sure the queue is empty
      Helpers.wait_for_passing(@timeout, fn ->
        assert 0 == rmq_queue_count("lightrail:test:events")
      end)

      # Try to publish a bad message
      expected = {
        :error,
        "Failed to publish message. \"Argument Error: Valid Protobuf required\""
      }

      assert expected == Publisher.publish_message("not a protobuf")

      # Make sure the queue is empty
      Helpers.wait_for_passing(@timeout, fn ->
        assert 0 == rmq_queue_count("lightrail:test:events")
      end)

      # Make sure the message was not persisted
      assert 0 == Repo.aggregate("lightrail_published_messages", :count, :uuid)
    end
  end
end
