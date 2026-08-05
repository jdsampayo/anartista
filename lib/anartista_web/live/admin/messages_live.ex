defmodule AnartistaWeb.Admin.MessagesLive do
  use AnartistaWeb, :live_view

  alias Anartista.Contact

  import AnartistaWeb.AdminComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :messages, Contact.list_messages())}
  end

  @impl true
  def handle_event("toggle-read", %{"id" => id}, socket) do
    message = Contact.get_message!(id)
    {:ok, updated_message} = Contact.toggle_message_read(message)

    {:noreply,
     socket
     |> put_flash(:info, read_message(updated_message))
     |> refresh_messages()}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    message = Contact.get_message!(id)
    {:ok, _deleted_message} = Contact.delete_message(message)

    {:noreply,
     socket
     |> put_flash(:info, "Mensaje eliminado.")
     |> refresh_messages()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_navigation current={:messages} />
    <section class="bg-light px-4 py-16">
      <div class="mx-auto max-w-6xl">
        <div class="border-b border-primary/60 pb-6">
          <h1 class="font-serif text-4xl leading-none text-dark sm:text-5xl">Mensajes</h1>
          <p class="mt-4 max-w-2xl text-dark/80">Consulta, marca y elimina los mensajes recibidos desde el formulario de contacto.</p>
        </div>

        <div :if={@messages == []} class="mt-8 border border-secondary bg-white px-6 py-16 text-center shadow-lg">
          <p class="font-serif text-3xl text-dark">Aún no hay mensajes.</p>
        </div>

        <div :if={@messages != []} class="mt-8 overflow-x-auto border border-secondary bg-white shadow-lg">
          <table class="min-w-[56rem] divide-y divide-secondary/70 text-left">
            <thead class="bg-dark text-light">
              <tr>
                <th class="px-4 py-3 text-xs font-semibold uppercase tracking-[0.14em]">Remitente</th>
                <th class="px-4 py-3 text-xs font-semibold uppercase tracking-[0.14em]">Asunto y mensaje</th>
                <th class="px-4 py-3 text-xs font-semibold uppercase tracking-[0.14em]">Estado</th>
                <th class="px-4 py-3 text-right text-xs font-semibold uppercase tracking-[0.14em]">Acciones</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-cement">
              <tr :for={message <- @messages} id={"message-#{message.id}"} class={["align-top", !message.read && "bg-secondary/20 font-semibold"]}>
                <td class="px-4 py-4">
                  <p class="text-dark">{message.name}</p>
                  <a href={"mailto:#{message.email}"} class="mt-1 inline-block text-sm font-normal text-muted underline decoration-primary decoration-2 underline-offset-4 hover:decoration-accent">{message.email}</a>
                </td>
                <td class="px-4 py-4">
                  <p class="text-dark">{message.subject}</p>
                  <p class="mt-2 max-w-xl whitespace-pre-line text-sm font-normal leading-relaxed text-muted">{message.message}</p>
                </td>
                <td class="px-4 py-4">
                  <button
                    type="button"
                    phx-click="toggle-read"
                    phx-value-id={message.id}
                    class={[
                      "min-h-11 border px-3 py-2 text-sm font-semibold transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark",
                      message.read && "border-primary bg-primary text-dark hover:bg-accent",
                      !message.read && "border-accent bg-accent/20 text-dark hover:bg-secondary"
                    ]}
                  >
                    {read_label(message.read)}
                  </button>
                </td>
                <td class="px-4 py-4 text-right">
                  <button type="button" phx-click="delete" phx-value-id={message.id} data-confirm="¿Eliminar este mensaje?" class="min-h-11 border border-accent px-3 py-2 text-sm font-semibold text-dark transition hover:bg-accent focus-visible:bg-accent">Eliminar</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
    """
  end

  defp refresh_messages(socket), do: assign(socket, :messages, Contact.list_messages())
  defp read_label(true), do: "Leído"
  defp read_label(false), do: "No leído"
  defp read_message(%{read: true}), do: "El mensaje se marcó como leído."
  defp read_message(%{read: false}), do: "El mensaje se marcó como no leído."
end
