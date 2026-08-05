defmodule AnartistaWeb.ShopComponents do
  use Phoenix.Component

  alias Anartista.Store.Piece

  attr :piece, Piece, required: true

  def piece_card(assigns) do
    ~H"""
    <article class="group flex h-full flex-col border border-secondary bg-white shadow-lg transition duration-300 hover:-translate-y-1 hover:shadow-xl">
      <div class="relative aspect-square overflow-hidden bg-cement">
        <img src={@piece.photo} alt={@piece.name} class="h-full w-full object-cover transition duration-500 group-hover:scale-105" loading="lazy" />
        <span :if={!@piece.available} class="absolute left-0 top-0 bg-accent px-4 py-2 text-sm font-semibold text-dark">Vendida</span>
      </div>
      <div class="flex flex-1 flex-col p-6">
        <h2 class="font-serif text-2xl leading-tight text-dark">{@piece.name}</h2>
        <p class="mt-3 flex-1 leading-relaxed text-dark/80">{@piece.description}</p>
        <div class="mt-6 flex items-end justify-between gap-4 border-t border-secondary/70 pt-4">
          <p class="text-lg font-semibold text-dark">${format_price(@piece.price)}</p>
          <a
            :if={@piece.available}
            href={@piece.payment_link}
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex min-h-11 items-center bg-primary px-4 py-2 text-sm font-semibold text-dark no-underline transition hover:bg-accent focus-visible:bg-accent"
          >
            Comprar
          </a>
          <span :if={!@piece.available} class="text-sm font-semibold text-muted">Archivo de obra</span>
        </div>
      </div>
    </article>
    """
  end

  defp format_price(price), do: Decimal.to_string(price, :normal)
end
