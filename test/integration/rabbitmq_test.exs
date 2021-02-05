defmodule Lightrail.MessageBus.RabbitmqTest do
  # Note that we need to use async: false since tests interact
  # with external Rabbit exchanges, queues, etc.
  use Test.Support.RabbitCase, async: false

  @moduletag :integration

  alias Lightrail.MessageBus

  describe "setting up a publisher" do
    setup do
      state = %MessageBus{exchange: "lightrail:test"}
      {:ok, new_state} = Adapter.setup_publisher(state)

      %{new_state: new_state}
    end

    test "state is updated", %{new_state: new_state} do
      assert new_state.channel
    end

    test "rabbitmq artifacts are created" do
      exchange_info = get_exchange_info("lightrail:test")
      assert exchange_info.durable
      assert "fanout" == exchange_info.type
    end
  end

  describe "setting up a consumer" do
    setup do
      state = %MessageBus{exchange: "lightrail:test", queue: "lightrail:test:events"}
      {:ok, new_state} = Adapter.setup_consumer(state)
      %{new_state: new_state}
    end

    test "state is updated", %{new_state: new_state} do
      assert new_state.channel
    end

    test "rabbitmq artifacts are created" do
      exchange_info = get_exchange_info("lightrail:test")
      assert exchange_info.durable
      assert "fanout" == exchange_info.type
      assert %{"x-dead-letter-exchange": "lightrail:errors"} == exchange_info.arguments
      assert not exchange_info.auto_delete
      assert not exchange_info.internal

      queue_info = get_queue_info("lightrail:test:events")
      assert queue_info.durable
      assert %{"x-dead-letter-exchange": "lightrail:errors"} == queue_info.arguments
      assert not queue_info.auto_delete
      assert not queue_info.exclusive

      binding_info = get_binding_info("lightrail:test", "lightrail:test:events")
      assert "lightrail:test" == binding_info.source
      assert "lightrail:test:events" == binding_info.destination
      assert %{} == binding_info.arguments
      assert "queue" == binding_info.destination_type
      assert "" == binding_info.routing_key
    end
  end

  test "publish, ack, reject" do
    # No need to test these directly since they're already tested through
    # the main publisher and consumer tests.
    assert true
  end

  describe "cleanup" do
    test "closes channel" do
      {:ok, connection} =
        open_connection(Application.fetch_env!(:lightrail, :message_bus_uri))

      {:ok, channel} = open_channel(connection)

      state = %{
        module: __MODULE__,
        channel: channel,
        connection: connection
      }

      {:ok, new_state} = Adapter.cleanup(state)

      assert new_state == %{module: __MODULE__}
      wait_for_passing(_2_seconds = 3000, fn ->
        refute Process.alive?(channel.pid)
      end)
    end

    test "doesn't try to close a channel that's already closed" do
      {:ok, connection} =
        open_connection(Application.fetch_env!(:lightrail, :message_bus_uri))

      {:ok, channel} = open_channel(connection)

      close_channel(channel)
      close_connection(connection)

      state = %{
        module: __MODULE__,
        channel: channel,
        connection: connection
      }

      {:ok, new_state} = Adapter.cleanup(state)

      assert new_state == %{module: __MODULE__}
    end

    test "returns the unaltered state if channel does not exist" do
      state = %{module: __MODULE__}
      {:ok, new_state} = Adapter.cleanup(state)
      assert new_state == state
    end
  end
end
