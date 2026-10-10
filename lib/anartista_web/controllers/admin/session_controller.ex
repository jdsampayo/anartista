defmodule AnartistaWeb.Admin.SessionController do
  use AnartistaWeb, :controller

  alias Anartista.Accounts
  alias AnartistaWeb.AdminAuth

  plug(:redirect_authenticated_user when action in [:new, :create])

  def new(conn, _params) do
    render_login(conn, "", nil)
  end

  def create(conn, params) do
    credentials = params["user"]
    email = if is_map(credentials), do: credentials["email"]
    password = if is_map(credentials), do: credentials["password"]

    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        render_login(conn, display_email(email), "Correo electrónico o contraseña incorrectos.")

      user ->
        AdminAuth.log_in_user(conn, user)
    end
  end

  def delete(conn, _params) do
    AdminAuth.log_out_user(conn)
  end

  defp redirect_authenticated_user(conn, _opts) do
    if conn.assigns.current_user do
      conn
      |> redirect(to: ~p"/admin")
      |> halt()
    else
      conn
    end
  end

  defp render_login(conn, email, error) do
    render(conn, :new,
      page_title: "Iniciar sesión",
      form: Phoenix.Component.to_form(%{"email" => email}, as: :user),
      error: error
    )
  end

  defp display_email(email) when is_binary(email) and byte_size(email) <= 254, do: email
  defp display_email(_email), do: ""
end
