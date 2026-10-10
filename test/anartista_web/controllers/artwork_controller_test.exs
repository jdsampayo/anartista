defmodule AnartistaWeb.ArtworkControllerTest do
  use AnartistaWeb.ConnCase

  alias Anartista.Artworks

  @attrs %{
    title: "Obra de archivo",
    category: "Mosaico",
    photo: "/images/portafolio/mosaico.webp",
    image_alt: "Fragmentos del mosaico",
    description: "Una obra del archivo."
  }

  test "the public archive groups and filters types without excluding unselected artwork", %{
    conn: conn
  } do
    {:ok, mosaic} = Artworks.create_artwork(@attrs)

    {:ok, ceramic} =
      Artworks.create_artwork(
        Map.merge(@attrs, %{
          title: "Pieza cerámica",
          category: "Cerámica / mosaico",
          selected: true
        })
      )

    document = conn |> get(~p"/obra") |> html_response(200) |> Floki.parse_document!()
    assert Floki.find(document, "#artwork-#{mosaic.id}") != []
    assert Floki.find(document, "#artwork-#{ceramic.id}") != []

    filter_url =
      document
      |> Floki.find("nav[aria-label='Filtrar obra por tipo'] a")
      |> Enum.find(fn link -> link |> Floki.text() |> String.trim() == ceramic.category end)
      |> Floki.attribute("href")
      |> List.first()

    filtered = build_conn() |> get(filter_url) |> html_response(200) |> Floki.parse_document!()
    assert Floki.find(filtered, "#artwork-#{ceramic.id}") != []
    assert Floki.find(filtered, "#artwork-#{mosaic.id}") == []

    assert filtered |> Floki.find("nav a[aria-current=page]") |> Floki.text() |> String.trim() ==
             ceramic.category

    unknown =
      build_conn()
      |> get(~p"/obra", type: "Tipo inexistente")
      |> html_response(200)
      |> Floki.parse_document!()

    assert Floki.find(unknown, "article") == []

    assert unknown
           |> Floki.find("nav[aria-label='Filtrar obra por tipo'] a")
           |> Floki.attribute("href")
           |> Enum.member?("/obra")
  end

  test "about includes only selected artwork and reflects changes to that flag", %{conn: conn} do
    {:ok, artwork} = Artworks.create_artwork(@attrs)

    {:ok, selected} =
      Artworks.create_artwork(Map.merge(@attrs, %{title: "Obra elegida", selected: true}))

    document = conn |> get(~p"/about") |> html_response(200) |> Floki.parse_document!()
    assert Floki.find(document, "#selected-artworks #artwork-#{selected.id}") != []
    assert Floki.find(document, "#selected-artworks #artwork-#{artwork.id}") == []

    {:ok, _} = Artworks.update_artwork(selected, %{selected: false})
    document = build_conn() |> get(~p"/about") |> html_response(200) |> Floki.parse_document!()
    assert Floki.find(document, "#selected-artworks") == []

    {:ok, _} = Artworks.update_artwork(artwork, %{selected: true})
    document = build_conn() |> get(~p"/about") |> html_response(200) |> Floki.parse_document!()
    assert Floki.find(document, "#selected-artworks #artwork-#{artwork.id}") != []
  end

  test "object labels show supplied facts, omit missing facts, and never repeat the artist", %{
    conn: conn
  } do
    metadata = %{
      year: "2024–2026",
      technique: "Linograbado",
      materials: "Tinta sobre papel",
      dimensions: "20 × 30 cm",
      edition: "2/10",
      collection: "Colección particular"
    }

    {:ok, complete} = Artworks.create_artwork(Map.merge(@attrs, metadata))
    {:ok, minimal} = Artworks.create_artwork(Map.put(@attrs, :title, "Registro sin ficha"))
    document = conn |> get(~p"/obra") |> html_response(200) |> Floki.parse_document!()
    values = document |> Floki.find("#artwork-#{complete.id} dd") |> Enum.map(&Floki.text/1)
    assert Map.values(metadata) |> Enum.all?(&(&1 in values))
    refute document |> Floki.find("article") |> Floki.text() =~ "Ana Álvarez"

    assert document |> Floki.find("#artwork-#{minimal.id} dd") |> Enum.map(&Floki.text/1) == [
             minimal.category
           ]

    assert document |> Floki.find("#artwork-#{complete.id} img") |> Floki.attribute("alt") == [
             complete.image_alt
           ]
  end
end
