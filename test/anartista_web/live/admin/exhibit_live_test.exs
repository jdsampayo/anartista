defmodule AnartistaWeb.Admin.ExhibitLiveTest do
  use AnartistaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Anartista.{Accounts, Artworks, Exhibit}

  test "rooms create, edit and delete without deleting their artworks", %{conn: conn} do
    first = create_artwork("Primera obra", "Pintura")
    second = create_artwork("Segunda obra", "Grabado")
    {:ok, other_room} = Exhibit.create_room(%{name: "Otra sala", artwork_ids: [first.id]})
    {:ok, view, _html} = conn |> register_and_log_in_user() |> live(~p"/admin/exhibit")

    view
    |> form("#room-form",
      room: %{name: "Sala de luz", type: "large", position: 3, artwork_ids: [first.id, second.id]}
    )
    |> render_submit()

    room = Enum.find(Exhibit.list_rooms(), &(&1.name == "Sala de luz"))
    assert room.type == "large"
    assert room.position == 3
    assert artwork_ids(room) == [first.id, second.id]
    refute has_element?(view, "#room_name[value='Sala de luz']")
    refute has_element?(view, "#room-artworks input:checked")

    edit(view, room)
    assert has_element?(view, "#room-artwork-#{first.id}[checked]")
    assert has_element?(view, "#room-artwork-#{second.id}[checked]")

    view
    |> form("#room-form",
      room: %{name: "Sala cenital", type: "skylit", position: 1, artwork_ids: [second.id]}
    )
    |> render_submit()

    updated = Exhibit.get_room!(room.id)
    assert updated.name == "Sala cenital"
    assert updated.type == "skylit"
    assert updated.position == 1
    assert artwork_ids(updated) == [second.id]

    edit(view, updated)
    view |> element("#room-#{room.id} button[phx-click=delete]") |> render_click()
    assert Enum.map(Exhibit.list_rooms(), & &1.id) == [other_room.id]
    assert artwork_ids(Exhibit.get_room!(other_room.id)) == [first.id]
    assert Artworks.get_artwork!(first.id).id == first.id
    assert Artworks.get_artwork!(second.id).id == second.id
    refute has_element?(view, "#room_name[value='Sala cenital']")
  end

  test "validation retains selected works and saves the corrected fields together", %{conn: conn} do
    artwork = create_artwork("Obra a conservar", "Ensamblaje")
    {:ok, view, _html} = conn |> register_and_log_in_user() |> live(~p"/admin/exhibit")

    view
    |> form("#room-form",
      room: %{name: "", type: "large", position: 2, artwork_ids: [artwork.id]}
    )
    |> render_change()

    assert has_element?(
             view,
             "#room_name[aria-invalid=true][aria-describedby='room_name-errors']"
           )

    assert has_element?(view, "#room_name-errors [role=alert]")
    assert has_element?(view, "#room-artwork-#{artwork.id}[checked]")
    assert has_element?(view, "#room_type option[value=large][selected]")
    assert Exhibit.list_rooms() == []

    view |> form("#room-form", room: %{name: "Sala válida", position: -1}) |> render_submit()
    assert has_element?(view, "#room_position[aria-invalid=true]")
    assert has_element?(view, "#room_position-errors [role=alert]")
    assert has_element?(view, "#room-artwork-#{artwork.id}[checked]")
    assert Exhibit.list_rooms() == []

    view |> form("#room-form", room: %{position: 2}) |> render_submit()
    [room] = Exhibit.list_rooms()
    assert room.name == "Sala válida"
    assert room.type == "large"
    assert room.position == 2
    assert artwork_ids(room) == [artwork.id]
  end

  test "malformed and missing artwork IDs and invalid room types cannot mutate a room", %{
    conn: conn
  } do
    artwork = create_artwork("Obra protegida", "Pintura")
    {:ok, room} = Exhibit.create_room(%{name: "Original", artwork_ids: [artwork.id]})
    {:ok, view, _html} = conn |> register_and_log_in_user() |> live(~p"/admin/exhibit")
    edit(view, room)

    for ids <- [["no-es-un-id"], ["2147483647"], [%{"unexpected" => "value"}], "no-es-una-lista"] do
      render_submit(view, "save", %{
        "room" => %{"name" => "No guardar", "artwork_ids" => ids}
      })

      assert has_element?(view, "#room_artwork_ids-errors [role=alert]")

      assert has_element?(
               view,
               "fieldset[aria-invalid=true][aria-describedby='room-artworks-help room_artwork_ids-errors']"
             )

      assert Exhibit.get_room!(room.id).name == "Original"
      assert artwork_ids(Exhibit.get_room!(room.id)) == [artwork.id]
    end

    render_submit(view, "save", %{
      "room" => %{"name" => "No guardar", "type" => "unknown", "artwork_ids" => [artwork.id]}
    })

    assert has_element?(view, "#room_type[aria-invalid=true]")
    assert has_element?(view, "#room_type-errors [role=alert]")
    assert has_element?(view, "#room-artwork-#{artwork.id}[checked]")
    assert Exhibit.get_room!(room.id).name == "Original"
  end

  test "the empty checkbox sentinel clears all works and empty rooms remain editable", %{
    conn: conn
  } do
    artwork = create_artwork("Obra para quitar", "Pintura")
    {:ok, room} = Exhibit.create_room(%{name: "Sala vacía", artwork_ids: [artwork.id]})
    {:ok, view, _html} = conn |> register_and_log_in_user() |> live(~p"/admin/exhibit")
    edit(view, room)

    view |> form("#room-form", room: %{artwork_ids: [""]}) |> render_change()
    refute has_element?(view, "#room-artworks input:checked")
    refute has_element?(view, "#room_artwork_ids-errors [role=alert]")
    view |> form("#room-form", room: %{artwork_ids: [""]}) |> render_submit()

    assert artwork_ids(Exhibit.get_room!(room.id)) == []
    assert Artworks.get_artwork!(artwork.id).id == artwork.id
    edit(view, room)
    refute has_element?(view, "#room-artworks input:checked")
  end

  test "switching and cancelling reset the unsaved editor and selection", %{conn: conn} do
    first = create_artwork("Primera", "Pintura")
    second = create_artwork("Segunda", "Grabado")
    {:ok, first_room} = Exhibit.create_room(%{name: "Primera sala", artwork_ids: [first.id]})

    {:ok, second_room} =
      Exhibit.create_room(%{name: "Segunda sala", type: "skylit", artwork_ids: [second.id]})

    {:ok, view, _html} = conn |> register_and_log_in_user() |> live(~p"/admin/exhibit")

    edit(view, first_room)

    view
    |> form("#room-form", room: %{name: "Sin guardar", artwork_ids: [second.id]})
    |> render_change()

    edit(view, second_room)
    assert has_element?(view, "#room_name[value='Segunda sala']")
    assert has_element?(view, "#room_type option[value=skylit][selected]")
    assert has_element?(view, "#room-artwork-#{second.id}[checked]")
    refute has_element?(view, "#room-artwork-#{first.id}[checked]")

    view |> element("#room-form button[phx-click=cancel-edit]") |> render_click()
    refute has_element?(view, "#room_name[value='Segunda sala']")
    refute has_element?(view, "#room-artworks input:checked")
    assert Exhibit.get_room!(first_room.id).name == first_room.name
    assert artwork_ids(Exhibit.get_room!(first_room.id)) == [first.id]
    assert artwork_ids(Exhibit.get_room!(second_room.id)) == [second.id]
  end

  test "the artwork collection has no five-work limit and never adds works automatically", %{
    conn: conn
  } do
    artworks = for index <- 1..7, do: create_artwork("Obra #{index}", "Pintura")
    ids = Enum.map(artworks, & &1.id)
    {:ok, view, _html} = conn |> register_and_log_in_user() |> live(~p"/admin/exhibit")
    assert Exhibit.list_rooms() == []

    view
    |> form("#room-form", room: %{name: "Colección completa", artwork_ids: ids})
    |> render_submit()

    [room] = Exhibit.list_rooms()
    assert artwork_ids(room) == ids

    create_artwork("Nueva obra sin sala", "Grabado")
    assert artwork_ids(Exhibit.get_room!(room.id)) == ids
  end

  test "Exhibit requires session authentication and remembers the requested page", %{conn: conn} do
    conn = get(conn, ~p"/admin/exhibit")
    assert redirected_to(conn) == "/admin/login"
    assert get_session(conn, :user_return_to) == "/admin/exhibit"
  end

  test "revoked sessions cannot save or delete rooms", %{conn: conn} do
    artwork = create_artwork("Obra protegida", "Pintura")
    {:ok, room} = Exhibit.create_room(%{name: "Sala protegida", artwork_ids: [artwork.id]})
    conn = register_and_log_in_user(conn)
    {:ok, view, _html} = live(conn, ~p"/admin/exhibit")
    edit(view, room)
    :ok = Accounts.delete_user_session_token(get_session(conn, :user_token))

    view |> form("#room-form", room: %{name: "No guardar", artwork_ids: [""]}) |> render_submit()
    assert_redirect(view, "/admin/login")
    assert Exhibit.get_room!(room.id).name == room.name
    assert artwork_ids(Exhibit.get_room!(room.id)) == [artwork.id]

    conn = conn |> recycle() |> register_and_log_in_user()
    {:ok, view, _html} = live(conn, ~p"/admin/exhibit")
    :ok = Accounts.delete_user_session_token(get_session(conn, :user_token))
    render_click(view, "delete", %{"id" => room.id})
    assert_redirect(view, "/admin/login")
    assert Exhibit.get_room!(room.id).id == room.id
    assert Artworks.get_artwork!(artwork.id).id == artwork.id
  end

  test "revoked sessions cannot validate, enter or cancel the room editor" do
    {:ok, room} = Exhibit.create_room(%{name: "Sala protegida"})

    for {event, params} <- [
          {"validate", %{"room" => %{"name" => "No validar"}}},
          {"edit", %{"id" => room.id}},
          {"cancel-edit", %{}}
        ] do
      conn = build_conn() |> register_and_log_in_user()
      {:ok, view, _html} = live(conn, ~p"/admin/exhibit")
      :ok = Accounts.delete_user_session_token(get_session(conn, :user_token))
      render_click(view, event, params)
      assert_redirect(view, "/admin/login")
      assert Exhibit.get_room!(room.id).name == room.name
    end
  end

  test "a room deleted by another administrator does not break a stale editor or list", %{
    conn: conn
  } do
    artwork = create_artwork("Obra conservada", "Pintura")
    conn = register_and_log_in_user(conn)

    for event <- ["validate", "save", "edit", "delete"] do
      {:ok, room} = Exhibit.create_room(%{name: "Sala eliminada", artwork_ids: [artwork.id]})
      {:ok, view, _html} = live(conn, ~p"/admin/exhibit")
      if event in ["validate", "save"], do: edit(view, room)
      {:ok, _} = Exhibit.delete_room(room)

      case event do
        "validate" -> render_change(view, "validate", %{"room" => %{"name" => "Sin guardar"}})
        "save" -> render_submit(view, "save", %{"room" => %{"name" => "Sin guardar"}})
        action -> render_click(view, action, %{"id" => room.id})
      end

      assert has_element?(view, "#room-editor [role=alert]")
      refute has_element?(view, "#room-#{room.id}")
      refute has_element?(view, "#room_name[value='Sin guardar']")
      assert Exhibit.list_rooms() == []
      assert Artworks.get_artwork!(artwork.id).id == artwork.id
    end
  end

  defp create_artwork(title, category) do
    {:ok, artwork} =
      Artworks.create_artwork(%{
        title: title,
        category: category,
        photo: "/images/portafolio/grabado.webp",
        image_alt: title
      })

    artwork
  end

  defp artwork_ids(room), do: Enum.map(room.artworks, & &1.id)

  defp edit(view, room) do
    view |> element("#room-#{room.id} button[phx-click=edit]") |> render_click()
  end
end
