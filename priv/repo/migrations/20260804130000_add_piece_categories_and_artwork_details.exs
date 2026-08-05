defmodule Anartista.Repo.Migrations.AddPieceCategoriesAndArtworkDetails do
  use Ecto.Migration

  def up do
    alter table(:pieces) do
      add :category, :string, null: false, default: "Artesanía"
      add :technique, :string
      add :dimensions, :string
      add :year, :integer
    end

    execute("UPDATE pieces SET category = 'Artesanía' WHERE category IS NULL OR category = ''")
  end

  def down do
    alter table(:pieces) do
      remove :year
      remove :dimensions
      remove :technique
      remove :category
    end
  end
end
