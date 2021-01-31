defmodule Lightrail.ConsumerTest do
  use ExUnit.Case, async: true

  import Test.Support.Helpers

  alias Ecto.Adapters.SQL.Sandbox
  alias Lightrail.Consumer
  alias Lightrail.Message
  alias Test.Support.Message, as: Proto
  alias Test.Support.Repo

  defmodule Subject do
    @behaviour Lightrail.Consumer

    def start_link() do
      Lightrail.Consumer.start_link(__MODULE__, name: __MODULE__)
    end

    @impl Lightrail.Consumer
    def init() do
      [
        exchange: "lightrail:test",
        queue: "lightrail:test:events",
        connection: "amqp://guest:guest@localhost:5672"
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

  describe "#process" do
    setup do
      %{module: Subject, exchange: "lightrail:test", queue: "lightrail:test:event"}
    end

    test "successfully process the message payload", context do
      proto = Proto.new(uuid: UUID.uuid4(), info: "this should be acked")
      {:ok, encoded, _type} = Message.prepare_for_publishing(proto)

      assert_difference row_count("lightrail_consumed_messages"), count: 1 do
        :ok = Consumer.process(encoded, %{}, context)
      end

      persisted = get_consumed_message!(proto.uuid)
      assert "success" == persisted.status
    end

    test "message could not be decoded", context do
      assert_difference row_count("lightrail_consumed_messages"), count: 0 do
        :error = Consumer.process("invalid", %{}, context)
      end
    end

    test "message could not be persisted", context do
      proto = Proto.new(uuid: UUID.uuid4(), info: "this should be acked")
      {:ok, encoded, _type} = Message.prepare_for_publishing(proto)
      invalid_info = %{context | queue: nil}

      assert_difference row_count("lightrail_consumed_messages"), count: 0 do
        :error = Consumer.process(encoded, %{}, invalid_info)
      end
    end

    test "message processing handler failed", context do
      proto = Proto.new(uuid: UUID.uuid4(), info: "this should be rejected")
      {:ok, encoded, _type} = Message.prepare_for_publishing(proto)

      assert_difference row_count("lightrail_consumed_messages"), count: 1 do
        :error = Consumer.process(encoded, %{}, context)
      end

      persisted = get_consumed_message!(proto.uuid)
      assert "failed_to_process" == persisted.status
    end
  end

  test "starting a new consumer" do
    {:ok, pid} = start_supervised(%{id: Subject, start: {Subject, :start_link, []}})
    assert Process.alive?(pid)
  end

  test "stopping a consumer" do
    pid = start_supervised!(%{id: Subject, start: {Subject, :start_link, []}})
    Consumer.stop(pid)
    assert not Process.alive?(pid)
  end
end
