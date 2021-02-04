defmodule Lightrail.Consumer do
  @moduledoc """
  A behaviour module for implementing a consumer.

  * allows consumer configuration to be set

  * starts a `Lightrail.Consumer.Server` process that tracks channel
    information state

  * provides a `handle_message` callback that receives a decoded
    protobuf struct

  ## Example

  ```
  defmodule ExampleConsumer do
    @behaviour Lightrail.Consumer

    def start_link() do
      Lightrail.Consumer.start_link(__MODULE__, name: __MODULE__)
    end

    @impl Lightrail.Consumer
    def init() do
      [
        exchange: "lightrail_example_exchange",
        queue: "lightrail_example_queue"
      ]
    end

    @impl Lightrail.Consumer
    def handle_message(_message) do
      # do something with the message
      :ok
    end
  end
  ```
  """

  require Logger

  alias Lightrail.Message
  alias Lightrail.Messages

  @doc """
  Used to provide consumer configuration.

  ## Required Values

  `exchange` - The name of the exchange to consume.
  `queue` - The name of the queue to consume.

  ## Examples

  ```
  @impl Lightrail.Consumer
  def init() do
    [
      exchange: "example",
      queue: "my_queue"
    ]
  end
  ```

  """
  @callback init() :: [exchange: String.t(), queue: String.t()]

  @doc """
  Message handler. This callback will be called when a message is consumed. If
  an error occurs when handling the message, this function should return
  `:error`, which will cause the message bus to reject the message. Any other
  return value will be considered successful, and the message bus will
  acknowledge the message.

  ## Example

  ```
  @impl Lightrail.Consumer
  def handle_message(message) do
    # do something with the message
    :ok
  end
  ```

  """
  @callback handle_message(message :: keyword) :: :ok | :error

  @doc """
  Starts the `Lightrail.Consumer` process with the given callback module
  linked to the current process.

  `module` - Callback module implementing `Lightrail.Consumer` behaviour.

  ## Options
   * `:name` - used for name registration

  ## Return values
  If the consumer is successfully created and initialized, this function
  returns `{:ok, pid}`, where `pid` is the PID of the consumer. If a
  process with the specified consumer name already exists, this function
  returns `{:error, {:already_started, pid}}` with the PID of that process.

  ## Examples:

  ```
  Lightrail.Consumer.start_link(__MODULE__, name: __MODULE__)
  ```

  """
  @spec start_link(module, Keyword.t()) :: {:ok, pid} | {:error, term}
  def start_link(module, options \\ []) do
    GenServer.start_link(Lightrail.Consumer.Server, %{module: module}, options)
  end

  @doc """
  Stops the consumer.

  """
  @spec stop(pid, term) :: :ok
  def stop(pid, reason \\ :normal) do
    GenServer.stop(pid, reason)
  end

  def process(payload, _attrs, %{module: module} = state) do
    Map.merge(state, %{payload: payload})
    |> decode_payload()
    |> find_or_create_message()
    |> apply_handler()
  rescue
    reason ->
      full_error = {reason, __STACKTRACE__}

      Logger.error(
        "[#{module}]: Unhandled exception while " <>
          "consuming message. #{inspect(full_error)}"
      )

      :error
  end

  defp decode_payload(%{payload: payload, module: module} = info) do
    case Message.decode(payload) do
      {:ok, proto, type} ->
        Map.merge(info, %{proto: proto, type: type})

      {:error, error} ->
        Logger.error(
          "[#{module}]: An error occurred while " <>
            "decoding a message. #{error}"
        )

        :error
    end
  end

  defp find_or_create_message(%{module: module} = info) do
    params = %{
      protobuf: info.proto,
      encoded: info.payload,
      exchange: info.exchange,
      type: info.type,
      queue: info.queue
    }

    case Messages.upsert(params) do
      {:ok, persisted} ->
        Map.merge(info, %{persisted: persisted})

      {:skip, _} ->
        {:skip, info}

      {:error, error} ->
        Logger.error(
          "[#{module}]: An error occurred while " <>
            "persisting a message. #{error}"
        )

        :error
    end
  end

  defp find_or_create_message(:error), do: :error

  defp apply_handler(%{proto: proto, module: module, persisted: persisted}) do
    case apply(module, :handle_message, [proto]) do
      :ok ->
        Messages.transition_status(persisted, "success")
        :ok

      :error ->
        Messages.transition_status(persisted, "failed_to_process")
        :error
    end
  end

  defp apply_handler({:skip, %{module: module}}) do
    Logger.info("[#{module}]: Message is already being processed, skipping")
    :ok
  end

  defp apply_handler(:error), do: :error
end
