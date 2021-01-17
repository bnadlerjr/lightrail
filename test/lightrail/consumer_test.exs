defmodule Lightrail.ConsumerTest do
  # Note that we need to use async: false since tests interact
  # with external Rabbit exhcanges, queues, etc.
  use ExUnit.Case, async: false
  use Test.Support.RabbitCase

  alias Lightrail.Consumer
  alias Lightrail.Message
  alias Test.Support.Helpers
  alias Test.Support.Message, as: Proto

  defmodule Subject do
    @behaviour Lightrail.Consumer

    def start_link() do
      Lightrail.Consumer.start_link(__MODULE__, name: __MODULE__)
    end

    @impl Lightrail.Consumer
    def init() do
      [
        exchange: "lightrail_example_exchange",
        queue: "lightrail_example_queue",
        connection: "amqp://guest:guest@localhost:5672"
      ]
    end

    @impl Lightrail.Consumer
    def handle_message(message) do
      case message.info do
        "this should succeed" ->
          :ok

        _ ->
          :error
      end
    end
  end

  setup_all do
    {:ok, rmq_connection} = rmq_open_connection("amqp://guest:guest@localhost:5672")
    on_exit(fn -> rmq_close_connection(rmq_connection) end)
    %{rmq_connection: rmq_connection}
  end

  setup context do
    purge = fn ->
      rmq_purge_queue(context.rmq_connection, "lightrail_example_queue")
    end

    on_exit(purge)
    purge.()
  end

  test "starting a new consumer" do
    {:ok, pid} = start_supervised(%{id: Subject, start: {Subject, :start_link, []}})
    assert Process.alive?(pid)
  end

  test "consuming a message", %{rmq_connection: connection} do
    # Publish a message
    msg = Proto.new(info: "this should succeed")
    {:ok, encoded} = Message.prepare_for_publishing(msg)
    rmq_publish_message(connection, "lightrail_example_exchange", encoded)

    # Make sure it arrived in the queue
    Helpers.wait_for_passing(_2_seconds = 2000, fn ->
      assert 1 == rmq_queue_count(connection, "lightrail_example_queue")
    end)

    # Start the consumer
    start_supervised!(%{id: Subject, start: {Subject, :start_link, []}})

    # Assert the consumer processed the message
    Helpers.wait_for_passing(_2_seconds = 2000, fn ->
      assert 0 == rmq_queue_count(connection, "lightrail_example_queue")
    end)
  end

  test "stopping a consumer" do
    pid = start_supervised!(%{id: Subject, start: {Subject, :start_link, []}})
    Consumer.stop(pid)
    assert not Process.alive?(pid)
  end
end
