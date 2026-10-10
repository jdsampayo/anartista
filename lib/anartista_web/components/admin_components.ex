defmodule AnartistaWeb.AdminComponents do
  use Phoenix.Component

  attr(:current, :atom, required: true)

  def admin_navigation(assigns) do
    ~H"""
    <nav class="mt-20 border-b border-secondary/70 bg-dark px-4 py-3 text-light" aria-label="Administración">
      <div class="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3">
        <span class="text-sm font-semibold">Administración</span>
        <div class="flex flex-wrap items-center gap-2">
          <a
            href="/admin"
            aria-current={if @current == :dashboard, do: "page"}
            class={[
              "inline-flex min-h-11 items-center px-3 text-sm font-semibold no-underline transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-light",
              @current == :dashboard && "bg-primary text-dark",
              @current != :dashboard && "text-light hover:bg-light hover:text-dark"
            ]}
          >
            Inicio
          </a>
          <a
            href="/admin/store"
            aria-current={if @current == :store, do: "page"}
            class={[
              "inline-flex min-h-11 items-center px-3 text-sm font-semibold no-underline transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-light",
              @current == :store && "bg-primary text-dark",
              @current != :store && "text-light hover:bg-light hover:text-dark"
            ]}
          >
            Tienda
          </a>
          <a
            href="/admin/messages"
            aria-current={if @current == :messages, do: "page"}
            class={[
              "inline-flex min-h-11 items-center px-3 text-sm font-semibold no-underline transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-light",
              @current == :messages && "bg-primary text-dark",
              @current != :messages && "text-light hover:bg-light hover:text-dark"
            ]}
          >
            Mensajes
          </a>
          <a
            href="/admin/exhibitions"
            aria-current={if @current == :exhibitions, do: "page"}
            class={[
              "inline-flex min-h-11 items-center px-3 text-sm font-semibold no-underline transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-light",
              @current == :exhibitions && "bg-primary text-dark",
              @current != :exhibitions && "text-light hover:bg-light hover:text-dark"
            ]}
          >
            Exposiciones
          </a>
          <a
            href="/admin/obra"
            aria-current={if @current == :artworks, do: "page"}
            class={[
              "inline-flex min-h-11 items-center px-3 text-sm font-semibold no-underline transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-light",
              @current == :artworks && "bg-primary text-dark",
              @current != :artworks && "text-light hover:bg-light hover:text-dark"
            ]}
          >
            Obra
          </a>
          <.form for={%{}} action="/admin/logout" method="delete">
            <button type="submit" class="min-h-11 border border-light/60 px-3 text-sm font-semibold text-light transition hover:bg-light hover:text-dark focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-light">
              Cerrar sesión
            </button>
          </.form>
        </div>
      </div>
    </nav>
    """
  end
end
