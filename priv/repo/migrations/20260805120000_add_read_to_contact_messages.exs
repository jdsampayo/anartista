defmodule Anartista.Repo.Migrations.AddReadToContactMessages do
  use Ecto.Migration

  def change do
    alter table(:contact_messages) do
      add :read, :boolean, null: false, default: false
    end
  end
end
