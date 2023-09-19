defmodule Doublep.Tables.Core.Game do
  alias Doublep.Tables.Core.Player
  alias Doublep.Tables.Core.GameOptions
  alias Doublep.Tables.Table

  alias __MODULE__

  defstruct table: nil,
            players: %{},
            state: :voting,
            options: %GameOptions{},
            current_votes: %{},
            past_votes: [],
            auto_reveal_timer_ref: nil


  def new(%Table{} = table, %GameOptions{} = options) do
    %Game{
      table: table,
      options: options
    }
  end

  def join_player(%Game{options: options} = game, role, name, pid) do
    %GameOptions{moderation_mode: mod_mode} = options

    with :ok <- role_allowed?(game, mod_mode, role) do
      player = %Player{role: role, name: name, pid: pid}
      {:ok, put_in(game.players[pid], player)}
    end
  end

  def join_player!(%Game{} = game, role, name, pid) do
    case join_player(game, role, name, pid) do
      {:ok, game} -> game
      _ -> raise "failed to join player"
    end
  end

  def remove_player(%Game{} = game, pid) do
    {_, new_game} = pop_in(game.players[pid])
    {:ok, new_game}
  end

  def remove_player!(%Game{} = game, pid) do
    case remove_player(game, pid) do
      {:ok, game} -> game
      _ -> raise "failed to remove player"
    end
  end

  def reveal(%Game{} = game) do
    with :ok <- state_allowed?(game, :revealing) do
      {:ok, struct!(game, state: :revealing)}
    end
  end

  def reveal!(%Game{} = game) do
    case reveal(game) do
      {:ok, game} -> game
      _ -> raise "failed to reveal hand"
    end
  end

  def register_vote(%Game{} = game, player_pid, vote) do
    with {:ok, player} <- find_player(game, player_pid),
         :ok <- voting_enabled?(game),
         :ok <- voting_allowed?(player) do
      {:ok, put_in(game.current_votes[player_pid], vote)}
    end
  end

  def register_vote!(%Game{} = game, player_pid, vote) do
    case register_vote(game, player_pid, vote) do
      {:ok, game} -> game
      _ -> raise "failed to register vote"
    end
  end

  def next_hand(%Game{} = game) do
    with :ok <- state_allowed?(game, :voting) do
      new_game = prepare_next_hand(game)
      {:ok, new_game}
    end
  end

  def next_hand!(%Game{} = game) do
    case next_hand(game) do
      {:ok, game} -> game
      _ -> raise "failed to deal next hand"
    end
  end

  def all_voted?(%Game{} = game) do
    %Game{players: players, current_votes: current_votes} = game

    vote_eligable_players = Enum.filter(players, fn {_pid, player} -> player.role == :player end)
    map_size(current_votes) == length(vote_eligable_players)
  end

  defp prepare_next_hand(%Game{current_votes: current_votes, past_votes: past_votes} = game) do
    game
    |> struct!(past_votes: [current_votes | past_votes])
    |> struct!(current_votes: %{})
    |> struct!(state: :voting)
    |> struct!(auto_reveal_timer_ref: nil)
  end

  defp find_player(%Game{players: players}, player_pid) do
    case Map.get(players, player_pid) do
      nil -> {:error, :not_participating}
      player -> {:ok, player}
    end
  end

  defp state_allowed?(%Game{state: :voting}, :revealing), do: :ok
  defp state_allowed?(%Game{state: :revealing}, :voting), do: :ok
  defp state_allowed?(_, next_state), do: {:error, {:state_not_allowed, next_state}}

  defp voting_enabled?(%Game{state: :voting}), do: :ok
  defp voting_enabled?(%Game{state: :revealing}), do: :ok
  defp voting_enabled?(_), do: {:error, :voting_not_allowed}

  defp role_allowed?(_, :auto, :dealer), do: {:error, :role_not_allowed}
  defp role_allowed?(_, _, :player), do: :ok

  defp role_allowed?(%Game{players: players}, :moderated, :dealer) do
    dealer_taken =
      players
      |> Map.values()
      |> Enum.any?(fn %Player{role: role} -> role == :dealer end)

    if dealer_taken do
      {:error, :role_taken}
    else
      :ok
    end
  end

  defp voting_allowed?(%Player{role: :player}), do: :ok
  defp voting_allowed?(_), do: {:error, :role_forbids_voting}
end
