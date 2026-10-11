defmodule AnartistaWeb.PageLiveTest do
  use AnartistaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Anartista.{Artworks, Exhibit}

  test "live navigation applies, clears, and restores encoded artwork filters", %{conn: conn} do
    attrs = %{
      title: "Mosaico del archivo",
      category: "Mosaico",
      photo: "/images/portafolio/mosaico.webp",
      image_alt: "Fragmentos de mosaico"
    }

    {:ok, mosaic} = Artworks.create_artwork(attrs)

    {:ok, ceramic} =
      Artworks.create_artwork(
        Map.merge(attrs, %{title: "Pieza cerámica", category: "Cerámica / mosaico"})
      )

    {:ok, view, _html} = live(conn, ~p"/about")
    view |> element("header nav[aria-label='Navegación principal'] a", "Obra") |> render_click()
    assert_patch(view, ~p"/obra")
    assert has_element?(view, "#artwork-#{mosaic.id}")
    assert has_element?(view, "#artwork-#{ceramic.id}")

    filter = ~p"/obra?#{[type: ceramic.category]}"

    view
    |> element("nav[aria-label='Filtrar obra por tipo'] a", ceramic.category)
    |> render_click()

    assert_patch(view, filter)
    assert has_element?(view, "#artwork-#{ceramic.id}")
    refute has_element?(view, "#artwork-#{mosaic.id}")

    render_patch(view, ~p"/obra?#{[type: "Tipo inexistente"]}")
    refute has_element?(view, "#artwork-#{ceramic.id}")
    refute has_element?(view, "#artwork-#{mosaic.id}")

    render_patch(view, ~p"/about")
    render_patch(view, filter)
    assert has_element?(view, "#artwork-#{ceramic.id}")
    refute has_element?(view, "#artwork-#{mosaic.id}")

    view |> element("nav[aria-label='Filtrar obra por tipo'] a", "Toda la obra") |> render_click()
    assert_patch(view, ~p"/obra")
    assert has_element?(view, "#artwork-#{mosaic.id}")
    assert has_element?(view, "#artwork-#{ceramic.id}")
  end

  test "Exhibit puts object categories on pedestals without mistaking mosaic materials for objects",
       %{conn: conn} do
    mosaic =
      artwork_fixture(%{title: "Superficie", category: "Mosaico", materials: "Cerámica y piedra"})

    sculpture =
      artwork_fixture(%{
        title: "Volumen",
        category: "Escultura",
        technique: "Ensamblaje",
        dimensions: "30 × 40 × 20 cm"
      })

    ceramic = artwork_fixture(%{title: "Vasija", category: "Cerámica"})
    installation = artwork_fixture(%{title: "Instalación", category: "Instalación"})
    room_fixture(%{name: "Materia y superficie"}, [mosaic, sculpture, ceramic, installation])

    {:ok, view, _html} = live(conn, ~p"/exhibit")

    assert has_element?(view, ".exhibit-wall a[href='#exhibit-record-#{mosaic.id}']")
    refute has_element?(view, ".exhibit-object a[href='#exhibit-record-#{mosaic.id}']")

    for object <- [sculpture, ceramic, installation] do
      assert has_element?(view, ".exhibit-object a[href='#exhibit-record-#{object.id}']")
      refute has_element?(view, ".exhibit-wall a[href='#exhibit-record-#{object.id}']")
    end

    assert has_element?(view, ".exhibit-object-label", "Ensamblaje")
    assert has_element?(view, ".exhibit-object-label", "30 × 40 × 20 cm")
  end

  test "Exhibit has independent public navigation and filters excluded archive records",
       %{conn: conn} do
    ceramic = artwork_fixture(%{title: "Objeto", category: "Cerámica / objeto"})
    painting = artwork_fixture(%{title: "Lienzo", category: "Pintura"})
    excluded = artwork_fixture(%{title: "Solo en el archivo", category: "Grabado"})
    room_fixture(%{name: "Selección del estudio"}, [ceramic, painting])
    {:ok, view, _html} = live(conn, ~p"/obra?#{[type: ceramic.category]}")

    assert has_element?(
             view,
             "header nav[aria-label='Navegación principal'] a[href='/exhibit']",
             "Exhibit"
           )

    assert has_element?(
             view,
             "header nav[aria-label='Navegación móvil'] a[href='/exhibit']",
             "Exhibit"
           )

    assert has_element?(view, "footer")

    view
    |> element("header nav[aria-label='Navegación principal'] a", "Exhibit")
    |> render_click()

    assert_patch(view, ~p"/exhibit")
    refute has_element?(view, "header nav[aria-label='Navegación principal']")
    refute has_element?(view, "header nav[aria-label='Navegación móvil']")
    refute has_element?(view, "footer")
    assert has_element?(view, "#exhibit-record-#{ceramic.id}")
    assert has_element?(view, "#exhibit-record-#{painting.id}")
    refute has_element?(view, "#exhibit-record-#{excluded.id}")
    refute has_element?(view, "nav[aria-label='Filtrar obra por tipo'] a", excluded.category)

    view
    |> element("nav[aria-label='Filtrar obra por tipo'] a", ceramic.category)
    |> render_click()

    assert_patch(view, ~p"/exhibit?#{[type: ceramic.category]}")
    assert has_element?(view, "#exhibit-record-#{ceramic.id}")
    refute has_element?(view, "#exhibit-record-#{painting.id}")
    refute has_element?(view, ".exhibit-wall a[href='#exhibit-record-#{painting.id}']")

    view |> element("nav[aria-label='Filtrar obra por tipo'] a", "Toda la obra") |> render_click()
    assert_patch(view, ~p"/exhibit")
    assert has_element?(view, "#exhibit-record-#{ceramic.id}")
    assert has_element?(view, "#exhibit-record-#{painting.id}")

    render_patch(view, ~p"/exhibit?#{[type: "No publicado"]}")
    refute has_element?(view, "#exhibit-gallery")
    refute has_element?(view, "#exhibit-record-#{ceramic.id}")
    refute has_element?(view, "#exhibit-record-#{painting.id}")
    assert has_element?(view, "p", "No hay obra publicada de este tipo.")

    render_patch(view, ~p"/about")
    assert has_element?(view, "header nav[aria-label='Navegación principal']")
    assert has_element?(view, "footer")
    view |> element("header nav[aria-label='Navegación móvil'] a", "Exhibit") |> render_click()
    assert_patch(view, ~p"/exhibit")
    assert has_element?(view, "#exhibit-record-#{ceramic.id}")
    assert has_element?(view, "#exhibit-record-#{painting.id}")
    refute has_element?(view, "header nav[aria-label='Navegación móvil']")
    refute has_element?(view, "footer")
  end

  test "curated room order, layout and complete selections reach the gallery without duplicate records",
       %{conn: conn} do
    walls =
      for index <- 1..8 do
        artwork_fixture(%{title: "Pintura #{index}", category: "Pintura"})
      end

    objects =
      for index <- 1..7 do
        artwork_fixture(%{title: "Objeto #{index}", category: "Escultura"})
      end

    works = Enum.reverse(walls) ++ objects
    room_fixture(%{name: "Sala cenital", type: "skylit", position: 2}, [hd(walls)])
    room_fixture(%{name: "Sala amplia", type: "large", position: 1}, works)
    room_fixture(%{name: "Sala de estudio", type: "standard", position: 0}, works)

    {:ok, view, html} = live(conn, ~p"/exhibit")
    document = Floki.parse_document!(html)
    rooms = Floki.find(document, ".exhibit-room")

    assert Floki.attribute(rooms, "aria-label") == [
             "Sala de estudio",
             "Sala amplia",
             "Sala cenital"
           ]

    assert has_element?(view, "#exhibit-room-status", "Sala de estudio")

    assert has_element?(
             view,
             ".exhibit-viewport[aria-label='Sala de exposición: Sala de estudio']"
           )

    for artwork <- works do
      assert has_element?(
               view,
               "[aria-label='Sala de estudio'] a[href='#exhibit-record-#{artwork.id}']"
             )

      assert length(Floki.find(document, "#exhibit-record-#{artwork.id}")) == 1
    end

    records = Floki.find(document, ".exhibit-record")
    assert Floki.attribute(records, "id") == Enum.map(works, &"exhibit-record-#{&1.id}")

    [standard, large, _skylit] = rooms

    width = fn room ->
      [room] |> Floki.attribute("data-room-width") |> hd() |> String.to_integer()
    end

    depth = fn room ->
      [room] |> Floki.attribute("data-room-depth") |> hd() |> String.to_integer()
    end

    assert width.(large) > width.(standard)
    assert depth.(large) > depth.(standard)
  end

  test "an empty saved room is explorable but disappears when its artworks do not match a filter",
       %{conn: conn} do
    room_fixture(%{name: "Sala en preparación", position: 0})

    {:ok, view, _html} = live(conn, ~p"/exhibit")
    assert has_element?(view, "#exhibit-room-status", "Sala en preparación")
    assert has_element?(view, "[role='group'][aria-label='Sala en preparación']")
    refute has_element?(view, ".exhibit-empty")
    assert has_element?(view, "#exhibit-gallery")
    refute has_element?(view, ".exhibit-record")

    painting = artwork_fixture(%{title: "Selección", category: "Pintura"})
    room_fixture(%{name: "Pinturas", position: 1}, [painting])

    render_patch(view, ~p"/exhibit?#{[type: painting.category]}")
    refute has_element?(view, "[role='group'][aria-label='Sala en preparación']")
    assert has_element?(view, "#exhibit-room-status", "Pinturas")

    render_patch(view, ~p"/exhibit?#{[type: "No publicado"]}")
    refute has_element?(view, "#exhibit-gallery")
    assert has_element?(view, ".exhibit-empty")

    render_patch(view, ~p"/exhibit")
    assert has_element?(view, "[role='group'][aria-label='Sala en preparación']")
  end

  test "archive artworks alone do not publish implicit exhibit rooms", %{conn: conn} do
    artwork = artwork_fixture(%{title: "Archivo sin selección", category: "Grabado"})
    {:ok, view, _html} = live(conn, ~p"/exhibit")
    refute has_element?(view, "#exhibit-gallery")
    refute has_element?(view, "#exhibit-record-#{artwork.id}")
    assert has_element?(view, ".exhibit-empty")

    render_patch(view, ~p"/obra")
    assert has_element?(view, "#artwork-#{artwork.id}")
  end

  defp room_fixture(attrs, artworks \\ []) do
    {:ok, room} = Exhibit.create_room(Map.put(attrs, :artwork_ids, Enum.map(artworks, & &1.id)))
    room
  end

  defp artwork_fixture(attrs) do
    {:ok, artwork} =
      Artworks.create_artwork(
        Map.merge(
          %{
            photo: "/images/portafolio/mosaico.webp",
            image_alt: "Obra de prueba"
          },
          attrs
        )
      )

    artwork
  end
end
