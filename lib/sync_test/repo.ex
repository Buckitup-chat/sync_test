defmodule SyncTest.Repo do
  use Ecto.Repo,
    otp_app: :sync_test,
    adapter: Ecto.Adapters.Postgres
end
