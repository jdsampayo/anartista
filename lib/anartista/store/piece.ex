defmodule Anartista.Store.Piece do
  use Ecto.Schema

  import Ecto.Changeset

  schema "pieces" do
    field :name, :string
    field :description, :string
    field :category, :string, default: "Artesanía"
    field :photo, :string
    field :price, :decimal
    field :payment_link, :string
    field :available, :boolean, default: true
    field :technique, :string
    field :dimensions, :string
    field :year, :integer

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(piece, attrs) do
    piece
    |> cast(attrs, [:name, :description, :category, :photo, :price, :payment_link, :available, :technique, :dimensions, :year])
    |> update_change(:category, &String.trim/1)
    |> validate_required([:name, :description, :category, :photo, :price, :payment_link])
    |> validate_length(:name, max: 120)
    |> validate_length(:category, max: 100)
    |> validate_length(:description, max: 2_000)
    |> validate_length(:technique, max: 255)
    |> validate_length(:dimensions, max: 100)
    |> validate_number(:year, greater_than: 0, less_than_or_equal_to: 9_999)
    |> validate_number(:price, greater_than: 0)
    |> validate_format(:payment_link, ~r/^https:\/\//, message: "debe ser una URL segura")
  end
end
