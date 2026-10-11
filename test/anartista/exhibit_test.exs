defmodule Anartista.ExhibitTest do
  use Anartista.DataCase

  alias Anartista.Artworks
  alias Anartista.Exhibit
  alias Anartista.Exhibit.{Room, RoomArtwork}

  test "creates persisted empty rooms with trimmed names and defaults" do
    assert {:ok, %Room{} = room} = Exhibit.create_room(%{name: "  Sala del jardín  "})
    assert room.name == "Sala del jardín"
    assert room.type == "standard"
    assert room.position == 0
    assert room.artworks == []
    assert room.artwork_ids == []
    assert Ecto.assoc_loaded?(room.artworks)
    assert Exhibit.get_room!(room.id) == room
    assert Exhibit.list_rooms() == [room]
  end

  test "persists string and integer IDs in selection order and deduplicates" do
    first = artwork(%{position: 0})
    second = artwork(%{position: 9})
    third = artwork(%{position: 1})

    assert {:ok, room} =
             Exhibit.create_room(%{
               name: "Sala de objetos",
               type: "skylit",
               artwork_ids: [Integer.to_string(second.id), first.id, third.id, second.id]
             })

    assert room.artworks == [second, first, third]
    assert room.artwork_ids == [second.id, first.id, third.id]
    assert Exhibit.get_room!(room.id) == room
    assert membership_positions(room.id) == [0, 1, 2]
  end

  test "replaces and clears memberships but omitted selection uses fresh persisted state" do
    first = artwork()
    second = artwork()
    third = artwork()
    {:ok, original} = Exhibit.create_room(%{name: "Original", artwork_ids: [first.id]})

    assert {:ok, replaced} =
             Exhibit.update_room(original, %{
               name: "Reemplazada",
               artwork_ids: [third.id, second.id]
             })

    assert replaced.artwork_ids == [third.id, second.id]
    assert replaced.artworks == [third, second]
    assert membership_positions(original.id) == [0, 1]

    assert {:ok, renamed} = Exhibit.update_room(original, %{name: "Nombre nuevo"})
    assert renamed.artwork_ids == [third.id, second.id]
    assert Exhibit.change_room(original).data.artwork_ids == [third.id, second.id]

    assert {:ok, cleared} = Exhibit.update_room(original, %{"artwork_ids" => []})
    assert cleared.artworks == []
    assert cleared.artwork_ids == []
    assert membership_positions(original.id) == []
    assert Artworks.get_artwork!(first.id) == first
    assert Artworks.get_artwork!(second.id) == second
    assert Artworks.get_artwork!(third.id) == third
  end

  test "rejects malformed and missing selections without saving room or membership changes" do
    selected = artwork()
    missing = artwork()
    {:ok, _} = Artworks.delete_artwork(missing)
    {:ok, room} = Exhibit.create_room(%{name: "Sin cambios", artwork_ids: [selected.id]})

    for selection <- [
          nil,
          "",
          Integer.to_string(selected.id),
          [""],
          [nil],
          ["not-an-id"],
          ["1x"],
          [0],
          [-1],
          [1.5],
          [%{}],
          [9_223_372_036_854_775_808],
          [selected.id, missing.id]
        ] do
      attrs = %{name: "No debe guardarse", type: "large", artwork_ids: selection}
      assert {:error, changeset} = Exhibit.update_room(room, attrs)
      assert Map.has_key?(errors_on(changeset), :artwork_ids)
      assert Exhibit.get_room!(room.id) == room
      assert membership_positions(room.id) == [0]
      assert {:error, changeset} = Exhibit.create_room(attrs)
      assert Map.has_key?(errors_on(changeset), :artwork_ids)
      assert Exhibit.list_rooms() == [room]
    end

    assert Map.has_key?(
             errors_on(Exhibit.change_room(room, %{artwork_ids: [missing.id]})),
             :artwork_ids
           )
  end

  test "a selection deleted since the editor opened returns errors and rolls back metadata" do
    retained = artwork()
    removed = artwork()
    {:ok, room} = Exhibit.create_room(%{name: "Sala original", artwork_ids: [retained.id]})
    {:ok, _} = Artworks.delete_artwork(removed)

    assert {:error, changeset} =
             Exhibit.update_room(room, %{
               name: "Cambio rechazado",
               position: 4,
               artwork_ids: [removed.id, retained.id]
             })

    assert Map.has_key?(errors_on(changeset), :artwork_ids)
    assert Exhibit.get_room!(room.id) == room
  end

  test "invalid metadata cannot replace existing membership" do
    first = artwork()
    second = artwork()
    {:ok, room} = Exhibit.create_room(%{name: "Sala", artwork_ids: [first.id]})

    for attrs <- [
          %{name: "   "},
          %{name: nil},
          %{name: String.duplicate("a", 201)},
          %{type: "unknown"},
          %{type: "divided"},
          %{type: nil},
          %{position: nil},
          %{position: -1},
          %{position: "first"},
          %{position: 2_147_483_648}
        ] do
      assert {:error, _} =
               Exhibit.update_room(room, Map.put(attrs, :artwork_ids, [second.id]))

      assert Exhibit.get_room!(room.id) == room
    end

    assert {:error, changeset} = Exhibit.create_room(%{})
    assert "can't be blank" in errors_on(changeset).name

    for {_label, type} <- Exhibit.room_types() do
      assert {:ok, bounded} =
               Exhibit.create_room(%{
                 name: String.duplicate("a", 200),
                 type: type,
                 position: 2_147_483_647
               })

      assert bounded.type == type
      assert bounded.position == 2_147_483_647
    end
  end

  test "orders rooms and memberships independently from archive ordering" do
    first = artwork(%{position: 9})
    second = artwork(%{position: 0})
    {:ok, earlier} = Exhibit.create_room(%{name: "Primera", position: 2})
    {:ok, later} = Exhibit.create_room(%{name: "Segunda", position: 2})

    {:ok, leading} =
      Exhibit.create_room(%{name: "Inicio", position: 0, artwork_ids: [first.id, second.id]})

    assert Enum.map(Exhibit.list_rooms(), & &1.id) == [leading.id, earlier.id, later.id]
    assert Exhibit.get_room!(leading.id).artworks == [first, second]

    Repo.update_all(from(m in RoomArtwork, where: m.room_id == ^leading.id),
      set: [position: 0]
    )

    assert Exhibit.get_room!(leading.id).artwork_ids == [first.id, second.id]
  end

  test "category filtering narrows memberships without altering persisted selections" do
    mosaic = artwork(%{category: "Mosaico"})
    painting = artwork(%{category: "Pintura"})
    another = artwork(%{category: "Mosaico"})

    {:ok, mixed} =
      Exhibit.create_room(%{
        name: "Sala mixta",
        artwork_ids: [mosaic.id, painting.id, another.id]
      })

    {:ok, only_painting} =
      Exhibit.create_room(%{name: "Pintura", artwork_ids: [painting.id]})

    {:ok, empty} = Exhibit.create_room(%{name: "Vacía"})

    assert [filtered] = Exhibit.list_rooms(category: "Mosaico")
    assert filtered.id == mixed.id
    assert filtered.artworks == [mosaic, another]
    assert filtered.artwork_ids == [mosaic.id, another.id]

    assert Enum.map(Exhibit.list_rooms(category: "Pintura"), & &1.id) ==
             [mixed.id, only_painting.id]

    assert Exhibit.list_rooms(category: "mosaico") == []
    assert Exhibit.list_rooms(category: "No existe") == []
    assert Exhibit.list_rooms() == [mixed, only_painting, empty]
    assert Exhibit.list_rooms(category: nil) == Exhibit.list_rooms()
    assert Exhibit.list_rooms(category: "") == Exhibit.list_rooms()
    assert Exhibit.get_room!(mixed.id) == mixed
    assert Artworks.list_categories() == ["Mosaico", "Pintura"]
  end

  test "shares artwork across rooms and cascades room deletion without deleting artwork" do
    shared = artwork()
    {:ok, first} = Exhibit.create_room(%{name: "Una", artwork_ids: [shared.id]})
    {:ok, second} = Exhibit.create_room(%{name: "Otra", artwork_ids: [shared.id]})

    assert {:ok, %Room{}} = Exhibit.delete_room(first)
    assert_raise Ecto.NoResultsError, fn -> Exhibit.get_room!(first.id) end
    assert membership_positions(first.id) == []
    assert Exhibit.get_room!(second.id).artworks == [shared]
    assert Artworks.get_artwork!(shared.id) == shared

    assert {:ok, _} = Artworks.delete_artwork(shared)
    assert Exhibit.get_room!(second.id).artworks == []
    assert Exhibit.get_room!(second.id).artwork_ids == []
    assert membership_positions(second.id) == []
  end

  test "database rejects duplicate and missing membership references with changeset errors" do
    selected = artwork()
    {:ok, room} = Exhibit.create_room(%{name: "Sala", artwork_ids: [selected.id]})

    duplicate =
      RoomArtwork.changeset(%RoomArtwork{}, %{
        room_id: room.id,
        artwork_id: selected.id,
        position: 1
      })

    assert {:error, changeset} = Repo.insert(duplicate, mode: :savepoint)
    assert Map.has_key?(errors_on(changeset), :room_id)

    removed = artwork()
    {:ok, _} = Artworks.delete_artwork(removed)

    invalid_artwork =
      RoomArtwork.changeset(%RoomArtwork{}, %{
        room_id: room.id,
        artwork_id: removed.id,
        position: 1
      })

    assert {:error, changeset} = Repo.insert(invalid_artwork, mode: :savepoint)
    assert Map.has_key?(errors_on(changeset), :artwork_id)

    {:ok, removed_room} = Exhibit.create_room(%{name: "Temporal"})
    {:ok, _} = Exhibit.delete_room(removed_room)

    invalid_room =
      RoomArtwork.changeset(%RoomArtwork{}, %{
        room_id: removed_room.id,
        artwork_id: selected.id,
        position: 1
      })

    assert {:error, changeset} = Repo.insert(invalid_room, mode: :savepoint)
    assert Map.has_key?(errors_on(changeset), :room_id)
    assert Exhibit.get_room!(room.id) == room
  end

  test "supports more than five selected artworks and never auto-selects new archive entries" do
    artworks = Enum.map(1..12, fn position -> artwork(%{position: position}) end)
    ids = Enum.map(artworks, & &1.id)
    {:ok, room} = Exhibit.create_room(%{name: "Sala amplia", type: "large", artwork_ids: ids})
    assert room.artworks == artworks
    assert room.artwork_ids == ids
    assert membership_positions(room.id) == Enum.to_list(0..11)

    new_artwork = artwork()
    assert Exhibit.get_room!(room.id) == room
    refute new_artwork.id in Exhibit.get_room!(room.id).artwork_ids
  end

  defp artwork(attrs \\ %{}) do
    {:ok, artwork} =
      Artworks.create_artwork(
        Map.merge(
          %{
            title: "Fragmentos",
            category: "Mosaico",
            photo: "/uploads/artworks/fragmentos.webp",
            image_alt: "Superficie de teselas"
          },
          attrs
        )
      )

    artwork
  end

  defp membership_positions(room_id) do
    RoomArtwork
    |> where([membership], membership.room_id == ^room_id)
    |> order_by([membership], asc: membership.position, asc: membership.id)
    |> select([membership], membership.position)
    |> Repo.all()
  end
end
