defmodule Lightrail.MessageBus.RabbitMQ.Connection do
  @moduledoc """
  A RabbitMQ connection.

  """

  alias Lightrail.MessageBus.RabbitMQ.Server

  def start_link(options) do
    config = %Server{
      uri: Application.fetch_env!(:lightrail, :message_bus_uri),
      adapter: Application.fetch_env!(:lightrail, :message_bus)
    }

    GenServer.start_link(Server, config, options)
  end

  def get(name) do
    case find_process(name) do
      nil ->
        {:error, "Cannot find connection #{inspect(name)}"}

      pid ->
        {:ok, GenServer.call(pid, {:get_connection})}
    end
  end

  defp find_process(:publisher_connection = name), do: Process.whereis(name)
  defp find_process(:consumer_connection = name), do: Process.whereis(name)
  defp find_process(_), do: nil
end
