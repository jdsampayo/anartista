defmodule AnartistaWeb.Plugs.AdminBasicAuth do
  @behaviour Plug

  @impl Plug
  def init(options), do: options

  @impl Plug
  def call(conn, _options) do
    Plug.BasicAuth.basic_auth(conn, credentials())
  end

  defp credentials do
    case {System.get_env("ADMIN_USER"), System.get_env("ADMIN_PASS")} do
      {username, password} when is_binary(username) and byte_size(username) > 0 and is_binary(password) and byte_size(password) > 0 ->
        [username: username, password: password]

      _ ->
        raise "ADMIN_USER and ADMIN_PASS must be configured before accessing /admin"
    end
  end
end
