defmodule Lightrail.Consumer.Logger do
  @moduledoc """
  Logging handlers for Consumer Telemetry events.

  You may either define your own handlers for `Lightrail.Consumer.Telemetry`
  events, or use this module.

  To use this module, call `attach` in your application's start function.

  For example, in your `application.ex` file:

  ```
  alias Lightrail.Consumer.Logger, as: ConsumerLog

  def start(_type, _args) do
    :ok = ConsumerLog.attach()

    # Your application start code
  end
  ```

  """

  require Logger

  @handler_id "lightrail-log-consumer-events"

  @consumer_confirm [:lightrail, :consumer, :confirm]
  @consumer_cancelled [:lightrail, :consumer, :cancelled]
  @consumer_down [:lightrail, :consumer, :down]

  @consumer_success [:lightrail, :consumer, :message, :success]
  @consumer_skip [:lightrail, :consumer, :message, :skip]
  @consumer_failure [:lightrail, :consumer, :message, :failure]
  @consumer_exception [:lightrail, :consumer, :message, :exception]

  @doc """
  Attaches this module's logging handlers to Telemetry. If the handlers are
  already attached, they will be detached and re-attached.

  """
  def attach() do
    events = [
      @consumer_confirm,
      @consumer_cancelled,
      @consumer_down,
      @consumer_success,
      @consumer_skip,
      @consumer_failure,
      @consumer_exception
    ]

    case :telemetry.attach_many(@handler_id, events, &__MODULE__.handle_event/4, nil) do
      :ok ->
        :ok

      {:error, :already_exists} ->
        :ok = :telemetry.detach(@handler_id)
        attach()
    end
  end

  @doc """
  Handles a telemetry event.

  """
  def handle_event(@consumer_confirm, _measurements, metadata, _config) do
    Logger.info(
      "[#{metadata.module}]: Broker confirmed consumer with tag " <>
        "'#{metadata.consumer_tag}' to '#{metadata.exchange}' exchange"
    )
  end

  def handle_event(@consumer_cancelled, _measurements, metadata, _config) do
    Logger.warn("[#{metadata.module}]: The consumer was cancelled (#{metadata.consumer_tag})")
  end

  def handle_event(@consumer_down, _measurements, metadata, _config) do
    Logger.info("[#{metadata.module}]: Consumer is down (#{metadata.reason})")
  end

  def handle_event(@consumer_success, _measurements, metadata, _config) do
    Logger.info(
      "[#{metadata.module}]: Consumer successfully processed " <>
        "a '#{metadata.type}' message from the '#{metadata.exchange}' " <>
        "exchange (#{metadata.uuid})"
    )
  end

  def handle_event(@consumer_skip, _measurements, metadata, _config) do
    Logger.info(
      "[#{metadata.module}]: Message (#{metadata.type}, " <>
        "#{metadata.uuid}) from the '#{metadata.exchange}' exchange is " <>
        "already being processed, skipping"
    )
  end

  def handle_event(@consumer_failure, _measurements, metadata, _config) do
    Logger.info(
      "[#{metadata.module}]: An error ocurred while processing " <>
        "'#{metadata.payload}' (#{metadata.reason})"
    )
  end

  def handle_event(@consumer_exception, _measurements, metadata, _config) do
    Logger.info(
      "[#{metadata.module}]: Unhandled exception while consuming a " <>
        "message (#{metadata.reason}, #{metadata.stacktrace})"
    )
  end
end
