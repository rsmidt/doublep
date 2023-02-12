defmodule DoublepWeb.PageLive do
  alias Doublep.Tables
  alias Doublep.Tables.Table
  use DoublepWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:table_changeset, Tables.change_table(%Table{}))
      |> assign(:enter_changeset, Tables.change_table_join(%Table{}))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex justify-center mt-10">
      <div>
        <h1 class="text-4xl">Welcome to DoubleP Planning Poker.</h1>
        <div class="mt-2 flex justify-evenly">
          <div>
            <p class="text-lg font-semibold">Create your own table:</p>
            <.form
              :let={f}
              class="mt-1"
              for={@table_changeset}
              phx-change="validate"
              phx-submit="create"
            >
              <.input field={{f, :name}} type="text" label="Table name" phx-debounce="500" />
              <.button class="mt-2" phx-disable-with="Creating ...">Create</.button>
            </.form>
          </div>
          <div>
            <p class="text-lg font-semibold">Or enter an existing one:</p>
            <.form
              :let={f}
              class="mt-1"
              for={@enter_changeset}
              phx-change="validate_enter"
              phx-submit="enter"
            >
              <.input field={{f, :id}} type="text" label="Table id" phx-debounce="500" />
              <.button class="mt-2" phx-disable-with="Joining ...">Enter</.button>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("create", %{"table" => table_params}, socket) do
    case Tables.create_table(table_params) do
      {:ok, table} ->
        {:noreply,
         socket
         |> put_flash(:info, "Table created successfully")
         |> push_navigate(to: ~p"/tables/#{table.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        dbg(changeset)
        {:noreply, assign(socket, table_changeset: changeset)}
    end
  end

  @impl true
  def handle_event("enter", %{"table" => table_params}, socket) do
    case Tables.can_enter?(table_params) do
      {:ok, table} ->
        {:noreply,
         socket
         |> push_navigate(to: ~p"/tables/#{table.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        dbg(changeset)
        {:noreply, assign(socket, enter_changeset: changeset)}
    end
  end

  @impl true
  def handle_event("validate", %{"table" => table_params}, socket) do
    changeset =
      %Table{}
      |> Tables.change_table(table_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :table_changeset, changeset)}
  end

  @impl true
  def handle_event("validate_enter", %{"table" => table_params}, socket) do
    changeset =
      %Table{}
      |> Tables.change_table_join(table_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :enter_changeset, changeset)}
  end
end
