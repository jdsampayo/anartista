defmodule Anartista.Repo.Migrations.CreateContactMessages do
  use Ecto.Migration

  def change do
    create table(:contact_messages) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :subject, :string, null: false
      add :message, :text, null: false

      timestamps()
    end

    create index(:contact_messages, [:email])
  end
end
