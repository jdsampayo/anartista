defmodule AnartistaWeb.Admin.ExhibitionsLive do
  use AnartistaWeb, :live_view

  alias Anartista.Exhibitions
  alias Anartista.Exhibitions.Exhibition

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
     |> assign(:page_title, "Administrar exposiciones")
     |> assign(:editing_exhibition, nil)
     |> refresh_exhibitions()
     |> assign_form(Exhibitions.change_exhibition(%Exhibition{}))}
  end

  @impl true
  def handle_event("validate", %{"exhibition" => params}, socket) do
    changeset =
      socket.assigns.editing_exhibition
      |> editable_exhibition()
      |> Exhibitions.change_exhibition(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"exhibition" => params}, socket) do
    exhibition = socket.assigns.editing_exhibition
    changeset = Exhibitions.change_exhibition(editable_exhibition(exhibition), params)

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

      is_nil(exhibition) and not photo_uploaded?(socket) ->
        changeset = Ecto.Changeset.add_error(changeset, :photo, "no puede estar vacía")
        {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}

      true ->
        {photo, uploaded?} = persist_uploaded_photo(socket, exhibition && exhibition.photo)

        case save_exhibition(exhibition, Map.put(params, "photo", photo)) do
          {:ok, _saved} ->
            if exhibition && uploaded?, do: delete_photo(exhibition.photo)

            {:noreply,
             socket
             |> put_flash(:info, "La exposición se guardó.")
             |> reset_editor()
             |> refresh_exhibitions()}

          {:error, changeset} ->
            if uploaded?, do: delete_photo(photo)
            {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
        end
    end
  end

  def handle_event("edit", %{"id" => id}, socket) do
    exhibition = Exhibitions.get_exhibition!(id)

    {:noreply,
     socket
     |> cancel_photo_uploads()
     |> assign(:editing_exhibition, exhibition)
     |> assign_form(Exhibitions.change_exhibition(exhibition))}
  end

  def handle_event("cancel-edit", _params, socket),
    do: {:noreply, socket |> cancel_photo_uploads() |> reset_editor()}

  def handle_event("delete", %{"id" => id}, socket) do
    exhibition = Exhibitions.get_exhibition!(id)
    {:ok, _deleted} = Exhibitions.delete_exhibition(exhibition)
    delete_photo(exhibition.photo)

    socket =
      if socket.assigns.editing_exhibition &&
           socket.assigns.editing_exhibition.id == exhibition.id,
         do: socket |> cancel_photo_uploads() |> reset_editor(),
         else: socket

    {:noreply,
     socket
     |> put_flash(:info, "La exposición se eliminó.")
     |> refresh_exhibitions()}
  end

  def handle_event("cancel-photo", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photo, ref)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_navigation current={:exhibitions} />
    <section class="bg-light px-4 py-16 text-dark">
      <div class="mx-auto grid max-w-6xl gap-10 lg:grid-cols-[minmax(0,1fr)_24rem] lg:items-start">
        <div>
          <div class="border-b border-primary/60 pb-6">
            <h1 class="font-serif text-4xl leading-none sm:text-5xl">Administrar exposiciones</h1>
            <p class="mt-4 max-w-2xl leading-relaxed text-dark/80">Agrega, edita y ordena las exposiciones del archivo público. Los cambios se publican al guardar.</p>
            <a href={~p"/exhibitions"} class="mt-4 inline-flex min-h-11 items-center font-semibold text-dark underline decoration-primary decoration-2 underline-offset-4 hover:decoration-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark">Ver archivo público</a>
          </div>

          <ul id="exhibitions" class="mt-8 divide-y divide-secondary border-y border-secondary">
            <li :for={exhibition <- @exhibitions} id={"exhibition-#{exhibition.id}"} class="py-6">
              <div class="flex items-start gap-4">
                <img src={exhibition.photo} alt="" class="h-20 w-20 shrink-0 border border-primary/50 object-cover" />
                <div class="min-w-0">
                  <h2 class="break-words font-serif text-2xl leading-tight">{exhibition.title}</h2>
                  <p class="mt-2 text-sm text-muted">{exhibition.date} · {exhibition.location}</p>
                  <p class="mt-2 text-sm text-muted">Orden: {exhibition.position}</p>
                </div>
              </div>
              <div class="mt-4 flex flex-wrap gap-3">
                <button type="button" phx-click="edit" phx-value-id={exhibition.id} aria-label={"Editar #{exhibition.title}"} class="min-h-11 border border-primary px-4 py-2 text-sm font-semibold transition hover:bg-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark">Editar</button>
                <button type="button" phx-click="delete" phx-value-id={exhibition.id} aria-label={"Eliminar #{exhibition.title}"} data-confirm="¿Eliminar esta exposición del archivo público?" class="min-h-11 border border-accent px-4 py-2 text-sm font-semibold transition hover:bg-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark">Eliminar</button>
              </div>
            </li>
          </ul>
          <p :if={@exhibitions == []} class="py-8 text-muted">Aún no hay exposiciones. Agrega la primera desde el formulario.</p>
        </div>

        <aside id="exhibition-editor" class="border border-primary/60 bg-white p-6 shadow-xl" aria-labelledby="exhibition-form-heading">
          <h2 id="exhibition-form-heading" class="font-serif text-2xl">{if @editing_exhibition, do: "Editar exposición", else: "Agregar exposición"}</h2>
          <p :if={message = Phoenix.Flash.get(@flash, :info)} role="status" class="mt-4 border border-secondary bg-secondary/20 p-3 text-sm text-dark">{message}</p>
          <p :if={message = Phoenix.Flash.get(@flash, :error)} role="alert" class="mt-4 border border-accent bg-accent/10 p-3 text-sm text-dark">{message}</p>
          <.form for={@form} id="exhibition-form" phx-change="validate" phx-submit="save" class="mt-6 space-y-5">
            <div :for={{field, label, required, maxlength} <- [
              {:title, "Título", true, 200},
              {:subtitle, "Subtítulo (opcional)", false, 255},
              {:date, "Fechas", true, 255},
              {:location, "Lugar", true, 255},
              {:opening, "Inauguración u horario (opcional)", false, 255},
              {:image_alt, "Descripción de la imagen", true, 255}
            ]}>
              <label for={@form[field].id} class="text-sm font-semibold">{label}</label>
              <input id={@form[field].id} name={@form[field].name} value={@form[field].value} type="text" required={required} maxlength={maxlength} class="mt-2 block min-h-11 w-full border border-muted bg-light px-3 py-2 text-dark caret-dark selection:bg-secondary focus:border-dark focus:outline focus:outline-2 focus:outline-offset-2 focus:outline-dark" />
              <.field_errors field={@form[field]} />
            </div>
            <div>
              <label for={@form[:description].id} class="text-sm font-semibold">Descripción</label>
              <textarea id={@form[:description].id} name={@form[:description].name} required maxlength="5000" rows="5" class="mt-2 block w-full border border-muted bg-light px-3 py-2 text-dark caret-dark selection:bg-secondary focus:border-dark focus:outline focus:outline-2 focus:outline-offset-2 focus:outline-dark">{@form[:description].value}</textarea>
              <.field_errors field={@form[:description]} />
            </div>
            <div>
              <label for={@form[:link_url].id} class="text-sm font-semibold">Enlace (opcional)</label>
              <input id={@form[:link_url].id} name={@form[:link_url].name} value={@form[:link_url].value} type="url" placeholder="https://…" maxlength="2000" class="mt-2 block min-h-11 w-full border border-muted bg-light px-3 py-2 text-dark caret-dark selection:bg-secondary focus:border-dark focus:outline focus:outline-2 focus:outline-offset-2 focus:outline-dark" />
              <.field_errors field={@form[:link_url]} />
            </div>
            <div>
              <label for={@form[:link_text].id} class="text-sm font-semibold">Texto del enlace</label>
              <input id={@form[:link_text].id} name={@form[:link_text].name} value={@form[:link_text].value} type="text" maxlength="255" class="mt-2 block min-h-11 w-full border border-muted bg-light px-3 py-2 text-dark caret-dark selection:bg-secondary focus:border-dark focus:outline focus:outline-2 focus:outline-offset-2 focus:outline-dark" />
              <.field_errors field={@form[:link_text]} />
            </div>
            <div>
              <label for={@form[:position].id} class="text-sm font-semibold">Orden en el archivo</label>
              <input id={@form[:position].id} name={@form[:position].name} value={@form[:position].value} type="number" required min="0" step="1" class="mt-2 block min-h-11 w-full border border-muted bg-light px-3 py-2 text-dark caret-dark selection:bg-secondary focus:border-dark focus:outline focus:outline-2 focus:outline-offset-2 focus:outline-dark" />
              <p class="mt-2 text-sm text-muted">Los números menores aparecen primero.</p>
              <.field_errors field={@form[:position]} />
            </div>
            <div>
              <label for={@uploads.photo.ref} class="text-sm font-semibold">Foto</label>
              <.live_file_input upload={@uploads.photo} class="mt-2 block min-h-11 w-full text-sm file:mr-3 file:min-h-11 file:border-0 file:bg-primary file:px-3 file:text-dark focus-visible:outline focus-visible:outline-2 focus-visible:outline-dark" />
              <p class="mt-2 text-sm text-muted">JPG, PNG o WebP. Máximo 10 MB.</p>
              <img :if={@editing_exhibition && @uploads.photo.entries == []} src={@editing_exhibition.photo} alt="Foto actual de la exposición" class="mt-3 h-24 w-24 border border-primary object-cover" />
              <div :for={entry <- @uploads.photo.entries} class="mt-3">
                <.live_img_preview entry={entry} class="h-24 w-24 border border-primary object-cover" />
                <p class="mt-2 break-words text-sm text-muted">{entry.client_name}</p>
                <p :for={error <- upload_errors(@uploads.photo, entry)} role="alert" class="mt-2 text-sm text-dark">{upload_error_message(error)}</p>
                <button type="button" phx-click="cancel-photo" phx-value-ref={entry.ref} class="mt-2 min-h-11 px-3 text-sm font-semibold underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-dark">Quitar foto seleccionada</button>
              </div>
              <p :for={error <- upload_errors(@uploads.photo)} role="alert" class="mt-2 text-sm text-dark">{upload_error_message(error)}</p>
              <.field_errors field={@form[:photo]} />
            </div>
            <div class="flex flex-wrap gap-3 pt-2">
              <button type="submit" phx-disable-with="Guardando…" class="min-h-11 bg-primary px-5 py-2 font-semibold transition hover:bg-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark">{if @editing_exhibition, do: "Guardar cambios", else: "Guardar exposición"}</button>
              <button :if={@editing_exhibition} type="button" phx-click="cancel-edit" class="min-h-11 border border-dark px-5 py-2 font-semibold transition hover:bg-secondary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark">Cancelar</button>
            </div>
          </.form>
        </aside>
      </div>
    </section>
    """
  end

  attr(:field, Phoenix.HTML.FormField, required: true)

  defp field_errors(assigns) do
    ~H"""
    <p :for={error <- @field.errors} role="alert" class="mt-2 text-sm text-dark">{translate_error(error)}</p>
    """
  end

  defp editable_exhibition(nil), do: %Exhibition{photo: "/uploads/exhibitions/pending.webp"}
  defp editable_exhibition(exhibition), do: exhibition
  defp save_exhibition(nil, attrs), do: Exhibitions.create_exhibition(attrs)
  defp save_exhibition(exhibition, attrs), do: Exhibitions.update_exhibition(exhibition, attrs)

  defp persist_uploaded_photo(socket, existing_photo) do
    case consume_uploaded_entries(socket, :photo, fn %{path: source_path}, entry ->
           filename =
             "#{Ecto.UUID.generate()}#{entry.client_name |> Path.extname() |> String.downcase()}"

           destination = Path.join(photo_directory(), filename)
           File.mkdir_p!(Path.dirname(destination))
           File.cp!(source_path, destination)
           {:ok, "/uploads/exhibitions/#{filename}"}
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
    :anartista |> :code.priv_dir() |> to_string() |> Path.join("static/uploads/exhibitions")
  end

  defp delete_photo("/uploads/exhibitions/" <> filename) do
    if Path.basename(filename) == filename, do: File.rm(Path.join(photo_directory(), filename))
    :ok
  end

  defp delete_photo(_photo), do: :ok
  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))

  defp refresh_exhibitions(socket),
    do: assign(socket, :exhibitions, Exhibitions.list_exhibitions())

  defp reset_editor(socket) do
    socket
    |> assign(:editing_exhibition, nil)
    |> assign_form(Exhibitions.change_exhibition(%Exhibition{}))
  end

  defp upload_error_message(:too_large),
    do: "La foto supera el límite de 10 MB. Elige una más pequeña."

  defp upload_error_message(:not_accepted), do: "Elige una foto JPG, PNG o WebP."
  defp upload_error_message(:too_many_files), do: "Elige una sola foto."

  defp upload_error_message(_error),
    do: "No fue posible cargar esta foto. Vuelve a seleccionarla."
end
