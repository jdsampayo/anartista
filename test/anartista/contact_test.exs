defmodule Anartista.ContactTest do
  use Anartista.DataCase

  alias Anartista.Contact
  alias Anartista.Contact.Message

  @valid_attrs %{
    name: "Ana Pérez",
    email: "ana@example.com",
    subject: "Consulta",
    message: "Me interesa conocer más sobre esta obra."
  }

  test "creates, orders, toggles, and deletes messages" do
    {:ok, unread_message} = Contact.create_message(@valid_attrs)

    {:ok, second_message} =
      Contact.create_message(Map.merge(@valid_attrs, %{email: "lector@example.com", read: true}))

    assert unread_message.read == false
    assert second_message.read == false
    assert Message.changeset(%Message{}, Map.put(@valid_attrs, :read, true)).changes.read == true
    assert [latest_message, older_message] = Contact.list_messages()
    assert latest_message.id == second_message.id
    assert older_message.id == unread_message.id

    assert {:ok, %Message{read: true}} = Contact.toggle_message_read(unread_message)
    assert {:ok, %Message{}} = Contact.delete_message(second_message)
    assert [remaining_message] = Contact.list_messages()
    assert remaining_message.id == unread_message.id
  end
end
