defmodule AnartistaWeb.ContactLiveTest do
  use AnartistaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Anartista.Contact

  @message_params %{
    "name" => "Ana Pérez",
    "email" => "ana@example.com",
    "subject" => "Consulta sobre mosaico",
    "message" => "Me interesa conocer más sobre esta obra."
  }

  test "contact submissions cannot set the administrative read state", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, AnartistaWeb.ContactLive)

    assert render_submit(view, "save", %{"message" => Map.put(@message_params, "read", "true")}) =~
             "¡Gracias por tu mensaje!"

    assert [%{read: false}] = Contact.list_messages()
  end
end
