defmodule Lightrail.Telemetry do
  @moduledoc """
  Shared helpers for emitting telemetry information. Acts as a wrapper
  for the [Telemetry][1] library.

  [1]: https://github.com/beam-telemetry/telemetry
  """

  @doc """
  Emit telemetry information. Automatically adds additional measurement
  information common to all requests (such as system time).

  """
  def emit(event, metadata) do
    emit(event, %{}, metadata)
  end

  def emit(event, measurements, metadata) do
    additional = %{system_time: System.system_time()}
    :telemetry.execute(event, Map.merge(measurements, additional), metadata)
  end
end
