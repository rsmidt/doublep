defmodule Doublep.Tables.Table do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tables" do
    field :name, :string
    field :slug, :string

    timestamps()
  end

  @doc false
  def changeset(table, attrs) do
    table
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:slug)
  end

  def join_changeset(table, attrs) do
    table
    |> cast(attrs, [:id])
    |> validate_required([:id])
  end
end
