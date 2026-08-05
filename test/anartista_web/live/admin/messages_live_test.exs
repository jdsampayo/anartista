defmodule AnartistaWeb.Admin.MessagesLiveTest do
  use AnartistaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Anartista.Contact

  @message_attrs %{
    name: "Ana Pérez",
    email: "ana@example.com",
    subject: "Consulta sobre mosaico",
    message: "Me interesa conocer más sobre esta obra.",
    read: false
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

  test "GET /admin/messages challenges unauthenticated visitors", %{conn: conn} do
    conn = get(conn, ~p"/admin/messages")

    assert response(conn, 401)
    assert [auth_header] = get_resp_header(conn, "www-authenticate")
    assert auth_header =~ "Basic"
  end

  test "admin manages message read status and deletion", %{conn: conn} do
    {:ok, message} = Contact.create_message(@message_attrs)

    conn = put_req_header(conn, "authorization", "Basic " <> Base.encode64("admin:secret"))

    assert {:ok, view, html} = live(conn, ~p"/admin/messages")
    assert html =~ "Mensajes"
    assert html =~ ~s(href="/admin/store")
    assert html =~ "Consulta sobre mosaico"
    assert html =~ "No leído"

    view
    |> element("#message-#{message.id} button[phx-click=\"toggle-read\"]")
    |> render_click()

    assert render(view) =~ "Leído"

    view
    |> element("#message-#{message.id} button[phx-click=\"delete\"]")
    |> render_click()

    refute render(view) =~ "Consulta sobre mosaico"
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
