defmodule AnartistaWeb.Admin.StoreLive do
  use AnartistaWeb, :live_view

  alias Anartista.Store
  alias Anartista.Store.Piece

  import AnartistaWeb.AdminComponents

  @accepted_photo_extensions ~w(.jpg .jpeg .png .webp)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:photo,
       accept: @accepted_photo_extensions,
       max_entries: 1,
       max_file_size: 10_000_000,
       auto_upload: true
     )
     |> assign(:editing_piece, nil)
     |> assign(:pieces, Store.list_pieces())
     |> assign(:categories, Store.list_categories())
     |> assign_form(Store.change_piece(%Piece{}))}
  end

  @impl true
  def handle_event("validate", %{"piece" => params}, socket) do
    changeset =
      socket.assigns.editing_piece
      |> editable_piece()
      |> Store.change_piece(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"piece" => params}, socket) do
    piece = socket.assigns.editing_piece
    changeset = Store.change_piece(editable_piece(piece), params)

    case validate_submission(socket, piece, changeset) do
      {:error, invalid_changeset} ->
        {:noreply, assign_form(socket, Map.put(invalid_changeset, :action, :validate))}

      {:ok, photo, photo_uploaded?} ->
        attrs = Map.put(params, "photo", photo)

        case save_piece(piece, attrs) do
          {:ok, _saved_piece} ->
            if piece && photo_uploaded?, do: delete_photo(piece.photo)

            {:noreply,
             socket
             |> put_flash(:info, saved_message(piece))
             |> refresh_pieces()
             |> assign(:editing_piece, nil)
             |> assign_form(Store.change_piece(%Piece{}))}

          {:error, invalid_changeset} ->
            if photo_uploaded?, do: delete_photo(photo)

            {:noreply, assign_form(socket, Map.put(invalid_changeset, :action, :validate))}
        end
    end
  end

  def handle_event("edit", %{"id" => id}, socket) do
    piece = Store.get_piece!(id)

    {:noreply,
     socket
     |> assign(:editing_piece, piece)
     |> assign_form(Store.change_piece(piece))}
  end

  def handle_event("cancel-edit", _params, socket) do
    {:noreply,
     socket
     |> cancel_photo_uploads()
     |> assign(:editing_piece, nil)
     |> assign_form(Store.change_piece(%Piece{}))}
  end

  def handle_event("toggle-availability", %{"id" => id}, socket) do
    piece = Store.get_piece!(id)
    {:ok, updated_piece} = Store.toggle_piece_availability(piece)

    {:noreply,
     socket
     |> put_flash(:info, availability_message(updated_piece))
     |> refresh_pieces()}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    piece = Store.get_piece!(id)
    {:ok, _deleted_piece} = Store.delete_piece(piece)
    delete_photo(piece.photo)

    socket =
      socket
      |> put_flash(:info, "Pieza eliminada.")
      |> refresh_pieces()

    if socket.assigns.editing_piece && socket.assigns.editing_piece.id == piece.id do
      {:noreply,
       socket
       |> assign(:editing_piece, nil)
       |> assign_form(Store.change_piece(%Piece{}))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_navigation current={:store} />
    <section class="bg-light px-4 py-16">
      <div class="mx-auto grid max-w-6xl gap-10 lg:grid-cols-[minmax(0,1fr)_24rem] lg:items-start">
        <div>
          <div class="border-b border-primary/60 pb-6">
            <h1 class="font-serif text-4xl leading-none text-dark sm:text-5xl">Administrar tienda</h1>
            <p class="mt-4 max-w-2xl text-dark/80">Agrega piezas únicas, actualiza su disponibilidad y conserva las vendidas como parte del archivo.</p>
          </div>

          <div class="mt-8 overflow-x-auto border border-secondary bg-white shadow-lg">
            <table class="min-w-full divide-y divide-secondary/70 text-left">
              <thead class="bg-dark text-light">
                <tr>
                  <th class="px-4 py-3 text-xs font-semibold uppercase tracking-[0.14em]">Pieza</th>
                  <th class="px-4 py-3 text-xs font-semibold uppercase tracking-[0.14em]">Precio</th>
                  <th class="px-4 py-3 text-xs font-semibold uppercase tracking-[0.14em]">Estado</th>
                  <th class="px-4 py-3 text-right text-xs font-semibold uppercase tracking-[0.14em]">Acciones</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-cement">
                <tr :for={piece <- @pieces} id={"piece-#{piece.id}"} class="align-top">
                  <td class="px-4 py-4">
                    <div class="flex min-w-52 gap-3">
                      <img src={piece.photo} alt="" class="h-14 w-14 border border-primary/50 object-cover" />
                      <div>
                        <p class="text-xs font-semibold uppercase tracking-[0.14em] text-muted">{piece.category}</p>
                        <p class="font-serif text-lg leading-tight text-dark">{piece.name}</p>
                        <p class="mt-1 max-w-sm text-sm leading-relaxed text-muted">{piece.description}</p>
                      </div>
                    </div>
                  </td>
                  <td class="whitespace-nowrap px-4 py-4 text-sm font-semibold text-dark">${format_price(piece.price)}</td>
                  <td class="px-4 py-4">
                    <button
                      type="button"
                      phx-click="toggle-availability"
                      phx-value-id={piece.id}
                      class={[
                        "min-h-11 border px-3 py-2 text-sm font-semibold transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark",
                        piece.available && "border-primary bg-primary text-dark hover:bg-accent",
                        !piece.available && "border-accent bg-accent/20 text-dark hover:bg-secondary"
                      ]}
                    >
                      {availability_label(piece)}
                    </button>
                  </td>
                  <td class="px-4 py-4 text-right">
                    <div class="flex justify-end gap-2">
                      <button type="button" phx-click="edit" phx-value-id={piece.id} class="min-h-11 border border-primary px-3 py-2 text-sm font-semibold text-dark transition hover:bg-primary focus-visible:bg-primary">Editar</button>
                      <button type="button" phx-click="delete" phx-value-id={piece.id} data-confirm="¿Eliminar esta pieza? La foto también se eliminará." class="min-h-11 border border-accent px-3 py-2 text-sm font-semibold text-dark transition hover:bg-accent focus-visible:bg-accent">Eliminar</button>
                    </div>
                  </td>
                </tr>
                <tr :if={@pieces == []}>
                  <td colspan="4" class="px-4 py-12 text-center text-muted">Aún no hay piezas. Agrega la primera desde este formulario.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <aside class="border border-primary/60 bg-white p-6 shadow-xl">
          <h2 class="font-serif text-2xl text-dark">{form_title(@editing_piece)}</h2>
          <p class="mt-2 text-sm leading-relaxed text-muted">La compra se realiza únicamente mediante el enlace de pago que guardes aquí.</p>

          <.form for={@form} id="piece-form" phx-change="validate" phx-submit="save" class="mt-6 space-y-5">
            <div>
              <label for={@form[:name].id} class="text-sm font-semibold text-dark">Nombre</label>
              <input id={@form[:name].id} name={@form[:name].name} value={@form[:name].value} type="text" required maxlength="120" class="mt-2 block w-full border border-primary/70 bg-light px-3 py-2 text-dark focus:border-dark focus:ring-0" />
              <.field_errors field={@form[:name]} />
            </div>

            <div>
              <label for={@form[:category].id} class="text-sm font-semibold text-dark">Categoría</label>
              <input id={@form[:category].id} name={@form[:category].name} value={@form[:category].value} type="text" list="piece-categories" autocomplete="off" required maxlength="100" class="mt-2 block w-full border border-primary/70 bg-light px-3 py-2 text-dark focus:border-dark focus:ring-0" />
              <datalist id="piece-categories">
                <option :for={category <- @categories} value={category}></option>
              </datalist>
              <p class="mt-1 text-xs text-muted">Escribe una categoría nueva o elige una ya usada.</p>
              <.field_errors field={@form[:category]} />
            </div>

            <div>
              <label for={@form[:description].id} class="text-sm font-semibold text-dark">Descripción</label>
              <textarea id={@form[:description].id} name={@form[:description].name} required maxlength="2000" rows="5" class="mt-2 block w-full border border-primary/70 bg-light px-3 py-2 text-dark focus:border-dark focus:ring-0">{@form[:description].value}</textarea>
              <.field_errors field={@form[:description]} />
            </div>

            <div class="grid gap-5 sm:grid-cols-2">
              <div>
                <label for={@form[:technique].id} class="text-sm font-semibold text-dark">Técnica</label>
                <input id={@form[:technique].id} name={@form[:technique].name} value={@form[:technique].value} type="text" maxlength="255" class="mt-2 block w-full border border-primary/70 bg-light px-3 py-2 text-dark focus:border-dark focus:ring-0" />
                <.field_errors field={@form[:technique]} />
              </div>

              <div>
                <label for={@form[:dimensions].id} class="text-sm font-semibold text-dark">Dimensiones</label>
                <input id={@form[:dimensions].id} name={@form[:dimensions].name} value={@form[:dimensions].value} type="text" maxlength="100" class="mt-2 block w-full border border-primary/70 bg-light px-3 py-2 text-dark focus:border-dark focus:ring-0" />
                <.field_errors field={@form[:dimensions]} />
              </div>
            </div>

            <div>
              <label for={@form[:year].id} class="text-sm font-semibold text-dark">Año</label>
              <input id={@form[:year].id} name={@form[:year].name} value={@form[:year].value} type="number" min="1" max="9999" step="1" class="mt-2 block w-full border border-primary/70 bg-light px-3 py-2 text-dark focus:border-dark focus:ring-0" />
              <.field_errors field={@form[:year]} />
            </div>

            <div>
              <label for={@form[:price].id} class="text-sm font-semibold text-dark">Precio</label>
              <input id={@form[:price].id} name={@form[:price].name} value={@form[:price].value} type="number" min="0.01" step="0.01" required class="mt-2 block w-full border border-primary/70 bg-light px-3 py-2 text-dark focus:border-dark focus:ring-0" />
              <p class="mt-1 text-xs text-muted">Se muestra como referencia; el cobro se gestiona fuera del sitio.</p>
              <.field_errors field={@form[:price]} />
            </div>

            <div>
              <label for={@form[:payment_link].id} class="text-sm font-semibold text-dark">Enlace de pago</label>
              <input id={@form[:payment_link].id} name={@form[:payment_link].name} value={@form[:payment_link].value} type="url" required placeholder="https://buy.stripe.com/..." class="mt-2 block w-full border border-primary/70 bg-light px-3 py-2 text-dark focus:border-dark focus:ring-0" />
              <.field_errors field={@form[:payment_link]} />
            </div>

            <div>
              <label for={@uploads.photo.ref} class="text-sm font-semibold text-dark">Foto</label>
              <div class="mt-2 border border-dashed border-primary/70 bg-light p-3">
                <.live_file_input upload={@uploads.photo} class="sr-only" />
                <label for={@uploads.photo.ref} class="inline-flex min-h-11 cursor-pointer items-center bg-primary px-4 py-2 text-sm font-semibold text-dark transition hover:bg-accent focus-visible:bg-accent">Elegir foto</label>
                <p :if={@uploads.photo.entries == []} class="mt-2 text-xs text-muted">Ninguna foto seleccionada.</p>
                <p class="mt-2 text-xs text-muted">JPG, PNG o WebP. Máximo 10 MB.</p>
                <div :for={entry <- @uploads.photo.entries} class="mt-3">
                  <.live_img_preview entry={entry} class="h-24 w-24 border border-primary object-cover" />
                  <p class="mt-1 text-xs text-muted">{entry.client_name}</p>
                </div>
                <.field_errors :if={!@editing_piece && @uploads.photo.entries == []} field={@form[:photo]} />
                <p :for={error <- upload_errors(@uploads.photo)} class="mt-2 text-sm text-accent">{upload_error_message(error)}</p>
              </div>
              <img :if={@editing_piece && @uploads.photo.entries == []} src={@editing_piece.photo} alt="Foto actual de la pieza" class="mt-3 h-24 w-24 border border-primary object-cover" />
            </div>

            <label class="flex items-center gap-3 text-sm font-semibold text-dark">
              <input type="hidden" name={@form[:available].name} value="false" />
              <input id={@form[:available].id} name={@form[:available].name} value="true" type="checkbox" checked={@form[:available].value} class="h-5 w-5 border-primary text-primary focus:ring-primary" />
              Disponible para comprar
            </label>

            <div class="flex flex-wrap gap-3 pt-2">
              <button type="submit" class="min-h-11 bg-primary px-5 py-2 font-semibold text-dark transition hover:bg-accent focus-visible:bg-accent" phx-disable-with="Guardando…">{save_label(@editing_piece)}</button>
              <button :if={@editing_piece} type="button" phx-click="cancel-edit" class="min-h-11 border border-dark px-5 py-2 font-semibold text-dark transition hover:bg-secondary focus-visible:bg-secondary">Cancelar</button>
            </div>
          </.form>
        </aside>
      </div>
    </section>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true

  defp field_errors(assigns) do
    ~H"""
    <p :for={error <- @field.errors} class="mt-2 text-sm text-accent">{translate_error(error)}</p>
    """
  end

  defp editable_piece(nil), do: %Piece{photo: "pending-upload"}
  defp editable_piece(piece), do: piece

  defp validate_submission(socket, piece, changeset) do
    cond do
      not changeset.valid? -> {:error, changeset}
      is_nil(piece) and not photo_uploaded?(socket) -> {:error, Ecto.Changeset.add_error(changeset, :photo, "no puede estar vacía")}
      true ->
        {photo, photo_uploaded?} = persist_uploaded_photo(socket, piece && piece.photo)
        {:ok, photo, photo_uploaded?}
    end
  end

  defp save_piece(nil, attrs), do: Store.create_piece(attrs)
  defp save_piece(piece, attrs), do: Store.update_piece(piece, attrs)

  defp persist_uploaded_photo(socket, existing_photo) do
    case consume_uploaded_entries(socket, :photo, fn %{path: source_path}, entry ->
           filename = "#{Ecto.UUID.generate()}#{entry.client_name |> Path.extname() |> String.downcase()}"
           destination = Path.join(photo_directory(), filename)
           File.mkdir_p!(Path.dirname(destination))
           File.cp!(source_path, destination)
           {:ok, "/uploads/pieces/#{filename}"}
         end) do
      [] -> {existing_photo, false}
      [photo] -> {photo, true}
    end
  end

  defp photo_uploaded?(socket) do
    case uploaded_entries(socket, :photo) do
      {[_entry | _entries], []} -> true
      _ -> false
    end
  end

  defp cancel_photo_uploads(socket) do
    Enum.reduce(socket.assigns.uploads.photo.entries, socket, fn entry, socket ->
      cancel_upload(socket, :photo, entry.ref)
    end)
  end

  defp photo_directory do
    :anartista
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("static/uploads/pieces")
  end

  defp delete_photo("/uploads/pieces/" <> filename) do
    if Path.basename(filename) == filename do
      File.rm(Path.join(photo_directory(), filename))
    end

    :ok
  end

  defp delete_photo(_photo), do: :ok

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))
  defp refresh_pieces(socket) do
    socket
    |> assign(:pieces, Store.list_pieces())
    |> assign(:categories, Store.list_categories())
  end
  defp form_title(nil), do: "Agregar pieza"
  defp form_title(_piece), do: "Editar pieza"
  defp save_label(nil), do: "Guardar pieza"
  defp save_label(_piece), do: "Guardar cambios"
  defp availability_label(%Piece{available: true}), do: "Disponible"
  defp availability_label(%Piece{}), do: "Vendida"
  defp availability_message(%Piece{available: true}), do: "La pieza está disponible."
  defp availability_message(%Piece{}), do: "La pieza se marcó como vendida."
  defp saved_message(nil), do: "La pieza se agregó a la tienda."
  defp saved_message(_piece), do: "Los cambios se guardaron."
  defp format_price(price), do: Decimal.to_string(price, :normal)
  defp upload_error_message(:too_large), do: "La foto supera el límite de 10 MB."
  defp upload_error_message(:not_accepted), do: "Elige una foto JPG, PNG o WebP."
  defp upload_error_message(_error), do: "No fue posible cargar esta foto."
end
