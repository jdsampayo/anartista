defmodule Anartista.Exhibit do
  @moduledoc """
  Manages persisted exhibit rooms and their ordered, explicitly selected artworks.

  Saving a room replaces its membership only when `artwork_ids` is supplied;
  an empty list clears the room. Artworks may belong to more than one room.
  """

  import Ecto.Query, warn: false

  alias Anartista.Artworks.Artwork
  alias Anartista.Exhibit.{Room, RoomArtwork}
  alias Anartista.Repo

  def room_types do
    [
      {"Sala estándar", "standard"},
      {"Sala amplia", "large"},
      {"Sala cenital", "skylit"}
    ]
  end

  @doc """
  Lists rooms by position and ID, with artworks in membership order.

  A nonempty `:category` filters artworks and omits rooms without matching works.
  Without a category filter, empty rooms are included.
  """
  def list_rooms(opts \\ []) do
    category = Keyword.get(opts, :category)

    rooms =
      Room
      |> order_by([room], asc: room.position, asc: room.id)
      |> Repo.all()
      |> preload_memberships(category)

    if category in [nil, ""] do
      rooms
    else
      Enum.reject(rooms, &(&1.artworks == []))
    end
  end

  def get_room(id) do
    case Repo.get(Room, id) do
      nil -> nil
      room -> preload_memberships(room)
    end
  end

  def get_room!(id) do
    Room
    |> Repo.get!(id)
    |> preload_memberships()
  end

  def create_room(attrs \\ %{}) do
    Repo.transaction(fn -> save_room(%Room{}, attrs, :insert) end)
  end

  def update_room(%Room{id: id}, attrs) do
    Repo.transaction(fn ->
      case Room |> where([room], room.id == ^id) |> lock("FOR UPDATE") |> Repo.one() do
        nil -> Repo.rollback(:not_found)
        room -> room |> preload_memberships() |> save_room(attrs, :update)
      end
    end)
  end

  def delete_room(%Room{} = room) do
    case Repo.delete(room, stale_error_field: :name) do
      {:error, %{errors: [name: {_message, [stale: true]}]}} -> {:error, :not_found}
      result -> result
    end
  end

  def change_room(%Room{} = room, attrs \\ %{}) do
    case if(room.id, do: get_room(room.id), else: room) do
      nil ->
        room
        |> Room.changeset(attrs)
        |> Ecto.Changeset.add_error(:name, "esta sala ya no existe", validation: :room_deleted)

      current ->
        current |> Room.changeset(attrs) |> validate_selection(false)
    end
  end

  defp save_room(room, attrs, action) do
    changeset =
      room
      |> Room.changeset(attrs)
      |> validate_selection(true)

    unless changeset.valid? do
      Repo.rollback(%{changeset | action: action})
    end

    result =
      case action do
        :insert -> Repo.insert(changeset)
        :update -> Repo.update(changeset)
      end

    case result do
      {:ok, saved} ->
        if action == :insert or selection_supplied?(attrs) do
          replace_memberships(saved, Ecto.Changeset.get_field(changeset, :artwork_ids), changeset)
        end

        preload_memberships(saved)

      {:error, errors} ->
        Repo.rollback(errors)
    end
  end

  defp selection_supplied?(attrs) do
    Map.has_key?(attrs, :artwork_ids) or Map.has_key?(attrs, "artwork_ids")
  end

  defp validate_selection(%Ecto.Changeset{valid?: false} = changeset, _lock), do: changeset

  defp validate_selection(changeset, lock?) do
    ids = Ecto.Changeset.get_field(changeset, :artwork_ids)

    query =
      Artwork
      |> where([artwork], artwork.id in ^ids)
      |> order_by([artwork], asc: artwork.id)
      |> select([artwork], artwork.id)

    # Keep selected works alive until the room and every membership are committed.
    query = if lock?, do: lock(query, "FOR KEY SHARE"), else: query
    existing_ids = Repo.all(query)

    if length(existing_ids) == length(ids) do
      changeset
    else
      Ecto.Changeset.add_error(changeset, :artwork_ids, "contiene obras que no existen")
    end
  end

  defp replace_memberships(room, artwork_ids, changeset) do
    RoomArtwork
    |> where([membership], membership.room_id == ^room.id)
    |> Repo.delete_all()

    artwork_ids
    |> Enum.with_index()
    |> Enum.each(fn {artwork_id, position} ->
      result =
        %RoomArtwork{}
        |> RoomArtwork.changeset(%{
          room_id: room.id,
          artwork_id: artwork_id,
          position: position
        })
        |> Repo.insert()

      case result do
        {:ok, _membership} ->
          :ok

        {:error, _errors} ->
          errors =
            changeset
            |> Ecto.Changeset.add_error(
              :artwork_ids,
              "no se pudieron guardar las obras seleccionadas"
            )
            |> Map.put(:action, if(room.id == changeset.data.id, do: :update, else: :insert))

          Repo.rollback(errors)
      end
    end)
  end

  defp preload_memberships(rooms, category \\ nil) do
    memberships =
      from(membership in RoomArtwork,
        join: artwork in assoc(membership, :artwork),
        order_by: [asc: membership.position, asc: membership.id],
        preload: [artwork: artwork]
      )
      |> filter_category(category)

    rooms
    |> Repo.preload([room_artworks: memberships], force: true)
    |> put_artworks()
  end

  defp filter_category(query, category) when category in [nil, ""], do: query

  defp filter_category(query, category) do
    where(query, [_membership, artwork], artwork.category == ^category)
  end

  defp put_artworks(rooms) when is_list(rooms), do: Enum.map(rooms, &put_artworks/1)

  defp put_artworks(%Room{} = room) do
    artworks = Enum.map(room.room_artworks, & &1.artwork)
    %{room | artworks: artworks, artwork_ids: Enum.map(artworks, & &1.id)}
  end
end
