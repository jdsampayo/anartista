defmodule Anartista.StoreTest do
  use Anartista.DataCase

  alias Anartista.Store
  alias Anartista.Store.Piece

  @valid_attrs %{
    name: "Collar de prueba",
    description: "Una pieza única para verificar el catálogo.",
    photo: "/uploads/pieces/test-piece.webp",
    price: "1250.00",
    payment_link: "https://buy.stripe.com/test-piece",
    available: true
  }

  test "creates, orders, and toggles pieces" do
    {:ok, first_piece} = Store.create_piece(@valid_attrs)
    {:ok, second_piece} = Store.create_piece(Map.put(@valid_attrs, :name, "Aretes de prueba"))

    assert [latest_piece, _older_piece] = Store.list_pieces()
    assert latest_piece.id == second_piece.id

    assert {:ok, %Piece{available: false}} = Store.toggle_piece_availability(first_piece)

    assert {:ok, %Piece{name: "Collar actualizado"}} =
             Store.update_piece(first_piece, %{name: "Collar actualizado"})
  end

  test "requires a secure payment link" do
    attrs = Map.put(@valid_attrs, :payment_link, "http://example.com/payment")

    assert {:error, changeset} = Store.create_piece(attrs)
    assert "debe ser una URL segura" in errors_on(changeset).payment_link
  end
end
