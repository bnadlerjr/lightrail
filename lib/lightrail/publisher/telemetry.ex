defmodule Lightrail.Publisher.Telemetry do
  @moduledoc """
  [Telemetry][1] events for Publishers.

  [1]: https://github.com/beam-telemetry/telemetry
  """

  alias Lightrail.Telemetry

  @doc """
  Dispatched by `Lightrail.Publisher` when a message is successfully published.

  - Measurement: `%{system_time: integer}`
  - Metadata: `%{module: term, exchange: term, type: term}`

  """
  def emit_publish_success(module, exchange, type) do
    event = [:lightrail, :publisher, :publish, :success]
    metadata = %{module: module, exchange: exchange, type: type}
    Telemetry.emit(event, metadata)
  end

  @doc """
  Dispatched by `Lightrail.Publisher` when a message fails to be published.

  - Measurement: `%{system_time: integer}`
  - Metadata: `%{module: term, reason: term}`

  """
  def emit_publish_failure(module, reason) do
    event = [:lightrail, :publisher, :publish, :failure]
    metadata = %{module: module, reason: reason}
    Telemetry.emit(event, metadata)
  end

  @doc """
  Dispatched by `Lightrail.Publisher.Server` when a Publisher is shut down.

  - Measurement: `%{system_time: integer}`
  - Metadata: `%{module: term, reason: atom}`

  """
  def emit_publisher_down(module, reason) do
    event = [:lightrail, :publisher, :down]
    metadata = %{module: module, reason: reason}
    Telemetry.emit(event, metadata)
  end
end
