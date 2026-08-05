defmodule AnartistaWeb.PageController do
  use AnartistaWeb, :controller

  alias Anartista.Store

  def home(conn, _params) do
    render(conn, :home, substack_posts: Anartista.Substack.posts(3))
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

  def shop(conn, _params) do
    render(conn, :shop, pieces_by_category: Store.list_pieces_by_category())
  end
end
