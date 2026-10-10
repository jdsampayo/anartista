defmodule Anartista.Repo.Migrations.CreateExhibitions do
  use Ecto.Migration

  def change do
    create table(:exhibitions) do
      add(:title, :string, null: false)
      add(:subtitle, :string)
      add(:date, :string, null: false)
      add(:location, :string, null: false)
      add(:opening, :string)
      add(:photo, :string, null: false)
      add(:image_alt, :string, null: false)
      add(:description, :text, null: false)
      add(:link_url, :string)
      add(:link_text, :string)
      add(:position, :integer, null: false, default: 0)
      add(:seed_key, :string)

      timestamps()
    end

    create(index(:exhibitions, [:position, :id]))
    create(unique_index(:exhibitions, [:seed_key]))
  end
end
