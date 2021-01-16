defmodule Lightrail.PublisherTest do
  use ExUnit.Case, async: true

  alias Lightrail.Publisher
  alias Test.Support.Message

  defmodule Subject do
    @behaviour Lightrail.Publisher

    def start_link() do
      Lightrail.Publisher.start_link(__MODULE__, name: __MODULE__)
    end

    @impl Lightrail.Publisher
    def init() do
      [
        exchange: "lightrail_example_exchange",
        connection: "amqp://guest:guest@localhost:5672"
      ]
    end
  end

  describe "#start_link" do
    test "starts a new publisher" do
      {:ok, pid} = Publisher.start_link(Subject)
      assert Process.alive?(pid)
    end

    test "supports registering a publisher name" do
      {:ok, pid} = Publisher.start_link(Subject, name: Subject)
      assert Process.whereis(Subject) == pid
    end
  end

  describe "#publish" do
    setup do
      {:ok, server_pid} = Subject.start_link()
      {:ok, server: server_pid}
    end

    test "successfully publish a message", %{server: pid} do
      proto = Message.new(uuid: "abc123")
      assert :ok == Publisher.publish(pid, proto)
    end

    test "error handling when protobuf can't be encoded", %{server: pid} do
      expected = {
        :error,
        "An error occurred while attempting to publish a message. Argument Error: Valid Protobuf required"
      }

      assert expected == Publisher.publish(pid, "not a protobuf")
    end
  end
end
