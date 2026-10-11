defmodule AnartistaWeb.Admin.DashboardLive do
  use AnartistaWeb, :live_view

  import AnartistaWeb.AdminComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Administración")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_navigation current={:dashboard} />
    <section class="bg-light px-4 py-16">
      <div class="mx-auto max-w-6xl">
        <div class="border-b border-primary/60 pb-6">
          <h1 class="font-serif text-4xl leading-none text-dark sm:text-5xl">Administración</h1>
          <p class="mt-4 max-w-2xl text-dark/80">Elige una sección para revisar mensajes o actualizar el contenido del sitio.</p>
        </div>

        <div id="admin-areas" class="mt-8 divide-y divide-secondary border-y border-secondary">
          <.link navigate={~p"/admin/messages"} class="group flex min-h-11 flex-col gap-2 px-4 py-6 text-dark no-underline transition hover:bg-secondary/30 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark sm:flex-row sm:items-baseline sm:gap-8">
            <h2 class="font-serif text-2xl group-hover:underline decoration-primary underline-offset-4 sm:w-48 sm:shrink-0">Mensajes</h2>
            <p class="max-w-2xl text-muted">Consulta los mensajes de contacto, márcalos como leídos o elimínalos.</p>
          </.link>
          <.link navigate={~p"/admin/store"} class="group flex min-h-11 flex-col gap-2 px-4 py-6 text-dark no-underline transition hover:bg-secondary/30 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark sm:flex-row sm:items-baseline sm:gap-8">
            <h2 class="font-serif text-2xl group-hover:underline decoration-primary underline-offset-4 sm:w-48 sm:shrink-0">Tienda</h2>
            <p class="max-w-2xl text-muted">Agrega y edita piezas, sus fotografías, precios y disponibilidad.</p>
          </.link>
          <.link navigate={~p"/admin/exhibitions"} class="group flex min-h-11 flex-col gap-2 px-4 py-6 text-dark no-underline transition hover:bg-secondary/30 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark sm:flex-row sm:items-baseline sm:gap-8">
            <h2 class="font-serif text-2xl group-hover:underline decoration-primary underline-offset-4 sm:w-48 sm:shrink-0">Exposiciones</h2>
            <p class="max-w-2xl text-muted">Agrega y edita exposiciones, sus fechas, sedes, fotografías y descripciones.</p>
          </.link>
          <.link navigate={~p"/admin/obra"} class="group flex min-h-11 flex-col gap-2 px-4 py-6 text-dark no-underline transition hover:bg-secondary/30 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark sm:flex-row sm:items-baseline sm:gap-8">
            <h2 class="font-serif text-2xl group-hover:underline decoration-primary underline-offset-4 sm:w-48 sm:shrink-0">Obra</h2>
            <p class="max-w-2xl text-muted">Agrega y edita obras, sus fotografías y fichas; elige cuáles aparecen en Acerca de.</p>
          </.link>
          <.link navigate={~p"/admin/exhibit"} class="group flex min-h-11 flex-col gap-2 px-4 py-6 text-dark no-underline transition hover:bg-secondary/30 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dark sm:flex-row sm:items-baseline sm:gap-8">
            <h2 class="font-serif text-2xl group-hover:underline decoration-primary underline-offset-4 sm:w-48 sm:shrink-0">Exhibit</h2>
            <p class="max-w-2xl text-muted">Crea y ordena salas de la galería virtual, elige su distribución y las obras que muestran.</p>
          </.link>
        </div>
      </div>
    </section>
    """
  end
end
