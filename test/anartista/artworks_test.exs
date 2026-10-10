defmodule Anartista.ArtworksTest do
  use Anartista.DataCase

  alias Anartista.Artworks
  alias Anartista.Artworks.Artwork

  @valid_attrs %{
    title: "Fragmentos",
    category: "Mosaico",
    photo: "/uploads/artworks/fragmentos.webp",
    image_alt: "Superficie de teselas"
  }
  @label_fields [:year, :technique, :materials, :dimensions, :edition, :collection]

  test "orders the archive by position ascending and id descending" do
    {:ok, first} = Artworks.create_artwork(Map.put(@valid_attrs, :position, 1))
    {:ok, last} = Artworks.create_artwork(Map.put(@valid_attrs, :position, 2))
    {:ok, newest} = Artworks.create_artwork(Map.put(@valid_attrs, :position, 1))
    {:ok, leading} = Artworks.create_artwork(Map.put(@valid_attrs, :position, 0))

    assert Enum.map(Artworks.list_artworks(), & &1.id) ==
             [leading.id, newest.id, first.id, last.id]
  end

  test "trims free-entry categories and filters exactly without narrowing category options" do
    {:ok, mosaic} = Artworks.create_artwork(Map.put(@valid_attrs, :category, "  Mosaico  "))
    {:ok, painting} = Artworks.create_artwork(Map.put(@valid_attrs, :category, "Pintura"))
    {:ok, another} = Artworks.create_artwork(@valid_attrs)
    {:ok, mixed} = Artworks.create_artwork(Map.put(@valid_attrs, :category, "Técnica mixta"))

    assert mosaic.category == "Mosaico"
    assert Artworks.list_artworks(category: "Mosaico") == [another, mosaic]
    assert Artworks.list_artworks(category: "Pintura") == [painting]
    assert Artworks.list_artworks(category: "mosaico") == []
    assert Artworks.list_artworks(category: "Sin obras") == []
    assert Artworks.list_artworks(category: nil) == [mixed, another, painting, mosaic]
    assert Artworks.list_artworks(category: "") == Artworks.list_artworks()
    assert Artworks.list_categories() == ["Mosaico", "Pintura", "Técnica mixta"]
  end

  test "selection affects only the selected list and follows archive ordering" do
    {:ok, unselected} = Artworks.create_artwork(@valid_attrs)

    {:ok, selected} =
      Artworks.create_artwork(Map.merge(@valid_attrs, %{selected: true, position: 2}))

    {:ok, leading} = Artworks.create_artwork(Map.put(@valid_attrs, :selected, true))
    assert Artworks.list_selected_artworks() == [leading, selected]
    assert unselected in Artworks.list_artworks()

    assert {:ok, deselected} = Artworks.update_artwork(selected, %{selected: false})
    assert Artworks.list_selected_artworks() == [leading]
    assert deselected in Artworks.list_artworks()
    assert {:ok, selected_now} = Artworks.update_artwork(unselected, %{selected: true})
    assert Artworks.list_selected_artworks() == [leading, selected_now]
  end

  test "persists optional object labels, permits clearing them and supports CRUD" do
    assert {:ok, artwork} = Artworks.create_artwork(@valid_attrs)
    assert Artworks.get_artwork!(artwork.id) == artwork
    assert artwork.description == nil
    assert Enum.all?(@label_fields, &(Map.fetch!(artwork, &1) == nil))

    attrs = %{
      title: "Fragmentos II",
      category: "Grabado",
      description: "Una descripción de la obra.",
      year: "2024–2026",
      technique: "Aguafuerte",
      materials: "Papel y tinta",
      dimensions: "30 × 40 cm",
      edition: "2/10",
      collection: "Colección particular",
      photo: "/images/portafolio/grabado.webp",
      image_alt: "Estampa en papel",
      selected: true,
      position: 3
    }

    assert {:ok, updated} = Artworks.update_artwork(artwork, attrs)
    assert Map.take(updated, Map.keys(attrs)) == attrs
    cleared_attrs = Map.new([:description | @label_fields], &{&1, ""})
    assert {:ok, cleared} = Artworks.update_artwork(updated, cleared_attrs)
    assert Enum.all?([:description | @label_fields], &(Map.fetch!(cleared, &1) == nil))
    assert {:ok, %Artwork{}} = Artworks.delete_artwork(cleared)
    assert_raise Ecto.NoResultsError, fn -> Artworks.get_artwork!(artwork.id) end
  end

  test "requires content and rejects invalid updates without changing stored values" do
    assert {:error, changeset} = Artworks.create_artwork(%{})

    for field <- [:title, :category, :photo, :image_alt] do
      assert "can't be blank" in Map.fetch!(errors_on(changeset), field)
    end

    {:ok, artwork} = Artworks.create_artwork(@valid_attrs)

    for attrs <- [
          %{category: "   "},
          %{category: nil},
          %{title: ""},
          %{selected: nil},
          %{position: nil}
        ] do
      assert {:error, _} = Artworks.update_artwork(artwork, attrs)
    end

    assert Artworks.get_artwork!(artwork.id) == artwork

    for attrs <- [%{position: -1}, %{position: "first"}, %{selected: "sometimes"}] do
      assert {:error, _} = Artworks.create_artwork(Map.merge(@valid_attrs, attrs))
    end
  end

  test "display order accepts the database maximum and rejects overflow without changing the record" do
    maximum = 2_147_483_647
    assert {:ok, artwork} = Artworks.create_artwork(Map.put(@valid_attrs, :position, maximum))
    assert Artworks.get_artwork!(artwork.id).position == maximum

    assert {:error, create_errors} =
             Artworks.create_artwork(Map.put(@valid_attrs, :position, maximum + 1))

    assert Map.has_key?(errors_on(create_errors), :position)
    assert {:error, update_errors} = Artworks.update_artwork(artwork, %{position: maximum + 1})
    assert Map.has_key?(errors_on(update_errors), :position)
    assert Artworks.get_artwork!(artwork.id) == artwork
  end

  test "accepts field length boundaries and rejects values beyond them" do
    limits = [
      title: 200,
      category: 100,
      image_alt: 255,
      description: 5_000,
      year: 100,
      technique: 255,
      materials: 255,
      dimensions: 255,
      edition: 255,
      collection: 255
    ]

    for {field, limit} <- limits do
      assert {:ok, _} =
               Artworks.create_artwork(Map.put(@valid_attrs, field, String.duplicate("a", limit)))

      assert {:error, changeset} =
               Artworks.create_artwork(
                 Map.put(@valid_attrs, field, String.duplicate("a", limit + 1))
               )

      assert Map.has_key?(errors_on(changeset), field)
    end

    prefix = "/uploads/artworks/"
    photo = prefix <> String.duplicate("a", 255 - String.length(prefix))
    assert {:ok, _} = Artworks.create_artwork(Map.put(@valid_attrs, :photo, photo))

    assert {:error, changeset} =
             Artworks.create_artwork(Map.put(@valid_attrs, :photo, photo <> "a"))

    assert Map.has_key?(errors_on(changeset), :photo)
  end

  test "accepts only artwork image locations" do
    for photo <- [
          "https://example.com/photo.webp",
          "/images/other.webp",
          "/uploads/exhibitions/photo.webp",
          "photo.webp",
          "/uploads/artworks/photo.webp?download=1",
          "/images/portafolio/photo.webp#image"
        ] do
      assert {:error, changeset} = Artworks.create_artwork(Map.put(@valid_attrs, :photo, photo))
      assert "debe ser una imagen local" in errors_on(changeset).photo
    end
  end

  test "administrator attributes cannot create or replace internal seed keys" do
    assert {:ok, %Artwork{seed_key: nil} = artwork} =
             Artworks.create_artwork(Map.put(@valid_attrs, :seed_key, "mosaico"))

    assert {:ok, %Artwork{seed_key: nil}} =
             Artworks.update_artwork(artwork, %{"seed_key" => "pintura"})
  end

  test "seeds exact originals and reruns preserve every administrator edit without duplicates" do
    assert %{inserted: 3, skipped: 0} = Artworks.seed_current_artworks!()
    assert [mosaic, painting, engraving] = Artworks.list_artworks()

    originals = [
      {mosaic, "Mosaico", "mosaico", 0,
       "Teselas de esmalte de porcelana, vidrio, cerámica, piedra y elementos recuperados que convierten la luz, el color y la textura en una superficie común."},
      {painting, "Pintura", "pintura", 1,
       "Exploraciones cromáticas y texturales que abren un diálogo con la luz, la profundidad y el entorno."},
      {engraving, "Grabado", "grabado", 2,
       "Series donde reproducción y unicidad se desplazan entre sí para cuestionar la imagen repetida."}
    ]

    for {artwork, title, key, position, description} <- originals do
      assert artwork.title == title
      assert artwork.category == title
      assert artwork.image_alt == title
      assert artwork.photo == "/images/portafolio/#{key}.webp"
      assert artwork.description == description
      assert artwork.position == position
      assert artwork.selected == true
      assert artwork.seed_key == key
      assert Enum.all?(@label_fields, &(Map.fetch!(artwork, &1) == nil))
    end

    attrs = %{
      title: "Título editado",
      category: "Ensamblaje",
      image_alt: "Texto editado",
      description: "Descripción editada",
      photo: "/uploads/artworks/edited.webp",
      selected: false,
      position: 7,
      year: "2026",
      technique: "Ensamblaje",
      materials: "Material recuperado",
      dimensions: "50 × 50 cm",
      edition: "Única",
      collection: "Colección editada",
      seed_key: "replacement"
    }

    assert {:ok, edited} = Artworks.update_artwork(mosaic, attrs)
    assert edited.seed_key == "mosaico"
    assert %{inserted: 0, skipped: 3} = Artworks.seed_current_artworks!()
    assert Artworks.list_artworks() == [painting, engraving, edited]
    assert Artworks.list_selected_artworks() == [painting, engraving]
  end

  test "seeds only missing originals and permits multiple unseeded works" do
    {:ok, first} = Artworks.create_artwork(@valid_attrs)
    {:ok, second} = Artworks.create_artwork(@valid_attrs)
    assert first.seed_key == nil
    assert second.seed_key == nil
    assert %{inserted: 3, skipped: 0} = Artworks.seed_current_artworks!()
    original = Enum.find(Artworks.list_artworks(), &(&1.seed_key == "pintura"))
    assert {:ok, _} = Artworks.delete_artwork(original)
    assert %{inserted: 1, skipped: 2} = Artworks.seed_current_artworks!()
    assert length(Artworks.list_artworks()) == 5
  end
end
