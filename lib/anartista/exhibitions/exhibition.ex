defmodule Anartista.Exhibitions.Exhibition do
  use Ecto.Schema

  import Ecto.Changeset

  schema "exhibitions" do
    field(:title, :string)
    field(:subtitle, :string)
    field(:date, :string)
    field(:location, :string)
    field(:opening, :string)
    field(:photo, :string)
    field(:image_alt, :string)
    field(:description, :string)
    field(:link_url, :string)
    field(:link_text, :string)
    field(:position, :integer, default: 0)
    field(:seed_key, :string)

    timestamps()
  end

  @doc false
  def changeset(exhibition, attrs) do
    exhibition
    |> cast(attrs, [
      :title,
      :subtitle,
      :date,
      :location,
      :opening,
      :photo,
      :image_alt,
      :description,
      :link_url,
      :link_text,
      :position
    ])
    |> validate_required([:title, :date, :location, :photo, :image_alt, :description, :position])
    |> validate_length(:title, max: 200)
    |> validate_length(:description, max: 5_000)
    |> validate_length(:link_url, max: 2_000)
    |> validate_length(:subtitle, max: 255)
    |> validate_length(:date, max: 255)
    |> validate_length(:location, max: 255)
    |> validate_length(:opening, max: 255)
    |> validate_length(:image_alt, max: 255)
    |> validate_length(:link_text, max: 255)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_format(:photo, ~r{\A/(?:images|uploads/exhibitions)/[^?#\\]+\z},
      message: "debe ser una imagen local"
    )
    |> validate_link()
    |> unique_constraint(:seed_key)
  end

  defp validate_link(changeset) do
    case get_field(changeset, :link_url) do
      nil ->
        changeset

      url ->
        changeset
        |> validate_required([:link_text])
        |> validate_change(:link_url, fn :link_url, _value ->
          case URI.new(url) do
            {:ok, %URI{scheme: "https", host: host}} when is_binary(host) and host != "" ->
              []

            _ ->
              [link_url: "debe ser una URL segura con un dominio"]
          end
        end)
    end
  end
end
