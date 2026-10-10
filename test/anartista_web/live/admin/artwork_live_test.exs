defmodule AnartistaWeb.Admin.ArtworkLiveTest do
  use AnartistaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Anartista.{Accounts, Artworks}

  @attrs %{
    title: "Fragmentos del estudio",
    category: "Ensamblaje experimental",
    image_alt: "Fragmentos sobre una mesa",
    description: "Una composición del estudio.",
    year: "2024–2026",
    technique: "Ensamblaje",
    materials: "Vidrio y cerámica",
    dimensions: "30 × 40 cm",
    edition: "Pieza única",
    collection: "Colección privada",
    position: 2,
    selected: true
  }

  test "upload, correction, optional labels, selection, replacement and deletion persist together",
       %{conn: conn} do
    {:ok, view, _html} = conn |> register_and_log_in_user() |> live(~p"/admin/obra")
    upload_photo(view, "original.webp")

    view |> form("#artwork-form", artwork: Map.put(@attrs, :title, "")) |> render_submit()
    assert Artworks.list_artworks() == []
    assert has_element?(view, "#artwork_title[aria-invalid=true]")

    view
    |> form("#artwork-form", artwork: Map.put(@attrs, :position, 2_147_483_648))
    |> render_submit()

    assert Artworks.list_artworks() == []
    assert has_element?(view, "#artwork_position[aria-invalid=true]")

    view |> form("#artwork-form", artwork: @attrs) |> render_submit()
    [artwork] = Artworks.list_artworks()
    original_path = uploaded_path(artwork.photo)
    on_exit(fn -> File.rm(original_path) end)
    assert File.exists?(original_path)
    assert String.starts_with?(artwork.photo, "/uploads/artworks/")
    for {field, value} <- @attrs, do: assert(Map.fetch!(artwork, field) == value)
    assert Enum.map(Artworks.list_selected_artworks(), & &1.id) == [artwork.id]

    edit(view, artwork)

    view
    |> form("#artwork-form",
      artwork: %{title: "Fragmentos actualizados", selected: false, category: "  Objeto nuevo  "}
    )
    |> render_submit()

    updated = Artworks.get_artwork!(artwork.id)
    assert updated.title == "Fragmentos actualizados"
    assert updated.category == "Objeto nuevo"
    assert updated.photo == artwork.photo
    assert updated.materials == @attrs.materials
    refute updated.selected
    assert Artworks.list_selected_artworks() == []
    assert Artworks.list_categories() == ["Objeto nuevo"]
    assert File.exists?(original_path)

    edit(view, updated)
    upload_photo(view, "replacement.webp")

    view
    |> form("#artwork-form", artwork: %{selected: true, year: "", edition: ""})
    |> render_submit()

    replaced = Artworks.get_artwork!(artwork.id)
    replacement_path = uploaded_path(replaced.photo)
    on_exit(fn -> File.rm(replacement_path) end)
    assert replaced.photo != artwork.photo
    assert File.exists?(replacement_path)
    refute File.exists?(original_path)
    assert replaced.year == nil
    assert replaced.edition == nil
    assert replaced.selected

    view |> element("#artwork-#{artwork.id} button[phx-click=delete]") |> render_click()
    assert Artworks.list_artworks() == []
    refute File.exists?(replacement_path)
  end

  test "switching or cancelling the editor drops pending uploads without changing seed assets", %{
    conn: conn
  } do
    first = create_artwork("Primera", "/images/portafolio/mosaico.webp")
    second = create_artwork("Segunda", "/images/portafolio/pintura.webp")
    {:ok, view, _html} = conn |> register_and_log_in_user() |> live(~p"/admin/obra")

    edit(view, first)
    upload_photo(view, "discard-switch.webp")
    edit(view, second)
    refute has_element?(view, "button[phx-click=cancel-photo]")
    view |> form("#artwork-form", artwork: %{title: "Segunda editada"}) |> render_submit()
    assert Artworks.get_artwork!(second.id).photo == second.photo
    assert Artworks.get_artwork!(first.id).title == first.title

    edit(view, first)
    upload_photo(view, "discard-cancel.webp")
    view |> element("button[phx-click=cancel-edit]") |> render_click()
    refute has_element?(view, "button[phx-click=cancel-photo]")
    view |> form("#artwork-form", artwork: @attrs) |> render_submit()
    assert length(Artworks.list_artworks()) == 2
    assert has_element?(view, "#artwork_photo-errors [role=alert]")

    edit(view, first)
    upload_photo(view, "replace-seed.webp")
    view |> form("#artwork-form", artwork: %{title: first.title}) |> render_submit()
    replacement = Artworks.get_artwork!(first.id)
    replacement_path = uploaded_path(replacement.photo)
    on_exit(fn -> File.rm(replacement_path) end)
    assert File.exists?(replacement_path)
    assert File.exists?("priv/static#{first.photo}")

    view |> element("#artwork-#{second.id} button[phx-click=delete]") |> render_click()
    assert File.exists?("priv/static#{second.photo}")
    view |> element("#artwork-#{first.id} button[phx-click=delete]") |> render_click()
    refute File.exists?(replacement_path)
  end

  test "revoked sessions cannot save or delete artwork", %{conn: conn} do
    artwork = create_artwork("Protegida", "/images/portafolio/grabado.webp")
    conn = register_and_log_in_user(conn)
    {:ok, view, _html} = live(conn, ~p"/admin/obra")
    edit(view, artwork)
    :ok = Accounts.delete_user_session_token(get_session(conn, :user_token))

    view
    |> form("#artwork-form", artwork: %{title: "No guardar", selected: false})
    |> render_submit()

    assert_redirect(view, "/admin/login")
    assert Artworks.get_artwork!(artwork.id).title == artwork.title
    assert Artworks.get_artwork!(artwork.id).selected

    conn = conn |> recycle() |> register_and_log_in_user()
    {:ok, view, _html} = live(conn, ~p"/admin/obra")
    :ok = Accounts.delete_user_session_token(get_session(conn, :user_token))
    render_click(view, "delete", %{"id" => artwork.id})
    assert_redirect(view, "/admin/login")
    assert Artworks.get_artwork!(artwork.id).id == artwork.id
  end

  defp create_artwork(title, photo) do
    {:ok, artwork} = Artworks.create_artwork(Map.merge(@attrs, %{title: title, photo: photo}))
    artwork
  end

  defp edit(view, artwork) do
    view |> element("#artwork-#{artwork.id} button[phx-click=edit]") |> render_click()
  end

  defp upload_photo(view, name) do
    upload_photo(view, name, "priv/static/images/portafolio/mosaico.webp", "image/webp")
  end

  defp upload_photo(view, name, source, type) do
    upload =
      file_input(view, "#artwork-form", :photo, [
        %{name: name, content: File.read!(source), type: type}
      ])

    render_upload(upload, name)
  end

  defp uploaded_path(photo), do: Path.join(:code.priv_dir(:anartista), "static#{photo}")
end
