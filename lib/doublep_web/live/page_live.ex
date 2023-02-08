defmodule DoublepWeb.PageLive do
  alias Doublep.Tables
  use DoublepWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.button phx-click="create_random">Create Random</.button>
    """
  end

  @impl true
  def handle_event("create_random", _params, socket) do
    {:ok, table} = Tables.create_random_table()
    {:noreply, push_navigate(socket, to: ~p"/tables/#{table.id}")}
  end
end
