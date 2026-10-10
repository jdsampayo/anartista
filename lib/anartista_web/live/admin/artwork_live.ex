defmodule AnartistaWeb.Admin.ArtworkLive do
  use AnartistaWeb, :live_view

  alias Anartista.Artworks
  alias Anartista.Artworks.Artwork

  import AnartistaWeb.AdminComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:photo,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 10_000_000,
       auto_upload: true
     )
     |> assign(:page_title, "Administrar obra")
     |> assign(:editing_artwork, nil)
     |> assign(:editor_revision, 0)
     |> refresh_artworks()
     |> assign_form(Artworks.change_artwork(%Artwork{}))}
  end

  @impl true
  def handle_event("validate", %{"artwork" => params}, socket) do
    changeset =
      socket.assigns.editing_artwork
      |> editable_artwork()
      |> Artworks.change_artwork(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"artwork" => params}, socket) do
    artwork = socket.assigns.editing_artwork
    changeset = Artworks.change_artwork(editable_artwork(artwork), params)

    cond do
      not changeset.valid? ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}

      socket.assigns.uploads.photo.entries != [] and not photo_uploaded?(socket) ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Espera a que termine de cargar la foto y revisa su formato y tamaño."
         )}

      is_nil(artwork) and not photo_uploaded?(socket) ->
        changeset = Ecto.Changeset.add_error(changeset, :photo, "no puede estar vacía")
        {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}

      true ->
        {photo, uploaded?} = persist_uploaded_photo(socket, artwork && artwork.photo)

        case save_artwork(artwork, Map.put(params, "photo", photo)) do
          {:ok, _saved} ->
            if artwork && uploaded?, do: delete_photo(artwork.photo)

            {:noreply,
             socket
             |> put_flash(:info, "La obra se guardó.")
             |> reset_editor()
             |> refresh_artworks()}

          {:error, changeset} ->
            if uploaded?, do: delete_photo(photo)
            {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
        end
    end
  end

  def handle_event("edit", %{"id" => id}, socket) do
    artwork = Artworks.get_artwork!(id)

    {:noreply,
     socket
     |> cancel_photo_uploads()
     |> assign(:editing_artwork, artwork)
     |> update(:editor_revision, &(&1 + 1))
     |> assign_form(Artworks.change_artwork(artwork))}
  end

  def handle_event("cancel-edit", _params, socket),
    do: {:noreply, socket |> cancel_photo_uploads() |> reset_editor()}

  def handle_event("delete", %{"id" => id}, socket) do
    artwork = Artworks.get_artwork!(id)
    {:ok, _deleted} = Artworks.delete_artwork(artwork)
    delete_photo(artwork.photo)

    socket =
      if socket.assigns.editing_artwork &&
           socket.assigns.editing_artwork.id == artwork.id,
         do: socket |> cancel_photo_uploads() |> reset_editor(),
         else: socket

    {:noreply,
     socket
     |> put_flash(:info, "La obra se eliminó.")
     |> refresh_artworks()}
  end

  def handle_event("cancel-photo", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photo, ref)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_navigation current={:artworks} />
    <section class="bg-light px-4 py-16 text-dark">
      <div class="mx-auto grid max-w-6xl gap-10 lg:grid-cols-[minmax(0,1fr)_24rem] lg:items-start">
        <div class="min-w-0">
          <div class="border-b border-primary/60 pb-6">
            <h1 class="font-serif text-4xl leading-none sm:text-5xl">Administrar obra</h1>
            <p class="mt-4 max-w-2xl leading-relaxed text-dark/80">Agrega, edita y ordena las obras del archivo público. Los cambios se publican al guardar.</p>
            <a href={~p"/obra"} class="mt-4 inline-flex min-h-11 items-center font-semibold text-dark underline decoration-primary decoration-2 underline-offset-4 hover:decoration-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark">Ver archivo público</a>
          </div>

          <ul id="artworks" class="mt-8 divide-y divide-secondary border-y border-secondary">
            <li :for={artwork <- @artworks} id={"artwork-#{artwork.id}"} class="py-6">
              <div class="flex items-start gap-4">
                <img src={artwork.photo} alt="" class="h-20 w-20 shrink-0 border border-primary/50 object-cover" />
                <div class="min-w-0">
                  <h2 class="break-words font-serif text-2xl leading-tight">{artwork.title}</h2>
                  <p class="mt-2 break-words text-sm text-muted [overflow-wrap:anywhere]">{artwork.category}</p>
                  <p class="mt-2 text-sm text-muted">Orden: {artwork.position} · {if artwork.selected, do: "Obra seleccionada", else: "Solo archivo público"}</p>
                </div>
              </div>
              <div class="mt-4 flex flex-wrap gap-3">
                <button type="button" phx-click="edit" phx-value-id={artwork.id} aria-label={"Editar #{artwork.title}"} class="min-h-11 border border-primary px-4 py-2 text-sm font-semibold transition hover:bg-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark">Editar</button>
                <button type="button" phx-click="delete" phx-value-id={artwork.id} aria-label={"Eliminar #{artwork.title}"} data-confirm="¿Eliminar esta obra del archivo público?" class="min-h-11 border border-accent px-4 py-2 text-sm font-semibold transition hover:bg-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark">Eliminar</button>
              </div>
            </li>
          </ul>
          <p :if={@artworks == []} class="py-8 text-muted">Aún no hay obra. Agrega la primera desde el formulario.</p>
        </div>

        <aside id="artwork-editor" class="border border-primary/60 bg-white p-6 shadow-xl" aria-labelledby="artwork-form-heading">
          <h2 id="artwork-form-heading" class="font-serif text-2xl">{if @editing_artwork, do: "Editar obra", else: "Agregar obra"}</h2>
          <p :if={message = Phoenix.Flash.get(@flash, :info)} role="status" class="mt-4 border border-secondary bg-secondary/20 p-3 text-sm text-dark">{message}</p>
          <p :if={message = Phoenix.Flash.get(@flash, :error)} role="alert" class="mt-4 border border-accent bg-accent/10 p-3 text-sm text-dark">{message}</p>
          <div id={"artwork-fields-#{@editor_revision}"} phx-mounted={if @editing_artwork, do: Phoenix.LiveView.JS.focus(to: "#artwork_title")}><.form for={@form} id="artwork-form" phx-change="validate" phx-submit="save" class="mt-6 space-y-5">
            <div :for={{field, label, required, maxlength} <- [
              {:title, "Título", true, 200},
              {:category, "Tipo", true, 100},
              {:year, "Fecha o año (opcional)", false, 100},
              {:technique, "Técnica (opcional)", false, 255},
              {:materials, "Materiales (opcional)", false, 255},
              {:dimensions, "Dimensiones (opcional)", false, 255},
              {:edition, "Edición (opcional)", false, 255},
              {:collection, "Colección (opcional)", false, 255},
              {:image_alt, "Descripción de la imagen", true, 255}
            ]}>
              <label for={@form[field].id} class="text-sm font-semibold">{label}</label>
              <input id={@form[field].id} name={@form[field].name} value={@form[field].value} type="text" list={if field == :category, do: "artwork-categories"} aria-invalid={if @form[field].errors != [], do: "true", else: "false"} aria-describedby={"#{@form[field].id}-errors"} required={required} maxlength={maxlength} class="mt-2 block min-h-11 w-full border border-muted bg-light px-3 py-2 text-dark caret-dark selection:bg-secondary focus:border-dark focus:outline focus:outline-2 focus:outline-offset-2 focus:outline-dark" />
              <.field_errors field={@form[field]} />
            </div>
            <div>
              <label for={@form[:description].id} class="text-sm font-semibold">Descripción (opcional)</label>
              <textarea id={@form[:description].id} name={@form[:description].name} aria-invalid={if @form[:description].errors != [], do: "true", else: "false"} aria-describedby="artwork_description-errors" maxlength="5000" rows="5" class="mt-2 block w-full border border-muted bg-light px-3 py-2 text-dark caret-dark selection:bg-secondary focus:border-dark focus:outline focus:outline-2 focus:outline-offset-2 focus:outline-dark">{@form[:description].value}</textarea>
              <.field_errors field={@form[:description]} />
            </div>
            <datalist id="artwork-categories"><option :for={category <- @categories} value={category} /></datalist>
            <div>
              <input type="hidden" name={@form[:selected].name} value="false" />
              <label for={@form[:selected].id} class="flex min-h-11 items-center gap-3 text-sm font-semibold">
                <input id={@form[:selected].id} name={@form[:selected].name} type="checkbox" value="true" checked={Phoenix.HTML.Form.normalize_value("checkbox", @form[:selected].value)} aria-invalid={if @form[:selected].errors != [], do: "true", else: "false"} aria-describedby="artwork-selected-help artwork_selected-errors" class="h-5 w-5 border-muted text-dark focus:ring-0 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark" />
                Obra seleccionada
              </label>
              <p id="artwork-selected-help" class="mt-2 text-sm text-muted">También aparece en Obra seleccionada de Acerca de. Todas las obras aparecen en el archivo público.</p>
              <.field_errors field={@form[:selected]} />
            </div>
            <div>
              <label for={@form[:position].id} class="text-sm font-semibold">Orden en el archivo</label>
              <input id={@form[:position].id} name={@form[:position].name} value={@form[:position].value} type="number" aria-invalid={if @form[:position].errors != [], do: "true", else: "false"} aria-describedby="artwork-position-help artwork_position-errors" required min="0" max="2147483647" step="1" class="mt-2 block min-h-11 w-full border border-muted bg-light px-3 py-2 text-dark caret-dark selection:bg-secondary focus:border-dark focus:outline focus:outline-2 focus:outline-offset-2 focus:outline-dark" />
              <p id="artwork-position-help" class="mt-2 text-sm text-muted">Los números menores aparecen primero.</p>
              <.field_errors field={@form[:position]} />
            </div>
            <div>
              <label for={@uploads.photo.ref} class="text-sm font-semibold">Foto</label>
              <.live_file_input upload={@uploads.photo} aria-describedby="artwork-photo-help artwork_photo-errors artwork-upload-errors" aria-invalid={if @form[:photo].errors != [] or upload_errors(@uploads.photo) != [], do: "true", else: "false"} class="mt-2 block min-h-11 w-full text-sm file:mr-3 file:min-h-11 file:border-0 file:bg-primary file:px-3 file:text-dark focus-visible:outline focus-visible:outline-2 focus-visible:outline-dark" />
              <p id="artwork-photo-help" class="mt-2 text-sm text-muted">JPG, PNG o WebP. Máximo 10 MB.</p>
              <img :if={@editing_artwork && @uploads.photo.entries == []} src={@editing_artwork.photo} alt="Foto actual de la obra" class="mt-3 h-24 w-24 border border-primary object-cover" />
              <div id="artwork-upload-errors"><div :for={entry <- @uploads.photo.entries} class="mt-3">
                <.live_img_preview entry={entry} class="h-24 w-24 border border-primary object-cover" />
                <p class="mt-2 break-words text-sm text-muted">{entry.client_name} · {entry.progress}%</p>
                <p :for={error <- upload_errors(@uploads.photo, entry)} role="alert" class="mt-2 text-sm text-dark">{upload_error_message(error)}</p>
                <button type="button" phx-click="cancel-photo" phx-value-ref={entry.ref} class="mt-2 min-h-11 px-3 text-sm font-semibold underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-dark">Quitar foto seleccionada</button>
              </div>
              <p :for={error <- upload_errors(@uploads.photo)} role="alert" class="mt-2 text-sm text-dark">{upload_error_message(error)}</p></div>
              <.field_errors field={@form[:photo]} />
            </div>
            <div class="flex flex-wrap gap-3 pt-2">
              <button type="submit" phx-disable-with="Guardando…" class="min-h-11 bg-primary px-5 py-2 font-semibold transition hover:bg-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark">{if @editing_artwork, do: "Guardar cambios", else: "Guardar obra"}</button>
              <button type="button" phx-click="cancel-edit" class="min-h-11 border border-dark px-5 py-2 font-semibold transition hover:bg-secondary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark">Cancelar</button>
            </div>
          </.form></div>
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

  defp editable_artwork(nil), do: %Artwork{photo: "/uploads/artworks/pending.webp"}
  defp editable_artwork(artwork), do: artwork
  defp save_artwork(nil, attrs), do: Artworks.create_artwork(attrs)
  defp save_artwork(artwork, attrs), do: Artworks.update_artwork(artwork, attrs)

  defp persist_uploaded_photo(socket, existing_photo) do
    case consume_uploaded_entries(socket, :photo, fn %{path: source_path}, entry ->
           filename =
             "#{Ecto.UUID.generate()}#{entry.client_name |> Path.extname() |> String.downcase()}"

           destination = Path.join(photo_directory(), filename)
           File.mkdir_p!(Path.dirname(destination))
           File.cp!(source_path, destination)
           {:ok, "/uploads/artworks/#{filename}"}
         end) do
      [] -> {existing_photo, false}
      [photo] -> {photo, true}
    end
  end

  defp photo_uploaded?(socket) do
    case uploaded_entries(socket, :photo) do
      {[_entry], []} -> true
      _ -> false
    end
  end

  defp cancel_photo_uploads(socket) do
    Enum.reduce(socket.assigns.uploads.photo.entries, socket, fn entry, socket ->
      cancel_upload(socket, :photo, entry.ref)
    end)
  end

  defp photo_directory do
    :anartista |> :code.priv_dir() |> to_string() |> Path.join("static/uploads/artworks")
  end

  defp delete_photo("/uploads/artworks/" <> filename) do
    if Path.basename(filename) == filename, do: File.rm(Path.join(photo_directory(), filename))
    :ok
  end

  defp delete_photo(_photo), do: :ok
  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))

  defp refresh_artworks(socket),
    do:
      socket
      |> assign(:artworks, Artworks.list_artworks())
      |> assign(:categories, Artworks.list_categories())

  defp reset_editor(socket) do
    socket
    |> assign(:editing_artwork, nil)
    |> assign_form(Artworks.change_artwork(%Artwork{}))
  end

  defp upload_error_message(:too_large),
    do: "La foto supera el límite de 10 MB. Elige una más pequeña."

  defp upload_error_message(:not_accepted), do: "Elige una foto JPG, PNG o WebP."
  defp upload_error_message(:too_many_files), do: "Elige una sola foto."

  defp upload_error_message(_error),
    do: "No fue posible cargar esta foto. Vuelve a seleccionarla."
end
