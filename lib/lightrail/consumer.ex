defmodule Lightrail.Consumer do
  @moduledoc """
  Public interface for a consumer.

  TODO:

  * docstrings for functions since this is a public API
  * put example implementation in moduledoc
  * anything to cleanup for callback type signatures?
  * is the stop function needed? how will it be used?

  """

  @callback init() :: [connection: String.t(), exchange: String.t(), queue: String.t()]
  @callback handle_message(message :: keyword) :: :ok
  @callback handle_error(message :: atom(), reason :: atom()) :: :ok

  def start_link(module, options \\ []) do
    GenServer.start_link(Lightrail.Consumer.Server, %{module: module}, options)
  end

  def stop(pid, reason) do
    GenServer.stop(pid, reason)
  end
end
