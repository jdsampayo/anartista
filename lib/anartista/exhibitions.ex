defmodule Anartista.Exhibitions do
  @moduledoc """
  Manages exhibitions and preserves the original public archive with a repeatable seed.
  """

  import Ecto.Query, warn: false

  alias Anartista.Exhibitions.Exhibition
  alias Anartista.Repo

  @current_exhibitions [
    %{
      seed_key: "universos-personales-2025",
      title: "Universos Personales: Primera Exposición",
      date: "26 de marzo a 28 de abril 2025",
      location: "Ciudad de México",
      opening: "Inauguración a las 6pm",
      photo: "/images/exposiciones/universos-personales-2025.webp",
      image_alt: "Universos Personales: Primera Exposición",
      description:
        "Muestra colectiva de estudiantes de La Esmeralda que exhibe obras de diversas disciplinas en el restaurante La Guarida del Diablo Panzón. Una iniciativa que promovió el talento emergente y la venta directa de obra.",
      link_url:
        "https://www.esmeralda.edu.mx/_files/ugd/d50bce_b8566f0fe8154223bf11385f5e01df69.pdf",
      link_text: "Ver programa (PDF)",
      position: 0
    },
    %{
      seed_key: "mujeres-creadoras-2025",
      title: "Mujeres Creadoras 2025: Cuidados",
      date: "22 y 23 de marzo 2025",
      location: "Ciudad de México",
      opening: "Inicia a las 9am",
      photo: "/images/exposiciones/mujeres-creadoras-2025.webp",
      image_alt: "Mujeres Creadoras 2025: Cuidados",
      description:
        "Exposición que abordó los cuidados desde múltiples dimensiones y narrativas: arte, política, encuentro y compartición.",
      link_url: "https://www.mujerescreadoras.org/",
      link_text: "Visitar Mujeres Creadoras",
      position: 1
    }
  ]

  def list_exhibitions do
    Exhibition
    |> order_by([exhibition], asc: exhibition.position, desc: exhibition.id)
    |> Repo.all()
  end

  def get_exhibition!(id), do: Repo.get!(Exhibition, id)

  def create_exhibition(attrs \\ %{}) do
    %Exhibition{}
    |> Exhibition.changeset(attrs)
    |> Repo.insert()
  end

  def update_exhibition(%Exhibition{} = exhibition, attrs) do
    exhibition
    |> Exhibition.changeset(attrs)
    |> Repo.update()
  end

  def delete_exhibition(%Exhibition{} = exhibition), do: Repo.delete(exhibition)

  def change_exhibition(%Exhibition{} = exhibition, attrs \\ %{}) do
    Exhibition.changeset(exhibition, attrs)
  end

  @doc """
  Inserts the original exhibitions without replacing previously seeded records.

  Returns `%{inserted: count, skipped: count}`. The unique internal seed key and
  database conflict handling also make concurrent deployment runs safe.
  """
  def seed_current_exhibitions! do
    {:ok, result} =
      Repo.transaction(fn ->
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        entries =
          Enum.map(@current_exhibitions, fn attrs ->
            Map.merge(attrs, %{inserted_at: now, updated_at: now})
          end)

        {inserted, _} =
          Repo.insert_all(Exhibition, entries,
            on_conflict: :nothing,
            conflict_target: [:seed_key]
          )

        %{inserted: inserted, skipped: length(entries) - inserted}
      end)

    result
  end
end
