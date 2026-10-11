defmodule Anartista.Repo.Migrations.CreateExhibitRooms do
  use Ecto.Migration

  def up do
    create table(:exhibit_rooms) do
      add(:name, :string, size: 200, null: false)
      add(:type, :string, null: false, default: "standard")
      add(:position, :integer, null: false, default: 0)

      timestamps()
    end

    create(index(:exhibit_rooms, [:position, :id]))

    create(
      constraint(:exhibit_rooms, :exhibit_rooms_name_check, check: "char_length(btrim(name)) > 0")
    )

    create(
      constraint(:exhibit_rooms, :exhibit_rooms_type_check,
        check: "type IN ('standard', 'large', 'divided')"
      )
    )

    create(constraint(:exhibit_rooms, :exhibit_rooms_position_check, check: "position >= 0"))

    create table(:exhibit_room_artworks) do
      add(:room_id, references(:exhibit_rooms, on_delete: :delete_all), null: false)
      add(:artwork_id, references(:artworks, on_delete: :delete_all), null: false)
      add(:position, :integer, null: false, default: 0)

      timestamps()
    end

    create(unique_index(:exhibit_room_artworks, [:room_id, :artwork_id]))
    create(index(:exhibit_room_artworks, [:room_id, :position, :id]))
    create(index(:exhibit_room_artworks, [:artwork_id]))

    create(
      constraint(:exhibit_room_artworks, :exhibit_room_artworks_position_check,
        check: "position >= 0"
      )
    )

    # Freeze the previous category-sorted archive into groups of five. New works
    # after this migration are only exhibited when an administrator selects them.
    execute("""
    WITH ranked_artworks AS (
      SELECT row_number() OVER (
        ORDER BY lower(category), position ASC, id DESC
      ) - 1 AS display_index
      FROM artworks
    )
    INSERT INTO exhibit_rooms (name, type, position, inserted_at, updated_at)
    SELECT 'Sala ' || ((display_index / 5) + 1), 'standard', display_index / 5,
           timezone('UTC', now()), timezone('UTC', now())
    FROM ranked_artworks
    GROUP BY display_index / 5
    ORDER BY display_index / 5
    """)

    execute("""
    WITH ranked_artworks AS (
      SELECT id, row_number() OVER (
        ORDER BY lower(category), position ASC, id DESC
      ) - 1 AS display_index
      FROM artworks
    )
    INSERT INTO exhibit_room_artworks
      (room_id, artwork_id, position, inserted_at, updated_at)
    SELECT room.id, artwork.id, artwork.display_index % 5,
           timezone('UTC', now()), timezone('UTC', now())
    FROM ranked_artworks AS artwork
    JOIN exhibit_rooms AS room ON room.position = artwork.display_index / 5
    ORDER BY artwork.display_index
    """)
  end

  def down do
    drop(table(:exhibit_room_artworks))
    drop(table(:exhibit_rooms))
  end
end
