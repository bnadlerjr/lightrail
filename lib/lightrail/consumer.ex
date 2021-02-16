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

      # if handling the message causes an error return either a bare `:error`
      # or a tuple `{:error, "reason why there was an error"}`
    end
  end
  ```
  """

  alias Lightrail.Consumer.Telemetry
  alias Lightrail.Message
  alias Lightrail.MessageStore.IncomingMessage

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
    |> emit_telemetry()
  rescue
    reason ->
      Telemetry.emit_consumer_exception(module, reason, __STACKTRACE__)
      reraise reason, __STACKTRACE__
  end

  defp decode_payload(%{payload: payload} = info) do
    case Message.decode(payload) do
      {:ok, proto, type} ->
        {:ok, Map.merge(info, %{proto: proto, type: type})}

      {:error, error} ->
        {:error, error, info}
    end
  end

  defp find_or_create_message({:ok, info}) do
    msg = %IncomingMessage{
      protobuf: info.proto,
      encoded: info.payload,
      exchange: info.exchange,
      type: info.type,
      queue: info.queue
    }

    message_store = Application.fetch_env!(:lightrail, :message_store)

    case message_store.upsert(msg) do
      {:ok, persisted} ->
        {:ok, Map.merge(info, %{persisted: persisted, incoming: msg})}

      {:skip, _} ->
        {:skip, info}

      {:error, error} ->
        {:error, error, info}
    end
  end

  defp find_or_create_message({:error, error, info}), do: {:error, error, info}

  defp apply_handler({:ok, %{proto: proto, module: module, incoming: msg} = info}) do
    message_store = Application.fetch_env!(:lightrail, :message_store)

    case apply(module, :handle_message, [proto]) do
      :ok ->
        message_store.transition_status(msg, "success")
        {:ok, info}

      {:error, error} ->
        message_store.transition_status(msg, "failed_to_process")
        {:error, error, info}

      :error ->
        message_store.transition_status(msg, "failed_to_process")
        {:error, "Handler did not provide error message", info}
    end
  end

  defp apply_handler({:skip, info}) do
    %{module: module, type: type, proto: proto, exchange: exchange} = info
    Telemetry.emit_consumer_skip(module, type, proto.uuid, exchange)
    {:ok, info}
  end

  defp apply_handler({:error, error, info}), do: {:error, error, info}

  defp emit_telemetry({:ok, info}) do
    %{module: module, proto: proto, type: type, exchange: exchange} = info
    Telemetry.emit_consumer_success(module, type, proto.uuid, exchange)
    :ok
  end

  defp emit_telemetry({:error, error, %{module: module, payload: payload}}) do
    Telemetry.emit_consumer_failure(module, error, payload)
    {:error, error}
  end
end
