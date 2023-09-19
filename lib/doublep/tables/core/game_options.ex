defmodule Doublep.Tables.Core.GameOptions do
  alias Doublep.Tables.Core.VotingLayout

  @default_voting_layout %VotingLayout{
    name: :fibonacci,
    title: "Fibonacci (1-13)",
    values: ["1", "2", "3", "5", "8", "13"]
  }

  defstruct moderation_mode: :auto,
            voting_layout: @default_voting_layout

  def new(fields \\ []) do
    voting_layout = Keyword.get(fields, :voting_layout, @default_voting_layout)
    moderation_mode = Keyword.get(fields, :moderation_mode, :auto)

    fields =
      fields
      |> Keyword.put(:voting_layout, voting_layout)
      |> Keyword.put(:moderation_mode, moderation_mode)

    struct!(__MODULE__, fields)
  end
end
