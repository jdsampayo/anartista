defmodule AnartistaWeb.AdminComponents do
  use Phoenix.Component

  attr :current, :atom, required: true

  def admin_navigation(assigns) do
    ~H"""
    <nav class="mt-20 border-b border-secondary/70 bg-dark px-4 py-3 text-light" aria-label="Administración">
      <div class="mx-auto flex max-w-6xl items-center justify-between gap-4">
        <span class="text-sm font-semibold">Administración</span>
        <div class="flex items-center gap-2">
          <a
            href="/admin/store"
            aria-current={if @current == :store, do: "page"}
            class={[
              "inline-flex min-h-9 items-center px-3 text-sm font-semibold no-underline transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-light",
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
              "inline-flex min-h-9 items-center px-3 text-sm font-semibold no-underline transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-light",
              @current == :messages && "bg-primary text-dark",
              @current != :messages && "text-light hover:bg-light hover:text-dark"
            ]}
          >
            Mensajes
          </a>
        </div>
      </div>
    </nav>
    """
  end
end
