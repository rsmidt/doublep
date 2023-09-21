defmodule Doublep.EmojiGen do
  @external_resource emoji_file = "./lib/doublep/emoji_gen/emoji_df.csv"

  emojis =
    emoji_file
    |> File.stream!()
    |> Enum.drop(1)

  def emojis() do
      unquote(emojis)
  end
end
