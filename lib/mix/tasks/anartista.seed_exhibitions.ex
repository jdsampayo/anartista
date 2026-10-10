defmodule Mix.Tasks.Anartista.SeedExhibitions do
  use Mix.Task

  @shortdoc "Preserves the two original exhibitions without overwriting edits"
  @moduledoc """
  Run `mix anartista.seed_exhibitions` after migrating the database.

  For deployment without a web server:

      env -u PHX_SERVER MIX_ENV=prod mix anartista.seed_exhibitions

  Reruns skip existing seed keys and preserve administrator changes.
  """

  @impl Mix.Task
  def run([]) do
    Mix.Task.run("app.start")

    %{inserted: inserted, skipped: skipped} = Anartista.Exhibitions.seed_current_exhibitions!()
    Mix.shell().info("Exhibitions: #{inserted} inserted, #{skipped} skipped.")
  end

  def run(_args), do: Mix.raise("Usage: mix anartista.seed_exhibitions")
end
