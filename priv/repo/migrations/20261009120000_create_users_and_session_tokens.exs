defmodule Anartista.Repo.Migrations.CreateUsersAndSessionTokens do
  use Ecto.Migration

  def change do
    create table(:users) do
      add(:email, :string, null: false)
      add(:hashed_password, :string, null: false)

      timestamps()
    end

    create(unique_index(:users, [:email]))

    create table(:users_tokens) do
      add(:token, :binary, null: false)
      add(:user_id, references(:users, on_delete: :delete_all), null: false)

      timestamps(updated_at: false)
    end

    create(index(:users_tokens, [:user_id]))
    create(unique_index(:users_tokens, [:token]))
  end
end
