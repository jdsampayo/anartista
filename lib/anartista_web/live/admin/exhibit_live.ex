defmodule AnartistaWeb.Admin.ExhibitLive do
  use AnartistaWeb, :live_view

  alias Anartista.{Artworks, Exhibit}
  alias Anartista.Exhibit.Room

  import AnartistaWeb.AdminComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Administrar Exhibit")
     |> assign(:editing_room, nil)
     |> assign(:editor_revision, 0)
     |> assign(:room_types, Exhibit.room_types())
     |> assign(:artworks, Artworks.list_artworks())
     |> refresh_rooms()
     |> assign_form(Exhibit.change_room(%Room{}))}
  end

  @impl true
  def handle_event("validate", %{"room" => params}, socket) do
    changeset =
      socket.assigns.editing_room
      |> editable_room()
      |> Exhibit.change_room(normalize_selection(params))
      |> Map.put(:action, :validate)

    if Enum.any?(changeset.errors, fn {_field, {_message, opts}} ->
         opts[:validation] == :room_deleted
       end),
       do: {:noreply, missing_room(socket)},
       else: {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"room" => params}, socket) do
    case save_room(socket.assigns.editing_room, normalize_selection(params)) do
      {:ok, _room} ->
        {:noreply,
         socket
         |> put_flash(:info, "La sala se guardó. Los cambios ya están publicados en Exhibit.")
         |> reset_editor()
         |> refresh_rooms()}

      {:error, :not_found} ->
        {:noreply, missing_room(socket)}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
    end
  end

  def handle_event("edit", %{"id" => id}, socket) do
    case Exhibit.get_room(id) do
      nil ->
        {:noreply, missing_room(socket)}

      room ->
        {:noreply,
         socket
         |> assign(:editing_room, room)
         |> update(:editor_revision, &(&1 + 1))
         |> assign_form(Exhibit.change_room(room))}
    end
  end

  def handle_event("cancel-edit", _params, socket), do: {:noreply, reset_editor(socket)}

  def handle_event("delete", %{"id" => id}, socket) do
    result =
      case Exhibit.get_room(id) do
        nil -> {:error, :not_found}
        room -> Exhibit.delete_room(room)
      end

    case result do
      {:ok, room} ->
        socket =
          if socket.assigns.editing_room && socket.assigns.editing_room.id == room.id,
            do: reset_editor(socket),
            else: socket

        {:noreply,
         socket
         |> put_flash(:info, "La sala se eliminó. Las obras se conservan en el archivo.")
         |> refresh_rooms()}

      {:error, :not_found} ->
        {:noreply, missing_room(socket)}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "No fue posible eliminar la sala. Inténtalo de nuevo.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_navigation current={:exhibit} />
    <section class="bg-light px-4 py-16 text-dark">
      <div class="mx-auto grid max-w-6xl gap-10 lg:grid-cols-[minmax(0,1fr)_28rem] lg:items-start">
        <div class="min-w-0">
          <div class="border-b border-primary/60 pb-6">
            <h1 class="font-serif text-4xl leading-none sm:text-5xl">Administrar Exhibit</h1>
            <p class="mt-4 max-w-2xl leading-relaxed text-dark/80">Organiza las salas de la galería virtual y elige las obras de cada una. Los cambios se publican al guardar.</p>
            <a href={~p"/exhibit"} class="mt-4 inline-flex min-h-11 items-center font-semibold text-dark underline decoration-primary decoration-2 underline-offset-4 hover:decoration-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark">Ver Exhibit público</a>
          </div>

          <ul id="rooms" class="mt-8 divide-y divide-secondary border-y border-secondary">
            <li :for={room <- @rooms} id={"room-#{room.id}"} class="py-6">
              <h2 class="break-words font-serif text-2xl leading-tight">{room.name}</h2>
              <p class="mt-2 text-sm text-muted">{room_type_label(room.type, @room_types)}</p>
              <p class="mt-2 text-sm tabular-nums text-muted">{length(room.artworks)} {if length(room.artworks) == 1, do: "obra", else: "obras"} · Orden: {room.position}</p>
              <div class="mt-4 flex flex-wrap gap-3">
                <button type="button" phx-click="edit" phx-value-id={room.id} aria-label={"Editar #{room.name}"} class="min-h-11 border border-primary px-4 py-2 text-sm font-semibold transition hover:bg-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark">Editar</button>
                <button type="button" phx-click="delete" phx-value-id={room.id} aria-label={"Eliminar #{room.name}"} data-confirm="¿Eliminar esta sala de Exhibit? Las obras se conservarán en el archivo y en las demás salas." class="min-h-11 border border-accent px-4 py-2 text-sm font-semibold transition hover:bg-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark">Eliminar sala</button>
              </div>
            </li>
          </ul>
          <p :if={@rooms == []} class="py-8 leading-relaxed text-muted">Aún no hay salas en Exhibit. Agrega una sala y elige sus obras desde el formulario.</p>
        </div>

        <aside id="room-editor" class="min-w-0 border border-primary/60 bg-white p-5 shadow-xl sm:p-6" aria-labelledby="room-form-heading">
          <h2 id="room-form-heading" class="font-serif text-2xl">{if @editing_room, do: "Editar sala", else: "Agregar sala"}</h2>
          <p :if={message = Phoenix.Flash.get(@flash, :info)} role="status" class="mt-4 border border-secondary bg-secondary/20 p-3 text-sm text-dark">{message}</p>
          <p :if={message = Phoenix.Flash.get(@flash, :error)} role="alert" class="mt-4 border border-accent bg-accent/10 p-3 text-sm text-dark">{message}</p>
          <div id={"room-fields-#{@editor_revision}"} phx-hook="ExhibitRoomEditor" data-editing={to_string(not is_nil(@editing_room))} data-name={@form[:name].value} data-type={@form[:type].value} data-position={@form[:position].value} phx-mounted={if @editing_room, do: Phoenix.LiveView.JS.focus(to: "#room_name")}>
            <.form for={@form} id="room-form" phx-change="validate" phx-submit="save" class="mt-6 space-y-5">
              <div>
                <label for={@form[:name].id} class="text-sm font-semibold">Nombre</label>
                <input id={@form[:name].id} name={@form[:name].name} value={@form[:name].value} type="text" required maxlength="200" aria-invalid={if @form[:name].errors != [], do: "true", else: "false"} aria-describedby="room_name-errors" class="mt-2 block min-h-11 w-full border border-muted bg-light px-3 py-2 text-dark caret-dark selection:bg-secondary focus:border-dark focus:outline focus:outline-2 focus:outline-offset-2 focus:outline-dark" />
                <.field_errors field={@form[:name]} />
              </div>
              <div>
                <label for={@form[:type].id} class="text-sm font-semibold">Tipo de sala</label>
                <select id={@form[:type].id} name={@form[:type].name} required aria-invalid={if @form[:type].errors != [], do: "true", else: "false"} aria-describedby="room-type-help room_type-errors" class="mt-2 block min-h-11 w-full border border-muted bg-light px-3 py-2 text-dark focus:border-dark focus:outline focus:outline-2 focus:outline-offset-2 focus:outline-dark">
                  <option :for={{label, value} <- @room_types} value={value} selected={@form[:type].value == value}>{label}</option>
                </select>
                <div id="room-type-help" class="mt-2 space-y-2 text-sm leading-relaxed text-muted">
                  <p><strong class="font-semibold">Estándar:</strong> un espacio compacto para recorrer las obras.</p>
                  <p><strong class="font-semibold">Amplia:</strong> más espacio entre los muros para una vista abierta.</p>
                  <p><strong class="font-semibold">Cenital:</strong> una sala abierta, sin divisores, con un lucernario que difunde la luz desde el techo.</p>
                </div>
                <.field_errors field={@form[:type]} />
              </div>
              <div>
                <label for={@form[:position].id} class="text-sm font-semibold">Orden</label>
                <input id={@form[:position].id} name={@form[:position].name} value={@form[:position].value} type="number" required min="0" max="2147483647" step="1" aria-invalid={if @form[:position].errors != [], do: "true", else: "false"} aria-describedby="room-position-help room_position-errors" class="mt-2 block min-h-11 w-full border border-muted bg-light px-3 py-2 text-dark caret-dark selection:bg-secondary focus:border-dark focus:outline focus:outline-2 focus:outline-offset-2 focus:outline-dark" />
                <p id="room-position-help" class="mt-2 text-sm text-muted">Los números menores aparecen primero.</p>
                <.field_errors field={@form[:position]} />
              </div>
              <fieldset aria-describedby="room-artworks-help room_artwork_ids-errors" aria-invalid={if @form[:artwork_ids].errors != [], do: "true", else: "false"}>
                <legend class="text-sm font-semibold">Obras en esta sala</legend>
                <p id="room-artworks-help" class="mt-2 text-sm leading-relaxed text-muted">Elige tantas obras como necesites. Una obra puede aparecer en varias salas. Sin selección, la sala queda vacía.</p>
                <input type="hidden" name="room[artwork_ids][]" value="" />
                <div id="room-artworks" class="mt-3 max-h-[28rem] overflow-y-auto overscroll-contain divide-y divide-secondary border-y border-secondary">
                  <label :for={artwork <- @artworks} for={"room-artwork-#{artwork.id}"} class="flex min-h-11 cursor-pointer items-center gap-3 py-3 pr-2 transition hover:bg-secondary/20">
                    <input id={"room-artwork-#{artwork.id}"} name="room[artwork_ids][]" type="checkbox" value={artwork.id} checked={artwork_selected?(@form[:artwork_ids].value, artwork.id)} aria-describedby="room-artworks-help room_artwork_ids-errors" aria-invalid={if @form[:artwork_ids].errors != [], do: "true", else: "false"} class="ml-1 h-5 w-5 shrink-0 border-muted text-dark focus:ring-0 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark" />
                    <img src={artwork.photo} alt="" loading="lazy" class="h-14 w-14 shrink-0 border border-primary/50 object-cover" />
                    <span class="min-w-0">
                      <span class="block break-words text-sm font-semibold">{artwork.title}</span>
                      <span class="mt-1 block break-words text-sm text-muted [overflow-wrap:anywhere]">{artwork.category}</span>
                    </span>
                  </label>
                </div>
                <p :if={@artworks == []} class="mt-3 text-sm leading-relaxed text-muted">Aún no hay obras en el archivo. <a href={~p"/admin/obra"} class="font-semibold text-dark underline underline-offset-4 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark">Agregar obra</a></p>
                <.field_errors field={@form[:artwork_ids]} />
              </fieldset>
              <div class="flex flex-wrap gap-3 pt-2">
                <button type="submit" phx-disable-with="Guardando…" class="min-h-11 bg-primary px-5 py-2 font-semibold transition hover:bg-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark">{if @editing_room, do: "Guardar cambios", else: "Guardar sala"}</button>
                <button type="button" phx-click="cancel-edit" class="min-h-11 border border-dark px-5 py-2 font-semibold transition hover:bg-secondary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark">Cancelar</button>
              </div>
            </.form>
          </div>
        </aside>
      </div>
    </section>
    """
  end

  attr(:field, Phoenix.HTML.FormField, required: true)

  defp field_errors(assigns) do
    ~H"""
    <div id={"#{@field.id}-errors"}><p :for={error <- @field.errors} role="alert" class="mt-2 text-sm text-dark">{translate_error(error)}</p></div>
    """
  end

  defp editable_room(nil), do: %Room{}
  defp editable_room(room), do: room
  defp save_room(nil, attrs), do: Exhibit.create_room(attrs)
  defp save_room(room, attrs), do: Exhibit.update_room(room, attrs)

  defp normalize_selection(%{"artwork_ids" => ids} = params) when is_list(ids),
    do: Map.put(params, "artwork_ids", Enum.reject(ids, &(&1 == "")))

  defp normalize_selection(params), do: params

  defp artwork_selected?(ids, id) when is_list(ids) do
    string_id = Integer.to_string(id)
    Enum.any?(ids, &(&1 == id or &1 == string_id))
  end

  defp artwork_selected?(_ids, _id), do: false

  defp room_type_label(type, types) do
    {label, _value} = Enum.find(types, fn {_label, value} -> value == type end)
    label
  end

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))
  defp refresh_rooms(socket), do: assign(socket, :rooms, Exhibit.list_rooms())

  defp missing_room(socket) do
    socket
    |> put_flash(:error, "Esta sala ya fue eliminada. Elige otra sala o agrega una nueva.")
    |> reset_editor()
    |> refresh_rooms()
  end

  defp reset_editor(socket) do
    socket
    |> assign(:editing_room, nil)
    |> update(:editor_revision, &(&1 + 1))
    |> assign_form(Exhibit.change_room(%Room{}))
  end
end
