defmodule Lightrail.Integration.ConsumerTest do
  # Note that we need to use async: false since tests interact
  # with external Rabbit exhcanges, queues, etc.
  use Test.Support.RabbitCase, async: false

  import Test.Support.Helpers

  alias Ecto.Adapters.SQL.Sandbox
  alias Lightrail.Message
  alias Test.Support.Message, as: Proto
  alias Test.Support.Repo

  @moduletag :integration
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
        queue: "lightrail:test:events"
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

  setup do
    :ok = Sandbox.checkout(Repo)
    Sandbox.mode(Repo, {:shared, self()})
  end

  test "acknowledging a message", %{connection: connection} do
    # Make sure the queue is empty
    wait_for_passing(@timeout, fn ->
      assert 0 == queue_count("lightrail:test:events")
    end)

    # Publish a message
    msg = Proto.new(info: "this should be acked")
    {:ok, encoded, _type} = Message.prepare_for_publishing(msg)
    publish_message(connection, "lightrail:test", encoded)

    # Make sure it arrived in the queue
    wait_for_passing(@timeout, fn ->
      assert 1 == queue_count("lightrail:test:events")
    end)

    # Start the consumer
    start_supervised!(%{id: Subject, start: {Subject, :start_link, []}})

    # Assert the consumer processed the message
    wait_for_passing(@timeout, fn ->
      assert 0 == queue_count("lightrail:test:events")
    end)
  end

  test "rejecting a message", %{connection: connection} do
    # Make sure the queue is empty
    wait_for_passing(@timeout, fn ->
      assert 0 == queue_count("lightrail:test:events")
    end)

    # Publish a message
    msg = Proto.new(info: "this should be rejected")
    {:ok, encoded, _type} = Message.prepare_for_publishing(msg)
    publish_message(connection, "lightrail:test", encoded)

    # Make sure it arrived in the queue
    wait_for_passing(@timeout, fn ->
      assert 1 == queue_count("lightrail:test:events")
    end)

    # Start the consumer
    start_supervised!(%{id: Subject, start: {Subject, :start_link, []}})

    # Assert the consumer rejected the message
    wait_for_passing(@timeout, fn ->
      assert 1 == queue_count("lightrail:test:events")
    end)
  end

  test "error handling", %{connection: connection} do
    # Make sure the queue is empty
    wait_for_passing(@timeout, fn ->
      assert 0 == queue_count("lightrail:test:events")
    end)

    # Publish a message
    msg = Proto.new(info: "this should blow up")
    {:ok, encoded, _type} = Message.prepare_for_publishing(msg)
    publish_message(connection, "lightrail:test", encoded)

    # Make sure it arrived in the queue
    wait_for_passing(@timeout, fn ->
      assert 1 == queue_count("lightrail:test:events")
    end)

    # Start the consumer
    start_supervised!(%{id: Subject, start: {Subject, :start_link, []}})

    # Assert the consumer rejected the message
    wait_for_passing(@timeout, fn ->
      assert 1 == queue_count("lightrail:test:events")
    end)
  end
end
