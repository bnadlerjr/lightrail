defmodule Lightrail.Publisher.Telemetry do
  @moduledoc """
  [Telemetry][1] events for Publishers.

  [1]: https://github.com/beam-telemetry/telemetry
  """

  @doc """
  Dispatched by `Lightrail.Publisher` when a message is successfully published.

  - Measurement: `%{system_time: integer}`
  - Metadata: `%{module: term, exchange: term, type: term}`

  """
  def emit_publish_success(module, exchange, type) do
    event = [:lightrail, :publisher, :publish, :success]
    measurements = %{system_time: System.system_time()}
    metadata = %{module: module, exchange: exchange, type: type}
    :telemetry.execute(event, measurements, metadata)
  end

  @doc """
  Dispatched by `Lightrail.Publisher` when a message fails to be published.

  - Measurement: `%{system_time: integer}`
  - Metadata: `%{module: term, reason: term}`

  """
  def emit_publish_failure(module, reason) do
    event = [:lightrail, :publisher, :publish, :failure]
    measurements = %{system_time: System.system_time()}
    metadata = %{module: module, reason: reason}
    :telemetry.execute(event, measurements, metadata)
  end

  @doc """
  Dispatched by `Lightrail.Publisher.Server` when a Publisher is shut down.

  - Measurement: `%{system_time: integer}`
  - Metadata: `%{module: term, reason: atom}`

  """
  def emit_publisher_down(module, reason) do
    event = [:lightrail, :publisher, :down]
    measurements = %{system_time: System.system_time()}
    metadata = %{module: module, reason: reason}
    :telemetry.execute(event, measurements, metadata)
  end
end
