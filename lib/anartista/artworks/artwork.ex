defmodule Anartista.Artworks.Artwork do
  use Ecto.Schema

  import Ecto.Changeset

  schema "artworks" do
    field(:title, :string)
    field(:category, :string)
    field(:photo, :string)
    field(:image_alt, :string)
    field(:description, :string)
    field(:year, :string)
    field(:technique, :string)
    field(:materials, :string)
    field(:dimensions, :string)
    field(:edition, :string)
    field(:collection, :string)
    field(:selected, :boolean, default: false)
    field(:position, :integer, default: 0)
    field(:seed_key, :string)

    timestamps()
  end

  @doc false
  def changeset(artwork, attrs) do
    artwork
    |> cast(attrs, [
      :title,
      :category,
      :photo,
      :image_alt,
      :description,
      :year,
      :technique,
      :materials,
      :dimensions,
      :edition,
      :collection,
      :selected,
      :position
    ])
    |> update_change(:category, fn
      nil -> nil
      category -> String.trim(category)
    end)
    |> validate_required([:title, :category, :photo, :image_alt, :position, :selected])
    |> validate_length(:title, max: 200)
    |> validate_length(:category, max: 100)
    |> validate_length(:photo, max: 255)
    |> validate_length(:image_alt, max: 255)
    |> validate_length(:description, max: 5_000)
    |> validate_length(:year, max: 100)
    |> validate_length(:technique, max: 255)
    |> validate_length(:materials, max: 255)
    |> validate_length(:dimensions, max: 255)
    |> validate_length(:edition, max: 255)
    |> validate_length(:collection, max: 255)
    |> validate_number(:position,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 2_147_483_647
    )
    |> validate_format(:photo, ~r{\A/(?:images/portafolio|uploads/artworks)/[^?#\\]+\z},
      message: "debe ser una imagen local"
    )
    |> unique_constraint(:seed_key)
  end
end
