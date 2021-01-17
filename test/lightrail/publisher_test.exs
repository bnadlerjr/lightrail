defmodule Lightrail.PublisherTest do
  # Note that we need to use async: false since tests interact
  # with external Rabbit exhcanges, queues, etc.
  use ExUnit.Case, async: false
  use Test.Support.RabbitCase

  alias Test.Support.Message
  alias Test.Support.Publisher

  setup_all do
    {:ok, rmq_connection} = rmq_open_connection("amqp://guest:guest@localhost:5672")
    on_exit(fn -> rmq_close_connection(rmq_connection) end)
    %{rmq_connection: rmq_connection}
  end

  describe "initialization" do
    test "starts a new publisher" do
      {:ok, pid} = start_supervised(%{id: Publisher, start: {Publisher, :start_link, []}})

      assert Process.alive?(pid)
    end
  end

  describe "#publish" do
    setup context do
      start_supervised!(%{id: Publisher, start: {Publisher, :start_link, []}})

      on_exit(fn ->
        rmq_purge_queue(context.rmq_connection, "lightrail:test:events")
      end)
    end

    test "successfully publish a message" do
      proto = Message.new(uuid: "abc123")
      assert :ok == Publisher.publish_message(proto)
    end

    test "error handling when protobuf can't be encoded" do
      expected = {
        :error,
        "An error occurred while attempting to publish a message. Argument Error: Valid Protobuf required"
      }

      assert expected == Publisher.publish_message("not a protobuf")
    end
  end
end
