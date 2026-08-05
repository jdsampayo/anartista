defmodule Anartista.Contact do
  @moduledoc """
  Context for handling contact messages.
  """

  import Ecto.Query, warn: false
  alias Anartista.Repo
  alias Anartista.Contact.Message

  @doc """
  Returns the list of contact messages.

  ## Examples

      iex> list_messages()
      [%Message{}, ...]

  """
  def list_messages do
    Message
    |> order_by([message], desc: message.inserted_at, desc: message.id)
    |> Repo.all()
  end

  @doc """
  Gets a single message.

  Raises `Ecto.NoResultsError` if the message does not exist.

  ## Examples

      iex> get_message!(123)
      %Message{}

      iex> get_message!(456)
      ** (Ecto.NoResultsError)

  """
  def get_message!(id), do: Repo.get!(Message, id)

  @doc """
  Creates a message.

  ## Examples

      iex> create_message(%{field: value})
      {:ok, %Message{}}

      iex> create_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_message(attrs \\ %{}) do
    attrs = Map.drop(attrs, [:read, "read"])

    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  def toggle_message_read(%Message{} = message) do
    message
    |> Message.changeset(%{read: !message.read})
    |> Repo.update()
  end

  def delete_message(%Message{} = message), do: Repo.delete(message)

  @doc """
  Returns an empty changeset for the contact form.
  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end
end
