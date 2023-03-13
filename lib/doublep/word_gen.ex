defmodule Doublep.WordGen do
  # Words taking from https://github.com/glitchdotcom/friendly-words/tree/main.
  # Licensed under MIT.
  @external_resource coll_file = "./lib/doublep/word_gen/collections.txt"
  @external_resource obj_file = "./lib/doublep/word_gen/objects.txt"
  @external_resource pre_file = "./lib/doublep/word_gen/predicates.txt"

  coll_words =
    coll_file
    |> File.stream!()
    |> Enum.map(&String.trim/1)
    |> Enum.to_list()

  obj_words =
    obj_file
    |> File.stream!()
    |> Enum.map(&String.trim/1)
    |> Enum.to_list()

  pre_words =
    pre_file
    |> File.stream!()
    |> Enum.map(&String.trim/1)
    |> Enum.to_list()

  @default_separator " "

  defp collections() do
    unquote(coll_words)
  end

  defp objects() do
    unquote(obj_words)
  end

  defp predicates() do
    unquote(pre_words)
  end

  def gen(opts \\ []) do
    sep = Keyword.get(opts, :separator, @default_separator)

    [
      Enum.random(predicates()),
      Enum.random(objects()),
      Enum.random(collections())
    ]
    |> Enum.join(sep)
  end
end
