ExUnit.start()

# Only use sandbox in test environment
if Mix.env() == :test do
  Ecto.Adapters.SQL.Sandbox.mode(SyncTest.Repo, :manual)
end
