defmodule AnartistaWeb.ShopComponents do
  use Phoenix.Component

  alias Anartista.Store.Piece

  attr :piece, Piece, required: true

  def featured_piece(assigns) do
    ~H"""
    <article class="grid overflow-hidden border border-secondary/70 bg-dark text-light shadow-2xl lg:grid-cols-[minmax(0,1.15fr)_minmax(22rem,0.85fr)]">
      <div class="relative min-h-80 bg-cement sm:min-h-[34rem]">
        <img
          src={@piece.photo}
          alt={@piece.name}
          class="absolute inset-0 h-full w-full object-cover"
          fetchpriority="high"
        />
        <div class="absolute inset-x-0 bottom-0 bg-dark/85 px-5 py-4 sm:px-7">
          <p class="font-serif text-xl text-light">{@piece.category}</p>
        </div>
      </div>
      <div class="flex flex-col px-6 py-8 sm:px-10 sm:py-12">
        <h1 class="font-serif text-5xl leading-none text-light sm:text-6xl">{@piece.name}</h1>
        <p class="mt-6 flex-1 text-lg leading-relaxed text-light/85">{@piece.description}</p>

        <dl :if={piece_details(@piece) != []} class="mt-8 grid gap-x-5 gap-y-4 border-y border-secondary/50 py-5 text-sm sm:grid-cols-3">
          <div :for={{label, value} <- piece_details(@piece)}>
            <dt class="font-semibold text-secondary">{label}</dt>
            <dd class="mt-1 text-light">{value}</dd>
          </div>
        </dl>

        <div class="mt-8 flex flex-wrap items-center justify-between gap-5">
          <p class="font-serif text-3xl text-light">${format_price(@piece.price)}</p>
          <a
            href={@piece.payment_link}
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex min-h-11 items-center bg-primary px-6 py-2 font-semibold text-dark no-underline transition hover:bg-accent focus-visible:bg-accent"
          >
            Comprar
          </a>
        </div>
      </div>
    </article>
    """
  end

  attr :piece, Piece, required: true

  def piece_card(assigns) do
    ~H"""
    <article class="group flex h-full flex-col border border-secondary bg-white shadow-lg transition duration-300 hover:-translate-y-1 hover:shadow-xl">
      <div class="relative aspect-square overflow-hidden bg-cement">
        <img src={@piece.photo} alt={@piece.name} class="h-full w-full object-cover transition duration-500 group-hover:scale-105" loading="lazy" />
        <span :if={!@piece.available} class="absolute left-0 top-0 bg-accent px-4 py-2 text-sm font-semibold text-dark">Vendida</span>
      </div>
      <div class="flex flex-1 flex-col p-6">
        <h3 class="font-serif text-2xl leading-tight text-dark">{@piece.name}</h3>
        <p class="mt-3 flex-1 leading-relaxed text-dark/80">{@piece.description}</p>

        <dl :if={piece_details(@piece) != []} class="mt-4 grid gap-x-4 gap-y-2 border-t border-secondary/50 pt-4 text-sm text-muted sm:grid-cols-3">
          <div :for={{label, value} <- piece_details(@piece)}>
            <dt class="font-semibold text-dark">{label}</dt>
            <dd class="mt-0.5">{value}</dd>
          </div>
        </dl>
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

  defp piece_details(piece) do
    [
      {"Técnica", piece.technique},
      {"Dimensiones", piece.dimensions},
      {"Año", piece.year}
    ]
    |> Enum.reject(fn {_label, value} -> is_nil(value) or value == "" end)
  end
end
