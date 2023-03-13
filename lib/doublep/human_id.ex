defmodule Doublep.HumanId do
  alias Doublep.WordGen

  def new(opts \\ []) do
    separator = Keyword.get(opts, :separator, "-")
    words = WordGen.gen(separator: separator)

    [
      words,
      Enum.random(100..999)
    ]
    |> Enum.join(separator)
  end
end
