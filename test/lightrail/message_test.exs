defmodule Lightrail.MessageTest do
  use ExUnit.Case, async: true

  alias Lightrail.Message
  alias Lightrail.MessageFormat.BinaryProtobuf
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

  describe "#consume" do
    test "successfully process a binary protobuf message" do
      msg = Proto.new(info: "this should succeed")
      {:ok, encoded} = BinaryProtobuf.encode(msg)
      assert :ok == Message.consume(encoded, Subject)
    end

    test "handling message handler errors" do
      msg = Proto.new(info: "this should fail")
      {:ok, encoded} = BinaryProtobuf.encode(msg)
      assert :error == Message.consume(encoded, Subject)
    end

    test "handling binary protobuf decode errors" do
      encoded = "not a valid protobuf"
      assert :error == Message.consume(encoded, Subject)
    end
  end
end
