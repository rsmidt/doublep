defmodule Doublep.Tables do
  @moduledoc """
  The Tables context.
  """

  import Ecto.Query, warn: false
  alias Doublep.Tables.Server
  alias Ecto.UUID
  alias Doublep.Repo

  alias Doublep.Tables.Table

  def get_table_by_slug(slug) do
    Repo.get_by(Table, slug: slug)
  end

  def get_table_state(%Table{id: id} = table) do
    :ok = Server.ensure_initialized(table)
    Server.get_state(id)
  end

  def register_pick(table_id, picker_pid, card) do
    Server.register_pick(table_id, picker_pid, card)
  end

  def join_table(table_id, {role, pid}) do
    Server.join_table(table_id, {role, "anon", pid})
  end

  def reveal(table_id) do
    Server.reveal(table_id)
  end

  def next_hand(table_id) do
    Server.next_hand(table_id)
  end

  def table_topic(), do: "tables"
  def table_topic(table_id) when is_binary(table_id), do: table_topic() <> ":#{table_id}"

  @doc """
  Creates a table.

  ## Examples

      iex> create_table(%{field: value})
      {:ok, %Table{}}

      iex> create_table(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_table(attrs \\ %{}) do
    id = UUID.generate()

    result =
      %Table{
        id: id,
        slug: id
      }
      |> Table.changeset(attrs)
      |> Repo.insert()

    with {:ok, table} <- result,
         {:ok, _} <- Server.open_table(table) do
      {:ok, table}
    end
  end

  def can_enter?(%{"id" => id} = attrs) do
    case get_table_by_slug(id) do
      nil ->
        changeset =
          %Table{}
          |> change_table_join(attrs)
          |> Ecto.Changeset.add_error(:id, "Table not found")
          |> Map.put(:action, :validate)

        {:error, changeset}

      table ->
        {:ok, table}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking table changes.

  ## Examples

      iex> change_table(table)
      %Ecto.Changeset{data: %Table{}}

  """
  def change_table(%Table{} = table, attrs \\ %{}) do
    Table.changeset(table, attrs)
  end

  def change_table_join(%Table{} = table, attrs \\ %{}) do
    Table.join_changeset(table, attrs)
  end
end
