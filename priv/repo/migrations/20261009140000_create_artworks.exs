defmodule Anartista.Repo.Migrations.CreateArtworks do
  use Ecto.Migration

  def change do
    create table(:artworks) do
      add(:title, :string, size: 200, null: false)
      add(:category, :string, size: 100, null: false)
      add(:photo, :string, size: 255, null: false)
      add(:image_alt, :string, size: 255, null: false)
      add(:description, :text)
      add(:year, :string, size: 100)
      add(:technique, :string, size: 255)
      add(:materials, :string, size: 255)
      add(:dimensions, :string, size: 255)
      add(:edition, :string, size: 255)
      add(:collection, :string, size: 255)
      add(:selected, :boolean, null: false, default: false)
      add(:position, :integer, null: false, default: 0)
      add(:seed_key, :string)

      timestamps()
    end

    create(index(:artworks, [:position, :id]))
    create(index(:artworks, [:category]))
    create(unique_index(:artworks, [:seed_key]))
  end
end
