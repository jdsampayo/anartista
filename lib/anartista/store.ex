defmodule Anartista.Store do
  @moduledoc """
  Context for managing one-of-a-kind store pieces.
  """

  import Ecto.Query, warn: false

  alias Anartista.Repo
  alias Anartista.Store.Piece

  def list_pieces do
    Piece
    |> order_by([piece], desc: piece.inserted_at, desc: piece.id)
    |> Repo.all()
  end

  def get_piece!(id), do: Repo.get!(Piece, id)

  def create_piece(attrs \\ %{}) do
    %Piece{}
    |> Piece.changeset(attrs)
    |> Repo.insert()
  end

  def update_piece(%Piece{} = piece, attrs) do
    piece
    |> Piece.changeset(attrs)
    |> Repo.update()
  end

  def delete_piece(%Piece{} = piece), do: Repo.delete(piece)

  def change_piece(%Piece{} = piece, attrs \\ %{}) do
    Piece.changeset(piece, attrs)
  end

  def toggle_piece_availability(%Piece{} = piece) do
    update_piece(piece, %{available: not piece.available})
  end
end
