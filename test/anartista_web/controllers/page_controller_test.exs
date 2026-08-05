defmodule AnartistaWeb.PageControllerTest do
  use AnartistaWeb.ConnCase

  test "GET / renders the canonical storefront empty state", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ "Tienda"
    assert html =~ "No hay piezas publicadas en este momento."
    assert html =~ ~s(href="https://www.gotrendier.mx/u/apalvarezvega")
    assert html =~ "Visitar el bazar de Ana en GoTrendier"
  end

  test "GET secondary routes render their dedicated pages", %{conn: conn} do
    for {path, heading} <- [
          {~p"/about", "Acerca de Ana"},
          {~p"/exhibitions", "Exposiciones"},
          {~p"/writing", "Escritos"},
          {~p"/contact", "Contacto"}
        ] do
      assert conn |> get(path) |> html_response(200) =~ heading
    end
  end
end
