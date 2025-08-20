defmodule SyncTest.SyncTest.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:pub_key, :binary, autogenerate: false}
  @foreign_key_type :binary
  schema "users" do
    field :name, :string
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:pub_key, :name])
    |> validate_required([:pub_key, :name])
    |> unique_constraint(:pub_key)
  end
end
