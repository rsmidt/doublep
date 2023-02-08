defmodule Doublep.TablesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Doublep.Tables` context.
  """

  @doc """
  Generate a unique table slug.
  """
  def unique_table_slug, do: "some slug#{System.unique_integer([:positive])}"

  @doc """
  Generate a table.
  """
  def table_fixture(attrs \\ %{}) do
    {:ok, table} =
      attrs
      |> Enum.into(%{
        name: "some name",
        slug: unique_table_slug()
      })
      |> Doublep.Tables.create_table()

    table
  end
end
