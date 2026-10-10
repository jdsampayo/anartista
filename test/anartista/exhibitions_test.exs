defmodule Anartista.ExhibitionsTest do
  use Anartista.DataCase

  alias Anartista.Exhibitions
  alias Anartista.Exhibitions.Exhibition

  @valid_attrs %{
    title: "Exposición de prueba",
    date: "9 de octubre 2026",
    location: "Ciudad de México",
    photo: "/uploads/exhibitions/test-exhibition.webp",
    image_alt: "Obras en la exposición de prueba",
    description: "Una muestra colectiva de arte."
  }

  test "lists exhibitions by position ascending and id descending" do
    {:ok, first} = Exhibitions.create_exhibition(Map.put(@valid_attrs, :position, 1))
    {:ok, last} = Exhibitions.create_exhibition(Map.put(@valid_attrs, :position, 2))
    {:ok, newest} = Exhibitions.create_exhibition(Map.put(@valid_attrs, :position, 1))
    {:ok, leading} = Exhibitions.create_exhibition(Map.put(@valid_attrs, :position, 0))

    assert Enum.map(Exhibitions.list_exhibitions(), & &1.id) ==
             [leading.id, newest.id, first.id, last.id]
  end

  test "creates, fetches, changes, updates and deletes an exhibition" do
    {:ok, exhibition} = Exhibitions.create_exhibition(@valid_attrs)
    assert Exhibitions.get_exhibition!(exhibition.id) == exhibition

    attrs = %{
      title: "Exposición actualizada",
      subtitle: "Encuentro de artistas",
      opening: "Inauguración a las 6pm",
      photo: "/images/exposiciones/universos-personales-2025.webp",
      link_url: "https://example.com/programa",
      link_text: "Ver programa",
      position: 3
    }

    assert {:ok, %Exhibition{} = updated} = Exhibitions.update_exhibition(exhibition, attrs)
    assert Map.take(updated, Map.keys(attrs)) == attrs
    assert {:ok, %Exhibition{}} = Exhibitions.delete_exhibition(updated)
    assert_raise Ecto.NoResultsError, fn -> Exhibitions.get_exhibition!(exhibition.id) end
  end

  test "requires exhibition content and leaves invalid updates unchanged" do
    assert {:error, changeset} = Exhibitions.create_exhibition(%{})

    for field <- [:title, :date, :location, :photo, :image_alt, :description] do
      assert "can't be blank" in Map.fetch!(errors_on(changeset), field)
    end

    {:ok, exhibition} = Exhibitions.create_exhibition(@valid_attrs)
    assert {:error, changeset} = Exhibitions.update_exhibition(exhibition, %{title: ""})
    assert "can't be blank" in errors_on(changeset).title
    assert Exhibitions.get_exhibition!(exhibition.id).title == exhibition.title

    assert {:error, changeset} =
             Exhibitions.create_exhibition(Map.put(@valid_attrs, :position, "first"))

    assert "is invalid" in errors_on(changeset).position
  end

  test "accepts only local exhibition images" do
    for photo <- ["https://example.com/photo.webp", "/uploads/pieces/photo.webp", "photo.webp"] do
      assert {:error, changeset} =
               Exhibitions.create_exhibition(Map.put(@valid_attrs, :photo, photo))

      assert "debe ser una imagen local" in errors_on(changeset).photo
    end
  end

  test "optional links require HTTPS, a host and a label" do
    for url <- ["http://example.com", "https://", "https:///programa", "/programa"] do
      attrs = Map.merge(@valid_attrs, %{link_url: url, link_text: "Ver programa"})
      assert {:error, changeset} = Exhibitions.create_exhibition(attrs)
      assert "debe ser una URL segura con un dominio" in errors_on(changeset).link_url
    end

    assert {:error, changeset} =
             Exhibitions.create_exhibition(
               Map.put(@valid_attrs, :link_url, "https://example.com")
             )

    assert "can't be blank" in errors_on(changeset).link_text

    assert {:ok, exhibition} =
             Exhibitions.create_exhibition(
               Map.merge(@valid_attrs, %{
                 link_url: "https://example.com",
                 link_text: "Ver programa"
               })
             )

    assert {:error, changeset} = Exhibitions.update_exhibition(exhibition, %{link_text: ""})
    assert "can't be blank" in errors_on(changeset).link_text

    assert {:ok, %Exhibition{link_url: nil, link_text: nil}} =
             Exhibitions.update_exhibition(exhibition, %{link_url: "", link_text: ""})
  end

  test "does not accept seed keys from administrator attributes" do
    assert {:ok, %Exhibition{seed_key: nil} = exhibition} =
             Exhibitions.create_exhibition(
               Map.put(@valid_attrs, :seed_key, "universos-personales-2025")
             )

    assert {:ok, %Exhibition{seed_key: nil}} =
             Exhibitions.update_exhibition(exhibition, %{"seed_key" => "mujeres-creadoras-2025"})
  end

  test "seeds both originals exactly and preserves administrator edits on rerun" do
    assert %{inserted: 2, skipped: 0} = Exhibitions.seed_current_exhibitions!()
    assert [universos, mujeres] = Exhibitions.list_exhibitions()

    assert Map.take(universos, [
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
             :position,
             :seed_key
           ]) == %{
             title: "Universos Personales: Primera Exposición",
             subtitle: nil,
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
             position: 0,
             seed_key: "universos-personales-2025"
           }

    assert Map.take(mujeres, [
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
             :position,
             :seed_key
           ]) == %{
             title: "Mujeres Creadoras 2025: Cuidados",
             subtitle: nil,
             date: "22 y 23 de marzo 2025",
             location: "Ciudad de México",
             opening: "Inicia a las 9am",
             photo: "/images/exposiciones/mujeres-creadoras-2025.webp",
             image_alt: "Mujeres Creadoras 2025: Cuidados",
             description:
               "Exposición que abordó los cuidados desde múltiples dimensiones y narrativas: arte, política, encuentro y compartición.",
             link_url: "https://www.mujerescreadoras.org/",
             link_text: "Visitar Mujeres Creadoras",
             position: 1,
             seed_key: "mujeres-creadoras-2025"
           }

    assert {:ok, edited} =
             Exhibitions.update_exhibition(universos, %{
               title: "Título editado",
               description: "Descripción editada",
               photo: "/uploads/exhibitions/edited.webp",
               position: 7,
               seed_key: "replacement"
             })

    assert edited.seed_key == "universos-personales-2025"
    assert %{inserted: 0, skipped: 2} = Exhibitions.seed_current_exhibitions!()
    assert [unchanged_mujeres, unchanged_edited] = Exhibitions.list_exhibitions()
    assert unchanged_mujeres == mujeres
    assert unchanged_edited == edited
  end

  test "seeds only missing original keys and permits multiple unseeded exhibitions" do
    {:ok, first} = Exhibitions.create_exhibition(@valid_attrs)
    {:ok, second} = Exhibitions.create_exhibition(@valid_attrs)
    assert first.seed_key == nil
    assert second.seed_key == nil
    assert %{inserted: 2, skipped: 0} = Exhibitions.seed_current_exhibitions!()

    original =
      Enum.find(Exhibitions.list_exhibitions(), &(&1.seed_key == "mujeres-creadoras-2025"))

    assert {:ok, _} = Exhibitions.delete_exhibition(original)
    assert %{inserted: 1, skipped: 1} = Exhibitions.seed_current_exhibitions!()
    assert length(Exhibitions.list_exhibitions()) == 4
  end
end
