
defmodule SyncTestWeb.IngestController do
  use SyncTestWeb, :controller

  alias Phoenix.Sync.Writer
  alias Writer.Format

  alias SyncTest.Repo

  def ingest(conn, %{"mutations" => mutations}) do
    mutations |> dbg()
    {:ok, txid, _changes} =
      Writer.new()
      |> Writer.allow(
        SyncTest.SyncTest.User
        # accept: [:insert], 
        # check: &Ingest.check_event(&1, user)
      )
      |> Writer.apply(mutations, Repo, format: Format.TanstackDB)

    json(conn, %{txid: Integer.to_string(txid)})
  end
end
