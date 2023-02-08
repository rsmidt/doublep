defmodule Doublep.Tables.Server do
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
    {:ok,
     %{
       table: table,
       dealer: nil,
       active_players: %{},
       current_votes: %{},
       past_votes: [],
       state: :picking
     }}
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

  def handle_call(:get_state, _, state) do
    {:reply, get_state_projection(state), state}
  end

  def handle_call({:join_table, role, name, pid}, _, state) do
    handle_join({role, name, pid}, state)
  end

  def handle_call({:register_pick, picker_pid, card}, _, %{table: table} = state) do
    with {:ok, player} <- find_player(state, picker_pid),
         :ok <- voting_enabled?(state) do
      PubSub.broadcast!(Doublep.PubSub, topic(table.id), {:player_picked, player, card})
      {:reply, :ok, put_in(state, [:current_votes, picker_pid], card)}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call(:reveal, _, %{table: table} = state) do
    with :ok <- state_allowed?(state, :revealing) do
      next_state = Map.put(state, :state, :revealing)

      PubSub.broadcast!(
        Doublep.PubSub,
        topic(table.id),
        {:cards_revealed, get_state_projection(next_state)}
      )

      {:reply, :ok, next_state}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call(:next_hand, _, %{table: table} = state) do
    with :ok <- state_allowed?(state, :picking) do
      next_state = prepare_next_hand(state)

      PubSub.broadcast!(
        Doublep.PubSub,
        topic(table.id),
        {:next_hand_dealt, get_state_projection(next_state)}
      )

      {:reply, :ok, next_state}
    else
      error -> {:reply, error, state}
    end
  end

  defp get_state_projection(state) do
    %{past_votes: past_votes, current_votes: current_votes, state: current_state} = state

    %{
      active_players: list_players(state),
      past_votes: past_votes,
      current_votes: current_votes,
      current_state: current_state
    }
  end

  defp prepare_next_hand(%{current_votes: current_votes, past_votes: past_votes} = state) do
    state
    |> Map.put(:past_votes, [current_votes | past_votes])
    |> Map.put(:current_votes, %{})
    |> Map.put(:state, :picking)
  end

  defp state_allowed?(%{state: :picking}, :revealing), do: :ok
  defp state_allowed?(%{state: :picking}, :picking), do: :ok
  defp state_allowed?(%{state: :revealing}, :picking), do: :ok
  defp state_allowed?(_, next_state), do: {:error, {:state_not_allowed, next_state}}

  defp voting_enabled?(%{state: :picking}), do: :ok
  defp voting_enabled?(%{state: :revealing}), do: :ok
  defp voting_enabled?(_), do: {:error, :picking_not_allowed}

  defp find_player(%{active_players: players}, player_pid) do
    case Map.get(players, player_pid) do
      nil -> {:error, :not_participating}
      player -> {:ok, player}
    end
  end

  defp list_players(%{dealer: nil, active_players: active_players}) do
    active_players
  end

  defp list_players(%{dealer: dealer, active_players: active_players}) do
    Map.put(active_players, dealer.pid, dealer)
  end

  defp handle_join({:dealer, name, pid}, %{dealer: nil} = state) do
    Process.monitor(pid)

    player = %{role: :dealer, name: name, pid: pid}

    PubSub.broadcast!(
      Doublep.PubSub,
      topic(state.table.id),
      {:player_joined, player}
    )

    {:reply, :ok, Map.put(state, :dealer, player)}
  end

  defp handle_join({:player, name, pid}, state) do
    Process.monitor(pid)

    player = %{role: :player, name: name, pid: pid}

    PubSub.broadcast!(
      Doublep.PubSub,
      topic(state.table.id),
      {:player_joined, player}
    )

    {:reply, :ok, put_in(state, [:active_players, pid], player)}
  end

  defp handle_join(_, state) do
    {:reply, {:error, :role_already_occupied}, state}
  end

  def handle_info({:DOWN, _ref, :process, object, _reason}, state) do
    handle_leave(object, state)
  end

  defp handle_leave(left_pid, %{table: table, dealer: %{pid: pid} = dealer} = state)
       when left_pid == pid do
    PubSub.broadcast!(Doublep.PubSub, topic(table.id), {:dealer_left, dealer})

    state
    |> Map.put(:dealer, nil)
    |> shutdown_if_empty()
  end

  defp handle_leave(left_pid, %{table: table, active_players: players} = state) do
    case Map.get(players, left_pid) do
      nil ->
        {:noreply, state}

      player ->
        PubSub.broadcast!(Doublep.PubSub, topic(table.id), {:player_left, player})

        state
        |> Map.put(:active_players, remove_player(players, left_pid))
        |> shutdown_if_empty()
    end
  end

  defp shutdown_if_empty(%{active_players: players, dealer: nil} = state)
       when map_size(players) == 0 do
    Logger.info("Shutting down Server because all players left")
    {:stop, :shutdown, state}
  end

  defp shutdown_if_empty(state) do
    {:noreply, state}
  end

  defp remove_player(players, pid) do
    Map.delete(players, pid)
  end

  defp topic(table_id), do: Doublep.Tables.table_topic(table_id)
end
