defmodule AnartistaWeb.Admin.DashboardLiveTest do
  use AnartistaWeb.ConnCase

  import Phoenix.LiveViewTest

  test "dashboard requires a session and remembers its return destination", %{conn: conn} do
    conn = get(conn, ~p"/admin")

    assert redirected_to(conn) == "/admin/login"
    assert get_session(conn, :user_return_to) == "/admin"
  end

  test "dashboard links open each protected administration area", %{conn: conn} do
    conn = register_and_log_in_user(conn)

    for path <- [
          ~p"/admin/messages",
          ~p"/admin/store",
          ~p"/admin/exhibitions",
          ~p"/admin/obra",
          ~p"/admin/exhibit"
        ] do
      assert {:ok, view, _html} = live(conn, ~p"/admin")

      assert {:ok, _area_view, _html} =
               view
               |> element("#admin-areas a[href=\"#{path}\"]")
               |> render_click()
               |> follow_redirect(conn, path)
    end
  end
end
