defmodule Lightrail.Publisher.ServerTest do
  use ExUnit.Case, async: true
  use AMQP

  alias Lightrail.Publisher.Server

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

  test "handle publish" do
    {:ok, connection} = Connection.open("amqp://guest:guest@localhost:5672")
    {:ok, channel} = Channel.open(connection)

    state = %{
      config: [
        exchange: "lightrail_example_exchange",
        connection: "amqp://guest:guest@localhost:5672"
      ],
      channel: channel,
      connection: connection,
      module: Lightrail.Publisher.ServerTest.Subject
    }

    {:reply, result, _state} = Server.handle_call({:publish, "message"}, self(), state)
    assert result == :ok
  end
end
