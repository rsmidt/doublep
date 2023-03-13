defmodule Doublep.WordGenTest do
  use Doublep.DataCase

  alias Doublep.WordGen

  describe "returns word with default separator" do
    assert length(String.split(WordGen.gen())) == 3
  end

  describe "returns word with overwrite separator" do
    assert length(String.split(WordGen.gen())) == 3
    assert length(String.split(WordGen.gen(separator: "-"), "-")) == 3
  end
end
