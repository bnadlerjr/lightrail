defmodule Lightrail.MessageBus.RabbitMQ.Logger do
  @moduledoc """
  Logging handlers for RabbitMQ Telemetry events.

  You may either define your own handlers for
  `Lightrail.MessageBus.RabbitMQ.Telemetry` events, or use this module.

  To use this module, call `attach` in your application's start function.

  For example, in your `application.ex` file:

  ```
  alias Lightrail.MessageBus.RabbitMQ.Logger, as: RabbitLog

  def start(_type, _args) do
    :ok = RabbitLog.attach()

    # Your application start code
  end
  ```

  """

  require Logger

  @handler_id "lightrail-log-rabbitmq-events"

  @connection_open [:lightrail, :rabbitmq, :connection, :open]
  @connection_fail [:lightrail, :rabbitmq, :connection, :fail_to_open]
  @connection_down [:lightrail, :rabbitmq, :connection, :down]

  @publish_start [:lightrail, :rabbitmq, :publish, :start]
  @publish_stop [:lightrail, :rabbitmq, :publish, :stop]
  @publish_error [:lightrail, :rabbitmq, :publish, :error]

  @doc """
  Attaches this module's logging handlers to Telemetry. If the handlers are
  already attached, they will be detached and re-attached.

  """
  def attach() do
    events = [
      @connection_open,
      @connection_fail,
      @connection_down,
      @publish_start,
      @publish_stop,
      @publish_error
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
  def handle_event(@connection_open, _measurements, metadata, _config) do
    Logger.info("[#{metadata.module}] Connected to RabbitMQ")
  end

  def handle_event(@connection_fail, _measurements, metadata, _config) do
    Logger.error(
      "[#{metadata.module}] Failed to connect to RabbitMQ " <>
        "(#{metadata.kind}, #{metadata.reason})"
    )
  end

  def handle_event(@connection_down, _measurements, metadata, _config) do
    Logger.info("[#{metadata.module}] RabbitMQ connection is down (#{metadata.reason})")
  end

  def handle_event(@publish_start, _measurements, metadata, _config) do
    Logger.info(
      "[#{metadata.module}] Publishing #{metadata.message} to " <>
        "the '#{metadata.exchange}' exchange"
    )
  end

  def handle_event(@publish_stop, measurements, metadata, _config) do
    Logger.info(
      "[#{metadata.module}] Successfully published #{metadata.message} to " <>
        "the '#{metadata.exchange}' exchange (#{measurements.duration}ms)"
    )
  end

  def handle_event(@publish_error, _measurements, metadata, _config) do
    Logger.error(
      "[#{metadata.module}] Failed to publish #{metadata.message} to " <>
        "the '#{metadata.exchange}' exchange (#{metadata.kind}, " <>
        "#{metadata.reason})"
    )
  end
end
