defmodule AnartistaWeb.StoreControllerTest do
  use AnartistaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Anartista.{Accounts, Repo, Store}
  alias Anartista.Accounts.UserToken

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

  test "GET /admin/store redirects unauthenticated visitors to login", %{conn: conn} do
    conn = get(conn, ~p"/admin/store")

    assert redirected_to(conn) == "/admin/login"
    assert get_session(conn, :user_return_to) == "/admin/store"
    assert get_resp_header(conn, "www-authenticate") == []
  end

  test "GET /admin/store renders the management interface for a logged-in administrator", %{conn: conn} do
    {:ok, _piece} = Store.create_piece(Map.put(@available_attrs, :category, "Stickers"))

    conn = register_and_log_in_user(conn)

    assert {:ok, _view, html} = live(conn, ~p"/admin/store")
    assert html =~ ~s(list="piece-categories")
    assert html =~ ~s(value="Stickers")
  end

  test "an expired session cannot change availability through a connected LiveView", %{conn: conn} do
    {:ok, piece} = Store.create_piece(@available_attrs)
    conn = register_and_log_in_user(conn)
    assert {:ok, view, _html} = live(conn, ~p"/admin/store")

    expired_at = NaiveDateTime.add(NaiveDateTime.utc_now(:second), -8, :day)
    Repo.update_all(UserToken, set: [inserted_at: expired_at])
    render_click(view, "toggle-availability", %{"id" => piece.id})

    assert_redirect(view, "/admin/login")
    assert Store.get_piece!(piece.id).available
    assert Accounts.get_user_by_session_token(get_session(conn, :user_token)) == nil
  end
end
