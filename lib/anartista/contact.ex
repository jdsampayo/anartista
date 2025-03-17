# lib/anartista/contact.ex
defmodule Anartista.Contact do
  @moduledoc """
  Contexto para manejar los mensajes de contacto.
  """

  import Ecto.Query, warn: false
  alias Anartista.Repo
  alias Anartista.Contact.Message

  @doc """
  Devuelve la lista de mensajes de contacto.

  ## Ejemplos

      iex> list_messages()
      [%Message{}, ...]

  """
  def list_messages do
    Repo.all(Message)
  end

  @doc """
  Obtiene un único mensaje.

  Genera `Ecto.NoResultsError` si el mensaje no existe.

  ## Ejemplos

      iex> get_message!(123)
      %Message{}

      iex> get_message!(456)
      ** (Ecto.NoResultsError)

  """
  def get_message!(id), do: Repo.get!(Message, id)

  @doc """
  Crea un mensaje.

  ## Ejemplos

      iex> create_message(%{field: value})
      {:ok, %Message{}}

      iex> create_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Devuelve un changeset vacío para el formulario de contacto.
  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end
end
