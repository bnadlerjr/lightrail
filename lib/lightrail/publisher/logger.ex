defmodule Lightrail.Publisher.Logger do
  @moduledoc """
  Logging handlers for Publisher Telemetry events.

  You may either define your own handlers for `Lightrail.Publisher.Telemetry`
  events, or use this module.

  To use this module, call `attach` in your application's start function.

  For example, in your `application.ex` file:

  ```
  alias Lightrail.Publisher.Logger, as: PublisherLog

  def start(_type, _args) do
    :ok = PublisherLog.attach()

    # Your application start code
  end
  ```

  """

  require Logger

  @handler_id "lightrail-log-publisher-events"

  @publish_success [:lightrail, :publisher, :publish, :success]
  @publish_failure [:lightrail, :publisher, :publish, :failure]
  @publish_down [:lightrail, :publisher, :down]

  @doc """
  Attaches this module's logging handlers to Telemetry. If the handlers are
  already attached, they will be detached and re-attached.

  """
  def attach() do
    events = [
      @publish_success,
      @publish_failure,
      @publish_down
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
  def handle_event(@publish_success, _measurements, metadata, _config) do
    Logger.info(
      "[#{metadata.module}]: Published a '#{metadata.type}' message " <>
        "to '#{metadata.exchange}' exchange"
    )
  end

  def handle_event(@publish_failure, _measurements, metadata, _config) do
    Logger.error("[#{metadata.module}]: Failed to publish message (#{metadata.reason})")
  end

  def handle_event(@publish_down, _measurements, metadata, _config) do
    Logger.info("[#{metadata.module}]: Publisher is down (#{metadata.reason})")
  end
end
