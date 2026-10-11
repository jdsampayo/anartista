defmodule Mix.Tasks.Anartista.SeedExhibitDemo do
  use Mix.Task

  import Ecto.Query

  alias Anartista.Artworks.Artwork
  alias Anartista.Repo

  @shortdoc "Completes the development archive to 30 works with clearly labeled demo records"
  @moduledoc """
  Run `mix anartista.seed_exhibit_demo` in development after migrating the database.

  Inserts only the missing number of records to reach 30 total. Existing records,
  including edited demo records, are never updated or deleted. Stable seed keys
  make reruns safe; an archive already containing 30 or more records is unchanged.

  Ceramic images are locally authored synthetic illustrations with transparent
  backgrounds, not photographs or 3D models. Other demo records reuse existing
  portfolio images without changing their original artwork records.
  """

  @target_count 30
  @vase "/images/portafolio/exhibit-demo/exhibit-demo-ceramic-ribbed-vase.webp"
  @bowl "/images/portafolio/exhibit-demo/exhibit-demo-ceramic-jade-bowl.webp"
  @jar "/images/portafolio/exhibit-demo/exhibit-demo-ceramic-banded-jar.webp"
  @bottle "/images/portafolio/exhibit-demo/exhibit-demo-ceramic-cobalt-bottle.webp"

  # The first 27 fill the current three-record archive. The last three also allow
  # an empty development archive to reach the same total without another seed.
  @demo_records [
    {"Cerámica", "Jarrón estriado — estudio 01", @vase},
    {"Cerámica", "Cuenco jade — estudio 01", @bowl},
    {"Cerámica", "Tarro de bandas — estudio 01", @jar},
    {"Cerámica", "Botella cobalto — estudio 01", @bottle},
    {"Cerámica", "Jarrón estriado — estudio 02", @vase},
    {"Cerámica", "Cuenco jade — estudio 02", @bowl},
    {"Cerámica", "Tarro de bandas — estudio 02", @jar},
    {"Cerámica", "Botella cobalto — estudio 02", @bottle},
    {"Escultura", "Volumen vertical — estudio 01", "/images/portafolio/escultura.webp"},
    {"Escultura", "Volumen vertical — estudio 02", "/images/portafolio/escultura.webp"},
    {"Escultura", "Volumen vertical — estudio 03", "/images/portafolio/escultura.webp"},
    {"Escultura", "Volumen vertical — estudio 04", "/images/portafolio/escultura.webp"},
    {"Escultura", "Volumen vertical — estudio 05", "/images/portafolio/escultura.webp"},
    {"Pintura", "Campo de color — estudio 01", "/images/portafolio/pintura.webp"},
    {"Pintura", "Campo de color — estudio 02", "/images/portafolio/pintura.webp"},
    {"Pintura", "Campo de color — estudio 03", "/images/portafolio/pintura.webp"},
    {"Pintura", "Campo de color — estudio 04", "/images/portafolio/pintura.webp"},
    {"Pintura", "Campo de color — estudio 05", "/images/portafolio/pintura.webp"},
    {"Grabado", "Trama sobre papel — estudio 01", "/images/portafolio/grabado.webp"},
    {"Grabado", "Trama sobre papel — estudio 02", "/images/portafolio/grabado.webp"},
    {"Grabado", "Trama sobre papel — estudio 03", "/images/portafolio/grabado.webp"},
    {"Grabado", "Trama sobre papel — estudio 04", "/images/portafolio/grabado.webp"},
    {"Grabado", "Trama sobre papel — estudio 05", "/images/portafolio/grabado.webp"},
    {"Mosaico", "Ensamblaje de teselas — estudio 01", "/images/portafolio/mosaico.webp"},
    {"Mosaico", "Ensamblaje de teselas — estudio 02", "/images/portafolio/mosaico.webp"},
    {"Mosaico", "Ensamblaje de teselas — estudio 03", "/images/portafolio/mosaico.webp"},
    {"Mosaico", "Ensamblaje de teselas — estudio 04", "/images/portafolio/mosaico.webp"},
    {"Cerámica", "Jarrón estriado — estudio 03", @vase},
    {"Pintura", "Campo de color — estudio 06", "/images/portafolio/pintura.webp"},
    {"Mosaico", "Ensamblaje de teselas — estudio 05", "/images/portafolio/mosaico.webp"}
  ]

  @metadata %{
    "Cerámica" => %{
      technique: "DEMO: modelado y esmaltado ficticios",
      materials: "DEMO: barro y esmalte ficticios",
      dimensions: "DEMO: 30 × 20 × 20 cm (medidas ficticias)"
    },
    "Escultura" => %{
      technique: "DEMO: construcción volumétrica ficticia",
      materials: "DEMO: cerámica y fibras ficticias",
      dimensions: "DEMO: 45 × 20 × 20 cm (medidas ficticias)"
    },
    "Pintura" => %{
      technique: "DEMO: pintura en capas ficticia",
      materials: "DEMO: pigmentos y lienzo ficticios",
      dimensions: "DEMO: 80 × 60 cm (medidas ficticias)"
    },
    "Grabado" => %{
      technique: "DEMO: impresión en relieve ficticia",
      materials: "DEMO: tinta y papel ficticios",
      dimensions: "DEMO: 40 × 50 cm (medidas ficticias)"
    },
    "Mosaico" => %{
      technique: "DEMO: ensamblaje de teselas ficticio",
      materials: "DEMO: vidrio, cerámica y soporte ficticios",
      dimensions: "DEMO: 60 × 40 cm (medidas ficticias)"
    }
  }

  @impl Mix.Task
  def run([]) do
    if Mix.env() != :dev do
      Mix.raise("mix anartista.seed_exhibit_demo is available only in MIX_ENV=dev")
    end

    Mix.Task.run("app.start")

    {:ok, %{before: before_count, inserted: inserted, total: total}} =
      Repo.transaction(fn ->
        before_count = Repo.aggregate(Artwork, :count, :id)
        needed = max(@target_count - before_count, 0)

        existing_keys =
          from(artwork in Artwork,
            where: not is_nil(artwork.seed_key),
            select: artwork.seed_key
          )
          |> Repo.all()
          |> MapSet.new()

        first_position = (Repo.aggregate(Artwork, :max, :position) || -1) + 1
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        entries =
          @demo_records
          |> Enum.with_index(1)
          |> Enum.reject(fn {_record, index} ->
            MapSet.member?(existing_keys, seed_key(index))
          end)
          |> Enum.take(needed)
          |> Enum.with_index(first_position)
          |> Enum.map(fn {{record, index}, position} ->
            demo_attrs(record, index, position, now)
          end)

        {inserted, _} =
          Repo.insert_all(Artwork, entries,
            on_conflict: :nothing,
            conflict_target: [:seed_key]
          )

        %{
          before: before_count,
          inserted: inserted,
          total: Repo.aggregate(Artwork, :count, :id)
        }
      end)

    Mix.shell().info(
      "Exhibit DEMO: before=#{before_count}, inserted=#{inserted}, total=#{total}."
    )
  end

  def run(_args), do: Mix.raise("Usage: mix anartista.seed_exhibit_demo")

  defp seed_key(index) do
    "exhibit-demo-" <> String.pad_leading(Integer.to_string(index), 2, "0")
  end

  defp demo_attrs({category, title, photo}, index, position, now) do
    {image_alt, description} =
      if category == "Cerámica" do
        {
          "DEMO: ilustración sintética de #{title}; no es una fotografía ni un modelo 3D",
          "Registro sintético de desarrollo para inspeccionar pedestales de Exhibit. " <>
            "La imagen es una ilustración sintética DEMO con fondo transparente, no una fotografía " <>
            "ni un modelo 3D. Todos los datos de la ficha son ficticios y no describen una obra " <>
            "real ni hacen afirmaciones sobre la artista."
        }
      else
        {
          "DEMO: #{title}; imagen local de #{category} reutilizada en un registro sintético",
          "Registro sintético de desarrollo para explorar el archivo y Exhibit. " <>
            "La imagen local del portafolio se reutiliza como referencia visual; no representa " <>
            "una obra adicional. Todos los datos de esta ficha DEMO son ficticios y no hacen " <>
            "afirmaciones sobre la artista ni modifican la ficha original."
        }
      end

    Map.merge(Map.fetch!(@metadata, category), %{
      seed_key: seed_key(index),
      title: "DEMO · #{title}",
      category: category,
      photo: photo,
      image_alt: image_alt,
      description: description,
      year: "2026 (DEMO ficticio)",
      edition: "DEMO: ejemplar ficticio #{index}/#{@target_count}",
      collection: "DEMO de desarrollo; colección ficticia",
      selected: false,
      position: position,
      inserted_at: now,
      updated_at: now
    })
  end
end
