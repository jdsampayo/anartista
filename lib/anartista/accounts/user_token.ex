defmodule Anartista.Accounts.UserToken do
  use Ecto.Schema

  schema "users_tokens" do
    field(:token, :binary, redact: true)
    belongs_to(:user, Anartista.Accounts.User)

    timestamps(updated_at: false)
  end
end
