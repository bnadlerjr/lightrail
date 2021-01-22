defmodule Test.Support.Repo do
  use Ecto.Repo,
    otp_app: :lightrail,
    adapter: Ecto.Adapters.Postgres
end
