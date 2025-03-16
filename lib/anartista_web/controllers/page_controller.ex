defmodule AnartistaWeb.PageController do
  use AnartistaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def about(conn, _params) do
    render(conn, :about)
  end

  def art(conn, _params) do
    render(conn, :art)
  end

  def contact(conn, _params) do
    render(conn, :contact)
  end
end
