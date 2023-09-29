defmodule DoublepWeb.TableLive.Show do
  alias Doublep.Tables.Core.Game
  use DoublepWeb, :live_view

  alias Ecto.Changeset
  alias Phoenix.PubSub
  alias Doublep.Tables
  alias Doublep.Tables.Table
  alias Doublep.EmojiGen

  @cards [1, 2, 3, 5, 8, 13]

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    socket =
      socket
      |> assign_default()
      |> assign_table(slug)

    if connected?(socket),
      do: PubSub.subscribe(Doublep.PubSub, Tables.table_topic(socket.assigns.table.id))

    handle_participation(socket.assigns.table, socket)
  end

  @impl true
  def handle_params(_params, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action, socket.assigns))}
  end

  @impl true
  def handle_event("join_dealer", _, socket) do
    handle_join(:dealer, socket)
  end

  @impl true
  def handle_event("join_player", _, socket) do
    handle_join(:player, socket)
  end

  @impl true
  def handle_event("pick", %{"card" => card}, %{assigns: assigns} = socket) do
    %{table: %Table{id: id}} = assigns

    :ok = Tables.register_pick(id, self(), card)

    socket =
      socket
      |> assign(:own_pick, card)

    {:noreply, socket}
  end

  @impl true
  def handle_event("reveal", _, %{assigns: assigns} = socket) do
    %{table: %Table{id: id}} = assigns

    :ok = Tables.reveal(id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("next_hand", _, %{assigns: assigns} = socket) do
    %{table: %Table{id: id}} = assigns

    :ok = Tables.next_hand(id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_nick", %{"participant" => participant_params}, socket) do
    changeset =
      %{}
      |> Tables.change_participant_join(participant_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :participant_changeset, changeset)}
  end

  @impl true
  def handle_info({:player_joined, player}, socket) do
    socket =
      socket
      |> assign_joined_player(player)
      |> maybe_announce_new_joiner(player)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:player_picked, player, card}, socket) do
    socket =
      socket
      |> assign_pick(player, card)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:player_left, player}, socket) do
    handle_player_left(player, socket)
  end

  @impl true
  def handle_info({:dealer_left, dealer}, socket) do
    handle_player_left(dealer, socket)
  end

  @impl true
  def handle_info({:cards_revealed, new_state}, socket) do
    socket =
      socket
      |> assign_new_state(new_state)
      |> maybe_assign_firework()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:next_hand_dealt, new_state}, socket) do
    {:noreply,
     socket
     |> assign(:own_pick, nil)
     |> assign_new_state(new_state)}
  end

  @impl true
  def handle_info(:hide_firework, socket) do
    socket =
      socket
      |> assign(:show_firework, false)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:auto_reveal_timer_set, duration}, socket) do
    socket =
      socket
      |> push_event("auto-reveal-timer-started", %{"duration" => duration})

    {:noreply, socket}
  end

  defp handle_player_left(%{pid: pid}, socket) do
    %{assigns: %{active_players: active_players}} = socket
    {:noreply, socket |> assign(:active_players, Map.delete(active_players, pid))}
  end

  defp maybe_announce_new_joiner(socket, %{pid: pid, name: name, role: :dealer})
       when self() != pid do
    socket
    |> put_flash(:info, "Hoora! #{name} is your new dealer.")
  end

  defp maybe_announce_new_joiner(socket, _) do
    socket
  end

  defp handle_join(role, %{assigns: assigns} = socket) do
    %{table: table, participant_changeset: participant_changeset} = assigns

    with {:ok, %{nickname: nickname}} <- apply_participant(participant_changeset),
         :ok <- Tables.join_table(table.id, {role, nickname, self()}) do
      {:noreply,
       socket
       |> assign(:own_role, role)
       |> push_patch(to: ~p"/tables/#{table.slug}")}
    else
      {:error, :role_already_occupied} ->
        {:noreply,
         socket
         |> put_flash(:error, "Role already occupied")
         |> push_navigate(to: ~p"/tables/#{table.slug}/join")}

      {:error, %Changeset{} = changeset} ->
        {:noreply, socket |> assign(:participant_changeset, changeset)}

      _error ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to join table")
         |> push_navigate(to: ~p"/")}
    end
  end

  defp apply_participant(%Changeset{} = changeset) do
    changeset
    |> Changeset.apply_action(:validate)
  end

  defp page_title(:show, %{table: table}), do: table.name
  defp page_title(:join, %{table: table}), do: "Join - #{table.name}"

  defp handle_participation(nil, socket) do
    {:ok, socket |> put_flash(:error, "Table not found :(") |> push_navigate(to: ~p"/")}
  end

  defp handle_participation(%Table{} = table, socket) do
    socket =
      socket
      |> get_and_assign_state(table)
      |> maybe_redirect(socket.assigns.live_action)

    {:ok, socket}
  end

  defp maybe_redirect(socket, :show) do
    unless already_participating?(self(), socket) do
      socket |> push_navigate(to: ~p"/tables/#{socket.assigns.table.slug}/join")
    else
      socket
    end
  end

  defp maybe_redirect(socket, :join) do
    socket
  end

  defp already_participating?(test_pid, %{assigns: %{active_players: players}}),
    do: Enum.any?(players, fn {pid, _} -> test_pid == pid end)

  defp assign_default(socket) do
    socket
    |> assign_new(:participant_changeset, fn -> Tables.change_participant_join(%{nickname: random_emoji()}) end)
    |> assign(:active_players, %{})
    |> assign(:cards, @cards)
    |> assign(:own_pick, nil)
    |> assign(:show_firework, false)
  end

  defp random_emoji() do
    EmojiGen.emojis()
    |> Enum.random()
    |> String.split(",")
    |> hd()
  end

  defp assign_table(socket, slug) do
    socket
    |> assign_new(:table, fn -> Tables.get_table_by_slug(slug) end)
  end

  defp get_and_assign_state(socket, %Table{} = table) do
    socket
    |> assign_new_state(Tables.get_table_state(table))
  end

  defp assign_new_state(socket, %Game{} = new_state) do
    %Game{players: players, current_votes: current_votes, state: current_state, options: options} =
      new_state

    %{
      active_players: players,
      current_votes: current_votes,
      current_state: current_state,
      options: options
    }
    |> Enum.reduce(socket, fn {key, value}, socket -> assign(socket, key, value) end)
  end

  defp assign_joined_player(socket, player) do
    socket
    |> assign(:active_players, Map.put(socket.assigns.active_players, player.pid, player))
  end

  defp assign_pick(socket, %{pid: pid}, card) do
    socket
    |> assign(:current_votes, Map.put(socket.assigns.current_votes, pid, card))
  end

  defp maybe_assign_firework(%{assigns: %{current_votes: current_votes}} = socket) do
    if all_votes_equal?(Map.values(current_votes)) do
      Process.send_after(self(), :hide_firework, 10000)
      socket |> assign(:show_firework, true)
    else
      socket
    end
  end

  defp role_available?(:dealer, current_players) when is_map(current_players) do
    current_players
    |> Enum.all?(fn {_, %{role: role}} -> role != :dealer end)
  end

  defp role_available?(:player, current_players) when is_map(current_players) do
    true
  end

  defp filter_players(players),
    do: Enum.filter(players, fn {_, %{role: role}} -> role == :player end) |> Map.new()

  defp all_votes_equal?([first | [_ | _] = rest]) do
    Enum.all?(rest, fn vote -> first == vote end)
  end

  defp all_votes_equal?([_ | _]), do: false

  defp all_votes_equal?([]), do: false
end
