defmodule Lightrail.Integration.PublisherTest do
  # Note that we need to use async: false since tests interact
  # with external Rabbit exchanges, queues, etc.
  use Test.Support.RabbitCase, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Test.Support.Helpers
  alias Test.Support.Message
  alias Test.Support.Publisher
  alias Test.Support.Repo

  @moduletag :integration
  @timeout _up_to_thirty_seconds = 30_000

  setup do
    start_supervised!(%{id: Publisher, start: {Publisher, :start_link, []}})
    :ok = Sandbox.checkout(Repo)
  end

  describe "#publish" do
    test "successfully publish a message" do
      # Make sure the queue is empty
      Helpers.wait_for_passing(@timeout, fn ->
        assert 0 == queue_count("lightrail:test:events")
      end)

      # Get the current message count
      count_before = Repo.aggregate("lightrail_published_messages", :count, :uuid)

      # Publish a message
      proto = Message.new(uuid: UUID.uuid4())
      :ok = Publisher.publish_message(proto)

      # Make sure it arrived in the queue
      Helpers.wait_for_passing(@timeout, fn ->
        assert 1 == queue_count("lightrail:test:events")
      end)

      # Make sure the message was persisted
      count_after = Repo.aggregate("lightrail_published_messages", :count, :uuid)
      assert 1 == count_after - count_before
    end

    test "error handling when protobuf can't be encoded" do
      # Make sure the queue is empty
      Helpers.wait_for_passing(@timeout, fn ->
        assert 0 == queue_count("lightrail:test:events")
      end)

      # Try to publish a bad message
      expected = {
        :error,
        "Failed to publish message. \"Argument Error: Valid Protobuf required\""
      }

      assert expected == Publisher.publish_message("not a protobuf")

      # Make sure the queue is empty
      Helpers.wait_for_passing(@timeout, fn ->
        assert 0 == queue_count("lightrail:test:events")
      end)

      # Make sure the message was not persisted
      assert 0 == Repo.aggregate("lightrail_published_messages", :count, :uuid)
    end
  end
end
