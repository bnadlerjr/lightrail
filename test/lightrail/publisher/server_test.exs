defmodule Lightrail.Publisher.ServerTest do
  # Note that we need to use async: false since tests interact
  # with external Rabbit exhcanges, queues, etc.
  use ExUnit.Case, async: false
  use Test.Support.RabbitCase

  alias Lightrail.Publisher.Server

  defmodule Subject do
    def init() do
      [
        exchange: "lightrail_example_exchange",
        connection: "amqp://guest:guest@localhost:5672"
      ]
    end
  end

  setup_all do
    {:ok, connection} = rmq_open_connection("amqp://guest:guest@localhost:5672")
    {:ok, channel} = rmq_open_channel(connection)

    on_exit(fn ->
      rmq_close_channel(channel)
      rmq_close_connection(connection)
    end)

    %{connection: connection, channel: channel}
  end

  setup context do
    on_exit(fn ->
      rmq_purge_queue(context.connection, "lightrail_example_queue")
    end)
  end

  test "initialization" do
    {:ok, state, {:continue, :init}} = Server.init(%{module: Subject})

    expected_state = %{
      config: [
        exchange: "lightrail_example_exchange",
        connection: "amqp://guest:guest@localhost:5672"
      ],
      module: Lightrail.Publisher.ServerTest.Subject
    }

    assert state == expected_state
  end

  test "message bus setup" do
    state = %{
      config: [
        exchange: "lightrail_example_exchange",
        connection: "amqp://guest:guest@localhost:5672"
      ],
      module: Lightrail.Publisher.ServerTest.Subject
    }

    {:noreply, new_state} = Server.handle_continue(:init, state)
    assert Map.has_key?(new_state, :connection)
    assert Map.has_key?(new_state, :channel)
  end

  test "handle publish", %{connection: connection, channel: channel} do
    state = %{
      config: [
        exchange: "lightrail_example_exchange",
        connection: "amqp://guest:guest@localhost:5672"
      ],
      channel: channel,
      connection: connection,
      module: Lightrail.Publisher.ServerTest.Subject
    }

    {:reply, result, new_state} = Server.handle_call({:publish, "message"}, self(), state)

    assert result == :ok
    assert state == new_state
  end
end
