defmodule AnartistaWeb.Admin.MessagesLiveTest do
  use AnartistaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Anartista.{Accounts, Contact}

  @message_attrs %{
    name: "Ana Pérez",
    email: "ana@example.com",
    subject: "Consulta sobre mosaico",
    message: "Me interesa conocer más sobre esta obra.",
    read: false
  }

  test "GET /admin/messages redirects unauthenticated visitors to login", %{conn: conn} do
    conn = get(conn, ~p"/admin/messages")

    assert redirected_to(conn) == "/admin/login"
    assert get_session(conn, :user_return_to) == "/admin/messages"
    assert get_resp_header(conn, "www-authenticate") == []
  end

  test "admin manages message read status and deletion", %{conn: conn} do
    {:ok, message} = Contact.create_message(@message_attrs)

    conn = register_and_log_in_user(conn)

    assert {:ok, view, html} = live(conn, ~p"/admin/messages")
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

  test "revoking a session prevents a connected administrator from changing messages", %{conn: conn} do
    {:ok, message} = Contact.create_message(@message_attrs)
    conn = register_and_log_in_user(conn)
    token = get_session(conn, :user_token)
    assert {:ok, view, _html} = live(conn, ~p"/admin/messages")

    :ok = Accounts.delete_user_session_token(token)
    render_click(view, "toggle-read", %{"id" => message.id})

    assert_redirect(view, "/admin/login")
    refute Contact.get_message!(message.id).read
  end
end
