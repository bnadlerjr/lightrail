defmodule Test.Support.Consumer do
  @moduledoc false
  @behaviour Lightrail.Consumer

  def start_link() do
    Lightrail.Consumer.start_link(__MODULE__, name: __MODULE__)
  end

  @impl Lightrail.Consumer
  def init() do
    [
      queue: "lightrail:test:events",
      exchange: "lightrail:test"
    ]
  end

  @impl Lightrail.Consumer
  def handle_message(message) do
    IO.puts("Handled message: #{inspect(message)}")
  end
end
