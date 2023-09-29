defmodule Doublep.Tables.Server do
  alias Doublep.Tables.Core.GameOptions
  alias Doublep.Tables.Core.Game
  alias Doublep.Tables.Core.Player
  alias Phoenix.PubSub
  alias Doublep.Tables.Table
  use GenServer, restart: :temporary
  require Logger

  # Client API

  def via(id) when is_binary(id) do
    {:via, Registry, {Doublep.Registry.Tables, id}}
  end

  def start_link(%Table{id: id} = table) do
    GenServer.start_link(
      __MODULE__,
      table,
      name: via(id)
    )
  end

  def init(%Table{} = table) do
    {:ok, Game.new(table, GameOptions.new())}
  end

  def open_table(%Table{} = table) do
    DynamicSupervisor.start_child(Doublep.Supervisor.Tables, {__MODULE__, table})
  end

  def ensure_initialized(%Table{} = table) do
    case open_table(table) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
  end

  def join_table(id, {role, name, pid}) do
    GenServer.call(via(id), {:join_table, role, name, pid})
  end

  def get_state(id) do
    GenServer.call(via(id), :get_state)
  end

  def register_pick(id, picker_pid, card) do
    GenServer.call(via(id), {:register_pick, picker_pid, card})
  end

  def reveal(id) do
    GenServer.call(via(id), :reveal)
  end

  def next_hand(id) do
    GenServer.call(via(id), :next_hand)
  end

  # Server API

  def handle_call(:get_state, _, %Game{} = state) do
    {:reply, state, state}
  end

  def handle_call({:join_table, role, name, pid}, _, %Game{} = state) do
    case Game.join_player(state, role, name, pid) do
      {:ok, next_state} ->
        Process.monitor(pid)

        broadcast!(next_state, {:player_joined, next_state.players[pid]})

        {:reply, :ok, next_state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:register_pick, picker_pid, card}, _, %Game{} = state) do
    case Game.register_vote(state, picker_pid, card) do
      {:ok, next_state} ->
        broadcast!(next_state, {:player_picked, next_state.players[picker_pid], card})

        next_state
        |> cancel_auto_reveal_timer()
        |> maybe_set_auto_timer()

      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:reveal, _, %Game{} = state) do
    case Game.reveal(state) do
      {:ok, next_state} ->
        broadcast!(next_state, {:cards_revealed, next_state})
        {:reply, :ok, next_state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:next_hand, _, %Game{} = state) do
    case Game.next_hand(state) do
      {:ok, next_state} ->
        broadcast!(next_state, {:next_hand_dealt, next_state})
        {:reply, :ok, next_state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, object, _reason}, state) do
    handle_leave(object, state)
  end

  def handle_info(:auto_reveal_timer, %Game{} = state) do
    case Game.reveal(state) do
      {:ok, next_state} ->
        broadcast!(next_state, {:cards_revealed, next_state})
        {:noreply, next_state}

      error ->
        {:noreply, error, state}
    end
  end

  defp cancel_auto_reveal_timer(%Game{} = state) do
    %Game{auto_reveal_timer_ref: timer_ref} = state

    if timer_ref != nil do
      Process.cancel_timer(timer_ref)
      struct!(state, auto_reveal_timer_ref: nil)
    else
      state
    end
  end

  defp maybe_set_auto_timer(%Game{options: options} = state) do
    with :auto <- options.moderation_mode,
         :voting <- state.state,
         true <- Game.all_voted?(state) do
      broadcast!(state, {:auto_reveal_timer_set, 5000})

      pid = Process.send_after(self(), :auto_reveal_timer, 5000)
      {:reply, :ok, struct!(state, auto_reveal_timer_ref: pid)}
    else
      _ ->
        {:reply, :ok, state}
    end
  end

  defp handle_leave(left_pid, state) do
    %Game{players: players, table: table} = state

    with %Player{} = player <- Map.get(players, left_pid),
         {:ok, next_state} <- Game.remove_player(state, left_pid) do
      broadcast_player_left!(next_state, player)
      maybe_shutdown(next_state)
    else
      nil ->
        {:noreply, state}

      error ->
        {:reply, error, state}
    end
  end

  defp broadcast_player_left!(%Game{} = state, %Player{role: :dealer} = player) do
    broadcast!(state, {:dealer_left, player})
  end

  defp broadcast_player_left!(%Game{} = state, %Player{role: :player} = player) do
    broadcast!(state, {:player_left, player})
  end

  defp maybe_shutdown(%Game{players: players} = state) when map_size(players) == 0 do
    {:stop, :shutdown, state}
  end

  defp maybe_shutdown(%Game{} = state) do
    {:noreply, state}
  end

  defp broadcast!(%Game{table: table}, message) do
    PubSub.broadcast!(Doublep.PubSub, topic(table.id), message)
  end

  defp topic(table_id), do: Doublep.Tables.table_topic(table_id)
end
