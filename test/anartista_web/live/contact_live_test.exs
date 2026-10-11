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
    {:ok, page, _html} = live(conn, ~p"/about")
    render_patch(page, ~p"/contact")
    view = find_live_child(page, "contact-form")

    assert render_submit(view, "save", %{"message" => Map.put(@message_params, "read", "true")}) =~
             "¡Gracias por tu mensaje!"

    assert [%{read: false}] = Contact.list_messages()
  end

  test "the contact form validates after navigation and resets on a later visit", %{conn: conn} do
    {:ok, page, _html} = live(conn, ~p"/")
    render_patch(page, ~p"/contact")
    form = find_live_child(page, "contact-form")

    form
    |> element("form")
    |> render_submit(%{"message" => Map.put(@message_params, "email", "invalid")})

    assert Contact.list_messages() == []
    assert has_element?(form, "input[name='message[email]'][value='invalid']")
    refute has_element?(form, "[role=alert]")

    form |> element("form") |> render_submit(%{"message" => @message_params})
    assert has_element?(form, "[role=alert]")
    assert [%{email: "ana@example.com"}] = Contact.list_messages()

    render_patch(page, ~p"/about")
    render_patch(page, ~p"/contact")
    fresh_form = find_live_child(page, "contact-form")
    assert has_element?(fresh_form, "form")
    refute has_element?(fresh_form, "[role=alert]")
    refute has_element?(fresh_form, "input[name='message[email]'][value='invalid']")
  end
end
