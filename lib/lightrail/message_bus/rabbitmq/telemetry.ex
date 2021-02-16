defmodule Lightrail.MessageBus.RabbitMQ.Telemetry do
  @moduledoc """
  [Telemetry][1] events for RabbitMQ.

  [1]: https://github.com/beam-telemetry/telemetry
  """

  alias Lightrail.Telemetry

  @doc """
  Dispatched by `Lightrail.MessageBus.RabbitMQ.Adapter` when RabbitMQ
  connection is opened.

  - Measurement: `%{system_time: integer}`
  - Metadata: `%{module: term}`

  """
  def emit_connection_open(module) do
    event = [:lightrail, :rabbitmq, :connection, :open]
    metadata = %{module: module}
    Telemetry.emit(event, metadata)
  end

  @doc """
  Dispatched by `Lightrail.MessageBus.RabbitMQ.Adapter` when RabbitMQ
  connection cannot be established.

  - Measurement: `%{system_time: integer}`
  - Metadata: `%{module: term, kind: atom, reason: term}`

  """
  def emit_connection_fail(module, kind, reason) do
    event = [:lightrail, :rabbitmq, :connection, :fail_to_open]
    metadata = %{module: module, kind: kind, reason: reason}
    Telemetry.emit(event, metadata)
  end

  @doc """
  Dispatched by `Lightrail.MessageBus.RabbitMQ.Server` when RabbitMQ
  connection is lost.

  - Measurement: `%{system_time: integer}`
  - Metadata: `%{module: term, reason: atom}`

  """
  def emit_connection_down(module, reason) do
    event = [:lightrail, :rabbitmq, :connection, :down]
    metadata = %{module: module, reason: reason}
    Telemetry.emit(event, metadata)
  end

  @doc """
  Dispatched by `Lightrail.MessageBus.RabbitMQ.Adapter` when a message is
  about to be published.

  - Measurement: `%{system_time: integer}`
  - Metadata: `%{module: term, exchange: term, message: String.t()}`

  """
  def emit_publish_start(module, exchange, message) do
    event = [:lightrail, :rabbitmq, :publish, :start]
    metadata = %{module: module, exchange: exchange, message: message}
    Telemetry.emit(event, metadata)
    System.monotonic_time()
  end

  @doc """
  Dispatched by `Lightrail.MessageBus.RabbitMQ.Adapter` when a message has
  been successfully published. The duration is in milliseconds.

  - Measurement: `%{system_time: integer, duration: integer}`
  - Metadata: `%{module: term, exchange: term, message: String.t()}`

  """
  def emit_publish_stop(module, start_time, exchange, message) do
    event = [:lightrail, :rabbitmq, :publish, :stop]
    measurements = %{duration: calculate_duration_ms(start_time)}
    metadata = %{module: module, exchange: exchange, message: message}
    Telemetry.emit(event, measurements, metadata)
  end

  @doc """
  Dispatched by `Lightrail.MessageBus.RabbitMQ.Adapter` when an error occurs
  while attempting to publish a message. The duration is in milliseconds.

  - Measurement: `%{system_time: integer, duration: integer}`
  - Metadata: `%{module: term, exchange: term, message: String.t(), kind: atom, reason: term}`

  """
  def emit_publish_error(module, start_time, exchange, message, kind, reason) do
    event = [:lightrail, :rabbitmq, :publish, :error]
    measurements = %{duration: calculate_duration_ms(start_time)}

    metadata = %{
      module: module,
      exchange: exchange,
      message: message,
      kind: kind,
      reason: reason
    }

    Telemetry.emit(event, measurements, metadata)
  end

  defp calculate_duration_ms(start_time) do
    stop_time = System.monotonic_time()
    System.convert_time_unit(stop_time - start_time, :native, :millisecond)
  end
end
