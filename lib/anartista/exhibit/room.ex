defmodule Anartista.Exhibit.Room do
  use Ecto.Schema

  import Ecto.Changeset

  alias Anartista.Artworks.Artwork
  alias Anartista.Exhibit.RoomArtwork

  @types ["standard", "large", "skylit"]
  @maximum_id 9_223_372_036_854_775_807

  schema "exhibit_rooms" do
    field(:name, :string)
    field(:type, :string, default: "standard")
    field(:position, :integer, default: 0)
    field(:artwork_ids, {:array, :integer}, virtual: true, default: [])

    has_many(:room_artworks, RoomArtwork)
    many_to_many(:artworks, Artwork, join_through: RoomArtwork)

    timestamps()
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :type, :position, :artwork_ids])
    |> update_change(:name, fn
      nil -> nil
      name -> String.trim(name)
    end)
    |> update_change(:artwork_ids, fn
      nil -> nil
      ids -> Enum.uniq(ids)
    end)
    |> validate_required([:name, :type, :position])
    |> validate_length(:name, max: 200)
    |> validate_inclusion(:type, @types)
    |> validate_number(:position,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 2_147_483_647
    )
    |> check_constraint(:type, name: :exhibit_rooms_type_check)
    |> check_constraint(:position, name: :exhibit_rooms_position_check)
    |> check_constraint(:name, name: :exhibit_rooms_name_check)
    |> validate_selection_input(attrs)
  end

  defp validate_selection_input(changeset, attrs) do
    value = Map.get(attrs, :artwork_ids, Map.get(attrs, "artwork_ids", :omitted))

    valid? =
      value == :omitted or
        (is_list(value) and
           Enum.all?(value, fn
             id when is_integer(id) ->
               id > 0 and id <= @maximum_id

             id when is_binary(id) ->
               case Integer.parse(id) do
                 {number, ""} -> number > 0 and number <= @maximum_id
                 _ -> false
               end

             _ ->
               false
           end))

    if valid? do
      changeset
    else
      add_error(changeset, :artwork_ids, "debe ser una lista de identificadores válidos")
    end
  end
end
