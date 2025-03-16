defmodule Anartista.Repo do
  use Ecto.Repo,
    otp_app: :anartista,
    adapter: Ecto.Adapters.Postgres
end
