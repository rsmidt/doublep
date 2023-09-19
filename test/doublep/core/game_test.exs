defmodule Doublep.Core.GameTest do
  use ExUnit.Case

  alias Doublep.Tables.Core.Player
  alias Doublep.Tables.Core.Game
  alias Doublep.Tables.Table
  alias Doublep.Tables.Core.GameOptions

  describe "join_player/4" do
    test "can only join if role is allowed" do
      roles = [
        [:auto, :dealer, {:error, :role_not_allowed}],
        [:auto, :player, :ok],
        [:moderated, :dealer, :ok],
        [:moderated, :player, :ok]
      ]

      for [mode, role, response] <- roles do
        game = Game.new(%Table{}, GameOptions.new(moderation_mode: mode))

        if response == :ok do
          assert {:ok, _} = Game.join_player(game, role, "foo", self())
        else
          assert ^response = Game.join_player(game, role, "foo", self())
        end
      end
    end

    test "can only join as dealer if not taken" do
      game =
        Game.new(%Table{}, GameOptions.new(moderation_mode: :moderated))
        |> Game.join_player!(:dealer, "dealer", :c.pid(0, 0, 1))

      assert {:error, :role_taken} =
               Game.join_player(game, :dealer, "another_dealer", :c.pid(0, 0, 2))
    end

    test "will override if joining twice" do
      pid = :c.pid(0, 0, 1)

      {:ok, game} =
        Game.new(%Table{}, GameOptions.new(moderation_mode: :moderated))
        |> Game.join_player(:dealer, "dealer", pid)

      assert {:ok, game} =
               Game.join_player(game, :player, "another dealer", pid)

      assert game.players[pid] == %Player{name: "another dealer", role: :player, pid: pid}
    end
  end

  describe "reveal/1" do
    test "will only reveal if state is voting" do
      game = Game.new(%Table{}, GameOptions.new(moderation_mode: :auto))

      assert {:ok, revealed_game} = Game.reveal(game)
      assert revealed_game.state == :revealing
    end
  end

  describe "register_vote/3" do
    test "allows voting when in voting state" do
      game =
        Game.new(%Table{}, GameOptions.new(moderation_mode: :auto))
        |> Game.join_player!(:player, "player", self())

      assert {:ok, voted_game} = Game.register_vote(game, self(), "1")
      assert voted_game.current_votes[self()] == "1"
    end

    test "allows voting when in revealed state" do
      game =
        Game.new(%Table{}, GameOptions.new(moderation_mode: :auto))
        |> Game.join_player!(:player, "player", self())
        |> Game.reveal!()

      assert {:ok, voted_game} = Game.register_vote(game, self(), "1")
      assert voted_game.current_votes[self()] == "1"
    end

    test "fails if user not found" do
      game = Game.new(%Table{}, GameOptions.new(moderation_mode: :auto))

      assert {:error, :not_participating} = Game.register_vote(game, self(), "1")
    end

    test "fails if user is dealer" do
      game =
        Game.new(%Table{}, GameOptions.new(moderation_mode: :moderated))
        |> Game.join_player!(:dealer, "dealer", self())

      assert {:error, :role_forbids_voting} = Game.register_vote(game, self(), "1")
    end
  end

  describe "next_hand/1" do
    test "fails if not in voting state" do
      game =
        Game.new(%Table{}, GameOptions.new(moderation_mode: :auto))

      assert {:error, {:state_not_allowed, :voting}} = Game.next_hand(game)
    end

    test "adds to history if successfull" do
      game =
        Game.new(%Table{}, GameOptions.new(moderation_mode: :auto))
        |> Game.join_player!(:player, "player", self())
        |> Game.register_vote!(self(), "1")
        |> Game.reveal!()

      assert {:ok, next_game} = Game.next_hand(game)
      assert next_game.state == :voting
      assert next_game.past_votes == [game.current_votes]
      assert next_game.current_votes == %{}
    end
  end
end
