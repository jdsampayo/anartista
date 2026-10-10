defmodule Anartista.Artworks do
  @moduledoc """
  Manages the artwork archive and preserves the original selected works with a repeatable seed.
  """

  import Ecto.Query, warn: false

  alias Anartista.Artworks.Artwork
  alias Anartista.Repo

  @current_artworks [
    %{
      seed_key: "mosaico",
      title: "Mosaico",
      category: "Mosaico",
      photo: "/images/portafolio/mosaico.webp",
      image_alt: "Mosaico",
      description:
        "Teselas de esmalte de porcelana, vidrio, cerámica, piedra y elementos recuperados que convierten la luz, el color y la textura en una superficie común.",
      selected: true,
      position: 0
    },
    %{
      seed_key: "pintura",
      title: "Pintura",
      category: "Pintura",
      photo: "/images/portafolio/pintura.webp",
      image_alt: "Pintura",
      description:
        "Exploraciones cromáticas y texturales que abren un diálogo con la luz, la profundidad y el entorno.",
      selected: true,
      position: 1
    },
    %{
      seed_key: "grabado",
      title: "Grabado",
      category: "Grabado",
      photo: "/images/portafolio/grabado.webp",
      image_alt: "Grabado",
      description:
        "Series donde reproducción y unicidad se desplazan entre sí para cuestionar la imagen repetida.",
      selected: true,
      position: 2
    }
  ]

  def list_artworks(opts \\ []) do
    Artwork
    |> filter_category(Keyword.get(opts, :category))
    |> ordered()
    |> Repo.all()
  end

  def list_selected_artworks do
    Artwork
    |> where([artwork], artwork.selected == true)
    |> ordered()
    |> Repo.all()
  end

  def list_categories do
    Artwork
    |> select([artwork], artwork.category)
    |> distinct(true)
    |> order_by([artwork], asc: artwork.category)
    |> Repo.all()
  end

  def get_artwork!(id), do: Repo.get!(Artwork, id)

  def create_artwork(attrs \\ %{}) do
    %Artwork{}
    |> Artwork.changeset(attrs)
    |> Repo.insert()
  end

  def update_artwork(%Artwork{} = artwork, attrs) do
    artwork
    |> Artwork.changeset(attrs)
    |> Repo.update()
  end

  def delete_artwork(%Artwork{} = artwork), do: Repo.delete(artwork)

  def change_artwork(%Artwork{} = artwork, attrs \\ %{}) do
    Artwork.changeset(artwork, attrs)
  end

  @doc """
  Inserts the three original selected works without replacing previously seeded records.

  Returns `%{inserted: count, skipped: count}`. Unique internal seed keys and
  database conflict handling preserve administrator edits on reruns and concurrent runs.
  """
  def seed_current_artworks! do
    {:ok, result} =
      Repo.transaction(fn ->
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        entries =
          Enum.map(@current_artworks, fn attrs ->
            Map.merge(attrs, %{inserted_at: now, updated_at: now})
          end)

        {inserted, _} =
          Repo.insert_all(Artwork, entries,
            on_conflict: :nothing,
            conflict_target: [:seed_key]
          )

        %{inserted: inserted, skipped: length(entries) - inserted}
      end)

    result
  end

  defp filter_category(query, category) when category in [nil, ""], do: query

  defp filter_category(query, category) do
    where(query, [artwork], artwork.category == ^category)
  end

  defp ordered(query), do: order_by(query, [artwork], asc: artwork.position, desc: artwork.id)
end
