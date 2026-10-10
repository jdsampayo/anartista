defmodule Anartista.Repo.Migrations.WidenExhibitionLinkUrls do
  use Ecto.Migration

  def change do
    alter table(:exhibitions) do
      modify(:link_url, :text, from: :string)
    end
  end
end
