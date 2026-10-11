defmodule Anartista.Repo.Migrations.ReplaceDividedRoomsWithSkylit do
  use Ecto.Migration

  def up do
    drop(constraint(:exhibit_rooms, :exhibit_rooms_type_check))

    execute("""
    UPDATE exhibit_rooms
    SET type = 'skylit',
        name = CASE
          WHEN name IN ('Sala con muro central', 'Muro central') THEN 'Sala cenital'
          ELSE name
        END,
        updated_at = timezone('UTC', now())
    WHERE type = 'divided'
    """)

    create(
      constraint(:exhibit_rooms, :exhibit_rooms_type_check,
        check: "type IN ('standard', 'large', 'skylit')"
      )
    )
  end

  def down do
    drop(constraint(:exhibit_rooms, :exhibit_rooms_type_check))

    # Custom names and memberships survive rollback; former names cannot be inferred.
    execute("""
    UPDATE exhibit_rooms
    SET type = 'divided', updated_at = timezone('UTC', now())
    WHERE type = 'skylit'
    """)

    create(
      constraint(:exhibit_rooms, :exhibit_rooms_type_check,
        check: "type IN ('standard', 'large', 'divided')"
      )
    )
  end
end
