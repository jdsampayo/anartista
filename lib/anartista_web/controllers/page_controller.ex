defmodule AnartistaWeb.PageController do
  use AnartistaWeb, :controller

  def shop(conn, _params), do: redirect(conn, to: ~p"/")
end
