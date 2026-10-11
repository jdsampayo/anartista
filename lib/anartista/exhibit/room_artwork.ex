defmodule Anartista.Exhibit.RoomArtwork do
  use Ecto.Schema

  import Ecto.Changeset

  schema "exhibit_room_artworks" do
    belongs_to(:room, Anartista.Exhibit.Room)
    belongs_to(:artwork, Anartista.Artworks.Artwork)
    field(:position, :integer, default: 0)

    timestamps()
  end

  @doc false
  def changeset(room_artwork, attrs) do
    room_artwork
    |> cast(attrs, [:room_id, :artwork_id, :position])
    |> validate_required([:room_id, :artwork_id, :position])
    |> validate_number(:position,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 2_147_483_647
    )
    |> foreign_key_constraint(:room_id)
    |> foreign_key_constraint(:artwork_id)
    |> unique_constraint([:room_id, :artwork_id])
    |> check_constraint(:position, name: :exhibit_room_artworks_position_check)
  end
end
