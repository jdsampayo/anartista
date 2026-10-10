defmodule Mix.Tasks.Anartista.CreateAdmin do
  use Mix.Task

  @shortdoc "Creates an administrator using a concealed password prompt"
  @moduledoc "Run mix anartista.create_admin EMAIL to provision a local administrator."

  @impl Mix.Task
  def run([email]) do
    Mix.Task.run("app.start")

    password = read_password("Password: ")
    confirmation = read_password("Confirm password: ")

    if password != confirmation,
      do: Mix.raise("Passwords do not match. No administrator created.")

    case Anartista.Accounts.create_user(%{email: email, password: password}) do
      {:ok, user} ->
        Mix.shell().info("Administrator created: #{user.email}")

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
            Enum.reduce(opts, message, fn {key, value}, text ->
              String.replace(text, "%{#{key}}", to_string(value))
            end)
          end)

        details =
          Enum.map_join(errors, "; ", fn {field, messages} ->
            "#{field}: #{Enum.join(messages, ", ")}"
          end)

        Mix.raise("No administrator created. #{details}")
    end
  end

  def run(_args), do: Mix.raise("Usage: mix anartista.create_admin EMAIL")

  defp read_password(prompt) do
    # Erlang ports detach from the controlling terminal, so pass its device explicitly.
    with {terminal, 0} <- System.cmd("ps", ["-o", "tty=", "-p", System.pid()]),
         device = Path.join("/dev", String.trim(terminal)),
         {settings, 0} <- stty("stty -g < \"$1\"", [device]),
         {_, 0} <- stty("stty -echo < \"$1\"", [device]) do
      try do
        case IO.gets(prompt) do
          password when is_binary(password) ->
            password |> String.trim_trailing("\n") |> String.trim_trailing("\r")

          _ ->
            Mix.raise("Could not read password. No administrator created.")
        end
      after
        stty("stty \"$2\" < \"$1\"", [device, String.trim(settings)])
        IO.puts("")
      end
    else
      _ ->
        Mix.raise("A terminal supporting concealed input is required. No administrator created.")
    end
  end

  defp stty(command, args) do
    System.cmd("sh", ["-c", command, "sh" | args], stderr_to_stdout: true)
  end
end
