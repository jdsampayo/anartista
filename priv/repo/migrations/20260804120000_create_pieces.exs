defmodule Anartista.Repo.Migrations.CreatePieces do
  use Ecto.Migration

  def change do
    create table(:pieces) do
      add :name, :string, null: false
      add :description, :text, null: false
      add :photo, :string, null: false
      add :price, :decimal, precision: 10, scale: 2, null: false
      add :payment_link, :string, null: false
      add :available, :boolean, null: false, default: true

      timestamps(updated_at: false)
    end

    create index(:pieces, [:inserted_at])
  end
end
