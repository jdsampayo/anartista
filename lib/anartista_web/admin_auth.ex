defmodule AnartistaWeb.AdminAuth do
  @moduledoc "Session authentication for locally provisioned administrators."

  use AnartistaWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Anartista.Accounts

  def fetch_current_user(conn, _opts) do
    user = Accounts.get_user_by_session_token(get_session(conn, :user_token))
    assign(conn, :current_user, user)
  end

  def prevent_caching(conn, _opts) do
    put_resp_header(conn, "cache-control", "no-store")
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns.current_user do
      conn
    else
      conn
      |> put_session(:user_return_to, conn.request_path)
      |> redirect(to: ~p"/admin/login")
      |> halt()
    end
  end

  def log_in_user(conn, user) do
    return_to = get_session(conn, :user_return_to)
    token = Accounts.generate_user_session_token(user)

    conn
    |> revoke_session()
    |> renew_session()
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
    |> redirect(to: return_path(return_to))
  end

  def log_out_user(conn) do
    conn
    |> revoke_session()
    |> renew_session()
    |> redirect(to: ~p"/admin/login")
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    token = session["user_token"]

    case Accounts.get_user_by_session_token(token) do
      nil ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/admin/login")}

      user ->
        socket =
          socket
          |> Phoenix.Component.assign(:current_user, user)
          |> Phoenix.LiveView.attach_hook(:authenticate_admin_event, :handle_event, fn
            _event, _params, socket ->
              if Accounts.get_user_by_session_token(token) do
                {:cont, socket}
              else
                {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/admin/login")}
              end
          end)

        {:cont, socket}
    end
  end

  defp revoke_session(conn) do
    Accounts.delete_user_session_token(get_session(conn, :user_token))

    if live_socket_id = get_session(conn, :live_socket_id) do
      AnartistaWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp return_path(path)
       when path in [
              "/admin",
              "/admin/store",
              "/admin/messages",
              "/admin/exhibitions",
              "/admin/obra"
            ],
       do: path

  defp return_path(_path), do: ~p"/admin"
end
