defmodule Test.Support.Publisher do
  @moduledoc false
  @behaviour Lightrail.Publisher

  def start_link() do
    Lightrail.Publisher.start_link(__MODULE__, name: __MODULE__)
  end

  def publish_message(message) do
    Lightrail.Publisher.publish(__MODULE__, message)
  end

  @impl Lightrail.Publisher
  def init() do
    [
      exchange: "lightrail:test"
    ]
  end
end
