defmodule Lightrail.Consumer.Telemetry do
  @moduledoc """
  [Telemetry][1] events for Consumers.

  [1]: https://github.com/beam-telemetry/telemetry
  """

  @doc """
  Dispatched by `Lightrail.Consumer.Server` when the broker confirms the
  consumer.

  - Measurement: `%{system_time: integer}`
  - Metadata: `%{module: term, consumer_tag: term, exchange: term}`

  """
  def emit_consumer_confirmed(module, tag, exchange) do
    event = [:lightrail, :consumer, :confirm]
    metadata = %{module: module, consumer_tag: tag, exchange: exchange}
    emit(event, metadata)
  end

  @doc """
  Dispatched by `Lightrail.Consumer.Server` when the consumer is cancelled.

  - Measurement: `%{system_time: integer}`
  - Metadata: `%{module: term, consumer_tag: term}`

  """
  def emit_consumer_cancelled(module, tag) do
    event = [:lightrail, :consumer, :cancelled]
    metadata = %{module: module, consumer_tag: tag}
    emit(event, metadata)
  end

  @doc """
  Dispatched by `Lightrail.Consumer.Server` when a Consumer is shut down.

  - Measurement: `%{system_time: integer}`
  - Metadata: `%{module: term, reason: atom}`

  """
  def emit_consumer_down(module, reason) do
    event = [:lightrail, :consumer, :down]
    metadata = %{module: module, reason: reason}
    emit(event, metadata)
  end

  @doc """
  Dispatched by `Lightrail.Consumer` when a Consumer successfully processes
  a message.

  - Measurement: `%{system_time: integer}`
  - Metadata: `%{module: term, type: term, uuid: term, exchange: term}`

  """
  def emit_consumer_success(module, type, uuid, exchange) do
    event = [:lightrail, :consumer, :message, :success]
    metadata = %{module: module, type: type, uuid: uuid, exchange: exchange}
    emit(event, metadata)
  end

  @doc """
  Dispatched by `Lightrail.Consumer` when a Consumer skips processing
  a message.

  - Measurement: `%{system_time: integer}`
  - Metadata: `%{module: term, type: term, uuid: term, exchange: term}`

  """
  def emit_consumer_skip(module, type, uuid, exchange) do
    event = [:lightrail, :consumer, :message, :skip]
    metadata = %{module: module, type: type, uuid: uuid, exchange: exchange}
    emit(event, metadata)
  end

  @doc """
  Dispatched by `Lightrail.Consumer` when a Consumer fails to process
  a message.

  - Measurement: `%{system_time: integer}`
  - Metadata: `%{module: term, reason: term, payload: term}`

  """
  def emit_consumer_failure(module, reason, payload) do
    event = [:lightrail, :consumer, :message, :failure]
    metadata = %{module: module, reason: reason, payload: payload}
    emit(event, metadata)
  end

  @doc """
  Dispatched by `Lightrail.Consumer` when a Consumer raises an unhandled
  exception while processing a message.

  - Measurement: `%{system_time: integer}`
  - Metadata: `%{module: term, reason: atom, stacktrace: list()}`

  """
  def emit_consumer_exception(module, reason, stacktrace) do
    event = [:lightrail, :consumer, :message, :exception]
    metadata = %{module: module, reason: reason, stacktrace: stacktrace}
    emit(event, metadata)
  end

  defp emit(event, metadata) do
    emit(event, %{}, metadata)
  end

  defp emit(event, measurements, metadata) do
    additional_measurements = %{system_time: System.system_time()}
    :telemetry.execute(event, Map.merge(measurements, additional_measurements), metadata)
  end
end
