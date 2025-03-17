defmodule Anartista.Contact.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "contact_messages" do
    field :name, :string
    field :email, :string
    field :subject, :string
    field :message, :string

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:name, :email, :subject, :message])
    |> validate_required([:name, :email, :subject, :message])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "debe ser un email válido")
    |> validate_length(:message, min: 10, message: "debe tener al menos 10 caracteres")
  end
end
