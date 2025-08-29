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
    decoded_attrs = decode_hex(attrs, "pub_key")

    user
    |> cast(decoded_attrs, [:pub_key, :name])
    |> validate_required([:pub_key, :name])
    |> unique_constraint(:pub_key)
  end

  def decode_hex(attrs, field) do
    case attrs do
      %{^field => "0x" <> hex} -> Map.put(attrs, field, hex |> Base.decode16!(case: :mixed))
      %{^field => "\\x" <> hex} -> Map.put(attrs, field, hex |> Base.decode16!(case: :mixed))
      _ -> attrs
    end
  end
end
