defmodule SyncTest.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :pub_key, :binary, primary_key: true
      add :name, :string
    end
  end
end
