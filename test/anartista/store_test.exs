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

  test "creates, groups, orders, and toggles pieces" do
    {:ok, first_piece} = Store.create_piece(@valid_attrs)

    {:ok, second_piece} =
      Store.create_piece(
        Map.merge(@valid_attrs, %{
          name: "Mosaico de prueba",
          category: "Piezas únicas",
          technique: "Mosaico en porcelana",
          dimensions: "40x60 cm",
          year: 2026
        })
      )

    assert first_piece.category == "Artesanía"
    assert [latest_piece, _older_piece] = Store.list_pieces()
    assert latest_piece.id == second_piece.id
    assert Store.latest_available_piece().id == second_piece.id
    assert ["Artesanía", "Piezas únicas"] == Store.list_categories()

    assert [{"Artesanía", [artisanal_piece]}, {"Piezas únicas", [unique_piece]}] =
             Store.list_pieces_by_category()

    assert artisanal_piece.id == first_piece.id
    assert unique_piece.id == second_piece.id
    assert unique_piece.technique == "Mosaico en porcelana"
    assert unique_piece.dimensions == "40x60 cm"
    assert unique_piece.year == 2026

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
