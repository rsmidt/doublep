defmodule Doublep.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      DoublepWeb.Telemetry,
      # Start the Ecto repository
      Doublep.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Doublep.PubSub},
      # Start the Endpoint (http/https)
      DoublepWeb.Endpoint,
      # Registry for table actors
      {Registry, keys: :unique, name: Doublep.Registry.Tables},
      # DynamicSupervisor for table actors
      {DynamicSupervisor, name: Doublep.Supervisor.Tables, strategy: :one_for_one}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Doublep.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DoublepWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
