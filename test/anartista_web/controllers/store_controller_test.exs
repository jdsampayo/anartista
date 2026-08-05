defmodule AnartistaWeb.StoreControllerTest do
  use AnartistaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Anartista.Store

  @available_attrs %{
    name: "Collar disponible",
    description: "Pieza única disponible.",
    photo: "/uploads/pieces/available.webp",
    price: "1250.00",
    payment_link: "https://buy.stripe.com/available-piece",
    category: "Artesanía",
    available: true
  }

  @sold_attrs %{
    name: "Aretes vendidos",
    description: "Pieza única vendida.",
    photo: "/uploads/pieces/sold.webp",
    price: "850.00",
    payment_link: "https://buy.stripe.com/sold-piece",
    category: "Piezas únicas",
    technique: "Mosaico en porcelana",
    dimensions: "40x60 cm",
    year: 2026,
    available: false
  }

  setup do
    original_user = System.get_env("ADMIN_USER")
    original_password = System.get_env("ADMIN_PASS")
    System.put_env("ADMIN_USER", "admin")
    System.put_env("ADMIN_PASS", "secret")

    on_exit(fn ->
      restore_env("ADMIN_USER", original_user)
      restore_env("ADMIN_PASS", original_password)
    end)

    :ok
  end

  test "GET / renders the storefront and /store redirects to its canonical route", %{conn: conn} do
    {:ok, _available_piece} = Store.create_piece(@available_attrs)
    {:ok, _sold_piece} = Store.create_piece(@sold_attrs)

    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ "Collar disponible"
    assert html =~ "Aretes vendidos"
    assert html =~ "Vendida"
    assert html =~ "Artesanía"
    assert html =~ "Piezas únicas"
    assert html =~ "Mosaico en porcelana"
    assert html =~ "40x60 cm"
    assert html =~ "2026"
    assert html =~ ~s(href="https://buy.stripe.com/available-piece")
    refute html =~ ~s(href="https://buy.stripe.com/sold-piece")

    conn = get(conn, ~p"/store")
    assert redirected_to(conn) == "/"
  end

  test "GET /admin/store challenges unauthenticated visitors", %{conn: conn} do
    conn = get(conn, ~p"/admin/store")

    assert response(conn, 401)
    assert [auth_header] = get_resp_header(conn, "www-authenticate")
    assert auth_header =~ "Basic"
  end

  test "GET /admin/store renders the management interface for the configured administrator", %{conn: conn} do
    {:ok, _piece} = Store.create_piece(Map.put(@available_attrs, :category, "Stickers"))

    conn = put_req_header(conn, "authorization", "Basic " <> Base.encode64("admin:secret"))

    assert {:ok, _view, html} = live(conn, ~p"/admin/store")
    assert html =~ "Administrar tienda"
    assert html =~ ~s(href="/admin/messages")
    assert html =~ "Agregar pieza"
    assert html =~ ~s(list="piece-categories")
    assert html =~ ~s(value="Stickers")
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
