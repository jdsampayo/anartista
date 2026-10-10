defmodule AnartistaWeb.Admin.ExhibitionsLiveTest do
  use AnartistaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Anartista.{Accounts, Exhibitions}

  @long_url "https://example.com/" <>
              String.duplicate("a", 2_000 - byte_size("https://example.com/"))

  @attrs %{
    title: "Exposición de prueba",
    date: "9 de octubre 2026",
    location: "Ciudad de México",
    image_alt: "Cartel de la exposición",
    description: "Obras reunidas en el estudio.",
    position: 0,
    link_url: @long_url,
    link_text: "Ver programa"
  }

  test "long links survive upload and edit while the public archive and photo lifecycle stay consistent",
       %{conn: conn} do
    conn = register_and_log_in_user(conn)
    {:ok, view, _html} = live(conn, ~p"/admin/exhibitions")

    upload =
      file_input(view, "#exhibition-form", :photo, [
        %{
          name: "cartel.webp",
          content:
            File.read!("priv/static/images/exposiciones/mujeres-creadoras-2025_thumb.webp"),
          type: "image/webp"
        }
      ])

    render_upload(upload, "cartel.webp")
    view |> form("#exhibition-form", exhibition: @attrs) |> render_submit()
    [exhibition] = Exhibitions.list_exhibitions()
    photo_path = Path.join(:code.priv_dir(:anartista), "static#{exhibition.photo}")
    on_exit(fn -> File.rm(photo_path) end)
    assert File.exists?(photo_path)
    assert exhibition.link_url == @long_url

    public_html = build_conn() |> get(~p"/exhibitions") |> html_response(200)
    assert public_html =~ @attrs.title
    assert public_html =~ exhibition.photo
    assert public_html =~ ~s(href="#{@long_url}")

    view |> element("#exhibition-#{exhibition.id} button[phx-click=edit]") |> render_click()

    view
    |> form("#exhibition-form", exhibition: %{link_url: @long_url <> "b"})
    |> render_submit()

    assert Exhibitions.get_exhibition!(exhibition.id).link_url == @long_url

    updated_url = String.replace_suffix(@long_url, "a", "b")

    view
    |> form("#exhibition-form",
      exhibition: %{title: "Exposición actualizada", link_url: updated_url}
    )
    |> render_submit()

    updated = Exhibitions.get_exhibition!(exhibition.id)
    assert updated.photo == exhibition.photo
    assert updated.link_url == updated_url
    assert File.exists?(photo_path)
    public_html = build_conn() |> get(~p"/exhibitions") |> html_response(200)
    assert public_html =~ "Exposición actualizada"
    assert public_html =~ ~s(href="#{updated_url}")
    refute public_html =~ @attrs.title

    view |> element("#exhibition-#{exhibition.id} button[phx-click=delete]") |> render_click()
    assert Exhibitions.list_exhibitions() == []
    refute File.exists?(photo_path)
    refute build_conn() |> get(~p"/exhibitions") |> html_response(200) =~ "Exposición actualizada"
  end

  test "invalid submissions retain uploaded photo for correction", %{conn: conn} do
    {:ok, view, _html} = conn |> register_and_log_in_user() |> live(~p"/admin/exhibitions")

    upload =
      file_input(view, "#exhibition-form", :photo, [
        %{
          name: "cartel.webp",
          content:
            File.read!("priv/static/images/exposiciones/mujeres-creadoras-2025_thumb.webp"),
          type: "image/webp"
        }
      ])

    render_upload(upload, "cartel.webp")
    view |> form("#exhibition-form", exhibition: Map.put(@attrs, :title, "")) |> render_submit()
    assert Exhibitions.list_exhibitions() == []
    view |> form("#exhibition-form", exhibition: @attrs) |> render_submit()
    [exhibition] = Exhibitions.list_exhibitions()
    photo_path = Path.join(:code.priv_dir(:anartista), "static#{exhibition.photo}")
    on_exit(fn -> File.rm(photo_path) end)
    assert File.exists?(photo_path)
  end

  test "revoked sessions cannot mutate an exhibition", %{conn: conn} do
    {:ok, exhibition} =
      Exhibitions.create_exhibition(
        Map.put(@attrs, :photo, "/images/exposiciones/mujeres-creadoras-2025.webp")
      )

    conn = register_and_log_in_user(conn)
    {:ok, view, _html} = live(conn, ~p"/admin/exhibitions")
    :ok = Accounts.delete_user_session_token(get_session(conn, :user_token))
    render_click(view, "delete", %{"id" => exhibition.id})
    assert_redirect(view, "/admin/login")
    assert Exhibitions.get_exhibition!(exhibition.id).id == exhibition.id
  end
end
