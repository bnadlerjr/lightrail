defmodule Lightrail.ConsumerTest do
  use ExUnit.Case, async: true

  alias Lightrail.Consumer

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

  describe "#start_link" do
    test "starts a new consumer" do
      {:ok, pid} = Consumer.start_link(Subject)
      assert Process.alive?(pid)
    end

    test "supports registering a consumer name" do
      {:ok, pid} = Consumer.start_link(Subject, name: Subject)
      assert Process.whereis(Subject) == pid
    end
  end

  describe "#stop" do
    test "stops the consumer" do
      {:ok, pid} = Consumer.start_link(Subject)
      assert Process.alive?(pid)
      Consumer.stop(pid)
      assert not Process.alive?(pid)
    end
  end
end
