defmodule Anartista.Store.Piece do
  use Ecto.Schema

  import Ecto.Changeset

  schema "pieces" do
    field :name, :string
    field :description, :string
    field :photo, :string
    field :price, :decimal
    field :payment_link, :string
    field :available, :boolean, default: true

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(piece, attrs) do
    piece
    |> cast(attrs, [:name, :description, :photo, :price, :payment_link, :available])
    |> validate_required([:name, :description, :photo, :price, :payment_link])
    |> validate_length(:name, max: 120)
    |> validate_length(:description, max: 2_000)
    |> validate_number(:price, greater_than: 0)
    |> validate_format(:payment_link, ~r/^https:\/\//, message: "debe ser una URL segura")
  end
end
