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
    available: true
  }

  @sold_attrs %{
    name: "Aretes vendidos",
    description: "Pieza única vendida.",
    photo: "/uploads/pieces/sold.webp",
    price: "850.00",
    payment_link: "https://buy.stripe.com/sold-piece",
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

  test "GET /store renders available and sold pieces with the correct actions", %{conn: conn} do
    {:ok, _available_piece} = Store.create_piece(@available_attrs)
    {:ok, _sold_piece} = Store.create_piece(@sold_attrs)

    html = conn |> get(~p"/store") |> html_response(200)

    assert html =~ "Collar disponible"
    assert html =~ "Aretes vendidos"
    assert html =~ "Vendida"
    assert html =~ ~s(href="https://buy.stripe.com/available-piece")
    refute html =~ ~s(href="https://buy.stripe.com/sold-piece")
  end

  test "GET /admin/store challenges unauthenticated visitors", %{conn: conn} do
    conn = get(conn, ~p"/admin/store")

    assert response(conn, 401)
    assert [auth_header] = get_resp_header(conn, "www-authenticate")
    assert auth_header =~ "Basic"
  end

  test "GET /admin/store renders the management interface for the configured administrator", %{conn: conn} do
    conn = put_req_header(conn, "authorization", "Basic " <> Base.encode64("admin:secret"))

    assert {:ok, _view, html} = live(conn, ~p"/admin/store")
    assert html =~ "Administrar tienda"
    assert html =~ "Agregar pieza"
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
