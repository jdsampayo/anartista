defmodule Mix.Tasks.Anartista.SeedArtworks do
  use Mix.Task

  @shortdoc "Preserves the three original selected works without overwriting edits"
  @moduledoc """
  Run `mix anartista.seed_artworks` after migrating the database.

  For deployment without a web server:

      env -u PHX_SERVER MIX_ENV=prod mix anartista.seed_artworks

  Reruns skip existing seed keys and preserve administrator changes.
  """

  @impl Mix.Task
  def run([]) do
    Mix.Task.run("app.start")

    %{inserted: inserted, skipped: skipped} = Anartista.Artworks.seed_current_artworks!()
    Mix.shell().info("Artworks: #{inserted} inserted, #{skipped} skipped.")
  end

  def run(_args), do: Mix.raise("Usage: mix anartista.seed_artworks")
end
