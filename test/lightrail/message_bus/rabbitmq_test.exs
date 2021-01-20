defmodule Lightrail.MessageBus.RabbitmqTest do
  # Note that we need to use async: false since tests interact
  # with external Rabbit exchanges, queues, etc.
  use ExUnit.Case, async: false
  use Test.Support.RabbitCase

  alias Lightrail.MessageBus.RabbitMQ

  # Even though these are rabbit tests, they're pretty fast since we're not
  # waiting for messages to arrive in queue, be consumed, etc; holding off
  # giving them the :rabbit tag for now

  setup do
    exit_fn = fn ->
      {:ok, connection} = rmq_open_connection("amqp://guest:guest@localhost:5672")
      rmq_delete_queue(connection, "lightrail:test:events")
      rmq_delete_exchange(connection, "lightrail:test")
      rmq_close_connection(connection)
    end

    on_exit(exit_fn)
  end

  describe "setting up a publisher" do
    setup do
      config = %{
        connection: "amqp://guest:guest@localhost:5672",
        exchange: "lightrail:test"
      }

      state = %{module: __MODULE__, config: config}
      {:ok, new_state} = RabbitMQ.setup_publisher(state)

      %{new_state: new_state}
    end

    test "state is updated", %{new_state: new_state} do
      assert new_state.connection
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
      config = %{
        connection: "amqp://guest:guest@localhost:5672",
        exchange: "lightrail:test",
        queue: "lightrail:test:events"
      }

      state = %{module: __MODULE__, config: config}
      {:ok, new_state} = RabbitMQ.setup_consumer(state)

      %{new_state: new_state}
    end

    test "state is updated", %{new_state: new_state} do
      assert new_state.connection
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
    # the main publisher an consumer tests.
    assert true
  end

  describe "cleanup" do
    test "closes both channel and connection" do
      {:ok, connection} = rmq_open_connection("amqp://guest:guest@localhost:5672")
      {:ok, channel} = rmq_open_channel(connection)

      state = %{
        module: __MODULE__,
        channel: channel,
        connection: connection
      }

      {:ok, new_state} = RabbitMQ.cleanup(state)

      assert new_state == %{module: __MODULE__}
      refute Process.alive?(connection.pid)
      refute Process.alive?(channel.pid)
    end

    test "doesn't try to close a channel or connection that's already closed" do
      {:ok, connection} = rmq_open_connection("amqp://guest:guest@localhost:5672")
      {:ok, channel} = rmq_open_channel(connection)

      rmq_close_channel(channel)
      rmq_close_connection(connection)

      state = %{
        module: __MODULE__,
        channel: channel,
        connection: connection
      }

      {:ok, new_state} = RabbitMQ.cleanup(state)

      assert new_state == %{module: __MODULE__}
    end

    test "returns the unaltered state if connection and channel do not exist" do
      state = %{module: __MODULE__}
      {:ok, new_state} = RabbitMQ.cleanup(state)
      assert new_state == state
    end
  end
end
