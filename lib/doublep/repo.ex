defmodule Doublep.Repo do
  use Ecto.Repo,
    otp_app: :doublep,
    adapter: Ecto.Adapters.Postgres
end
