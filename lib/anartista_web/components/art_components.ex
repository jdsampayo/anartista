defmodule AnartistaWeb.ArtComponents do
  use Phoenix.Component

  attr(:artwork, :map, required: true)
  attr(:layout, :string, default: "record")

  def artwork_card(assigns) do
    assigns =
      assigns
      |> assign(:image, artwork_image(assigns.artwork.photo))
      |> assign(:details, artwork_details(assigns.artwork))

    ~H"""
    <article
      id={"artwork-#{@artwork.id}"}
      class={[
        "min-w-0 border-t border-secondary/50 pt-4",
        @layout == "record" && "grid gap-6 lg:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)] lg:gap-10",
        @layout == "wide" && "lg:col-span-7",
        @layout == "tall" && "lg:col-span-5"
      ]}
    >
      <a
        href={@artwork.photo}
        data-hires={@artwork.photo}
        data-caption={@artwork.image_alt}
        target="_blank"
        rel="noopener noreferrer"
        aria-label={"Ver imagen completa: #{@artwork.title}"}
        class="lightbox-trigger block overflow-hidden bg-dark focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-secondary"
      >
        <img
          src={@image.src}
          srcset={@image.srcset}
          alt={@artwork.image_alt}
          loading="lazy"
          class={[
            "w-full object-contain",
            @layout == "record" && "h-80 sm:h-[28rem] lg:h-[34rem]",
            @layout != "record" && "h-72 lg:h-[30rem]"
          ]}
        />
      </a>
      <div class="min-w-0 py-5">
        <h3 class="break-words font-serif text-3xl leading-tight text-light">{@artwork.title}</h3>
        <dl class="mt-5 grid gap-x-6 gap-y-3 text-sm leading-relaxed sm:grid-cols-2">
          <div :for={{label, value} <- @details} class="min-w-0">
            <dt class="font-semibold text-secondary">{label}</dt>
            <dd class="mt-1 whitespace-pre-line break-words text-light">{value}</dd>
          </div>
        </dl>
        <p :if={@artwork.description} class="mt-5 max-w-prose whitespace-pre-line break-words text-sm leading-relaxed text-light/85">{@artwork.description}</p>
      </div>
    </article>
    """
  end

  defp artwork_details(artwork) do
    [
      {"Tipo", artwork.category},
      {"Fecha", artwork.year},
      {"Técnica", artwork.technique},
      {"Materiales", artwork.materials},
      {"Dimensiones", artwork.dimensions},
      {"Edición", artwork.edition},
      {"Colección / ubicación", artwork.collection}
    ]
    |> Enum.reject(fn {_label, value} -> is_nil(value) or value == "" end)
  end

  defp artwork_image("/images/portafolio/" <> filename) do
    base = String.trim_trailing(filename, ".webp")

    %{
      src: "/images/portafolio/#{base}_thumb.webp",
      srcset:
        "/images/portafolio/#{base}_thumb.webp 1x, /images/portafolio/#{base}_thumb@2x.webp 2x"
    }
  end

  defp artwork_image(photo), do: %{src: photo, srcset: nil}

  attr(:image_name, :string, required: true)
  attr(:description, :string, required: true)

  def mosaic_gallery_item(assigns) do
    ~H"""
    <div class="border border-primary/40 rounded-lg overflow-hidden shadow-md relative pt-[100%] group">
      <img
        width="488"
        height="488"
        data-hires={"/images/mosaicos/#{@image_name}.webp"}
        src={"/images/mosaicos/#{@image_name}_thumb.webp"}
        srcset={"/images/mosaicos/#{@image_name}_thumb.webp 1x, /images/mosaicos/#{@image_name}_thumb@2x.webp 2x"}
        alt={@description}
        class="absolute top-0 left-0 w-full h-full object-cover transition duration-500 hover:scale-110 lightbox-trigger"
      />
      <div class="absolute bottom-0 left-0 w-full bg-dark/95 text-light p-3 opacity-0 group-hover:opacity-100 transition duration-300">
        <h4 class="font-serif text-lg"><%= @description %></h4>
      </div>
    </div>
    """
  end

  attr(:title, :string, required: true)
  attr(:subtitle, :string, default: nil)
  attr(:date, :string, required: true)
  attr(:location, :string, required: true)
  attr(:opening, :string, default: nil)
  attr(:photo, :string, required: true)
  attr(:image_alt, :string, required: true)
  attr(:description, :string, required: true)
  attr(:link_url, :string, default: nil)
  attr(:link_text, :string, default: "Visitar sitio")

  def exhibition_card(assigns) do
    assigns = assign(assigns, :image, exhibition_image(assigns.photo))

    ~H"""
    <div class="bg-white border border-accent/25 rounded-lg shadow-lg overflow-hidden flex flex-col md:flex-row mb-12">
      <div class="md:w-2/5 relative h-64 md:h-auto overflow-hidden">
        <img
          width="602"
          height="252"
          data-hires={@photo}
          src={@image.src}
          srcset={@image.srcset}
          alt={@image_alt}
          class="absolute inset-0 w-full h-full object-cover transition duration-500 hover:scale-110 lightbox-trigger"
        />
      </div>
      <div class="md:w-3/5 p-6 md:p-8 flex flex-col">
        <div class="mb-4">
          <h3 class="font-serif text-2xl md:text-3xl font-bold text-dark mb-1"><%= @title %></h3>
          <%= if @subtitle do %>
            <h4 class="text-lg text-muted mb-2"><%= @subtitle %></h4>
          <% end %>
          <div class="flex flex-wrap gap-4 text-sm text-muted mb-4">
            <span class="flex items-center">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              <%= @date %>
            </span>
            <span class="flex items-center">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
              <%= @location %>
            </span>
            <span :if={@opening} class="flex items-center">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <%= @opening %>
            </span>
          </div>
        </div>
        <p class="text-dark/80 mb-6 flex-grow"><%= @description %></p>
        <%= if @link_url do %>
          <div class="mt-auto">
            <a href={@link_url} aria-label={@image_alt} target="_blank" rel="noopener noreferrer" class="inline-flex items-center text-dark underline decoration-primary decoration-2 underline-offset-4 hover:decoration-accent focus-visible:decoration-accent font-semibold transition">
              <%= @link_text %>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 ml-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
              </svg>
            </a>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp exhibition_image("/images/exposiciones/" <> filename) do
    base = String.trim_trailing(filename, ".webp")

    %{
      src: "/images/exposiciones/#{base}_thumb.webp",
      srcset:
        "/images/exposiciones/#{base}_thumb.webp 1x, /images/exposiciones/#{base}_thumb@2x.webp 2x"
    }
  end

  defp exhibition_image(photo), do: %{src: photo, srcset: nil}

  attr(:post, :map, required: true)

  def writing_card(assigns) do
    ~H"""
    <a
      href={@post.link}
      target="_blank"
      rel="noopener noreferrer"
      class="block bg-white border border-secondary/50 rounded-lg shadow-lg overflow-hidden transition transform duration-300 hover:-translate-y-2 group"
    >
      <div :if={@post.image != ""} class="h-48 overflow-hidden">
        <img
          src={@post.image}
          alt={@post.title}
          loading="lazy"
          class="w-full h-full object-cover transition duration-500 group-hover:scale-110"
        />
      </div>
      <div class="p-6">
        <p class="text-sm text-muted mb-2"><%= @post.pub_date %></p>
        <h3 class="font-serif text-2xl mb-3 text-dark"><%= @post.title %></h3>
        <p class="text-dark/80 text-sm mb-4"><%= @post.description %></p>
        <span class="inline-flex items-center text-dark underline decoration-primary decoration-2 underline-offset-4 font-semibold text-sm group-hover:decoration-accent">
          Leer en Substack
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 ml-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 4h6m0 0v6m0-6L10 14" />
          </svg>
        </span>
      </div>
    </a>
    """
  end
end
