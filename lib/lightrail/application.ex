defmodule Lightrail.Application do
  @moduledoc false

  use Application

  alias Lightrail.MessageBus.Connection

  def start(_type, _args) do
    children = [
      %{
        id: PublisherConnection,
        start: {Connection, :start_link, [[name: :publisher_connection]]}
      },
      %{
        id: ConsumerConnection,
        start: {Connection, :start_link, [[name: :consumer_connection]]}
      }
    ]

    opts = [strategy: :one_for_one, name: Lightrail.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
