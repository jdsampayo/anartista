defmodule AnartistaWeb.ArtComponents do
  use Phoenix.Component

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :image_name, :string, required: true
  def category_card(assigns) do
    ~H"""
    <div class="bg-white bg-opacity-10 rounded-lg overflow-hidden transition transform duration-300 hover:-translate-y-2">
      <div class="h-64 overflow-hidden">
        <img
        width="480"
        height="256"
        data-hires={"/images/portafolio/#{@image_name}.webp"}
        src={"/images/portafolio/#{@image_name}_thumb.webp"}
        srcset={"/images/portafolio/#{@image_name}_thumb.webp 1x, /images/portafolio/#{@image_name}_thumb@2x.webp 2x"}
        alt={@title}
        class="w-full h-full object-cover transition duration-500 hover:scale-110 lightbox-trigger"
      />
      </div>
      <div class="p-5">
        <h3 class="font-serif text-2xl mb-3"><%= @title %></h3>
        <p class="text-sm text-opacity-80"><%= @description %></p>
      </div>
    </div>
    """
  end

  attr :image_name, :string, required: true
  attr :description, :string, required: true
  def mosaic_gallery_item(assigns) do
    ~H"""
    <div class="rounded-lg overflow-hidden shadow-md relative pt-[100%] group">
      <img
        width="488"
        height="488"
        data-hires={"/images/mosaicos/#{@image_name}.webp"}
        src={"/images/mosaicos/#{@image_name}_thumb.webp"}
        srcset={"/images/mosaicos/#{@image_name}_thumb.webp 1x, /images/mosaicos/#{@image_name}_thumb@2x.webp 2x"}
        alt={@description}
        class="absolute top-0 left-0 w-full h-full object-cover transition duration-500 hover:scale-110 lightbox-trigger"
      />
      <div class="absolute bottom-0 left-0 w-full bg-black bg-opacity-70 text-white p-3 opacity-0 group-hover:opacity-100 transition duration-300">
        <h4 class="font-serif text-lg"><%= @description %></h4>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :date, :string, required: true
  attr :location, :string, required: true
  attr :opening, :string, required: true
  attr :image_name, :string, required: true
  attr :image_alt, :string, required: true
  attr :description, :string, required: true
  attr :link_url, :string, default: nil
  attr :link_text, :string, default: "Visitar sitio"

  def exhibition_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-lg overflow-hidden flex flex-col md:flex-row mb-12">
      <div class="md:w-2/5 relative h-64 md:h-auto overflow-hidden">
        <img
          width="602"
          height="252"
          data-hires={"/images/exposiciones/#{@image_name}.webp"}
          src={"/images/exposiciones/#{@image_name}_thumb.webp"}
          srcset={"/images/exposiciones/#{@image_name}_thumb.webp 1x, /images/exposiciones/#{@image_name}_thumb@2x.webp 2x"}
          alt={@image_alt}
          class="absolute inset-0 w-full h-full object-cover transition duration-500 hover:scale-110 lightbox-trigger"
        />
      </div>
      <div class="md:w-3/5 p-6 md:p-8 flex flex-col">
        <div class="mb-4">
          <h3 class="font-serif text-2xl md:text-3xl font-bold text-primary mb-1"><%= @title %></h3>
          <%= if @subtitle do %>
            <h4 class="text-lg text-dark/80 mb-2"><%= @subtitle %></h4>
          <% end %>
          <div class="flex flex-wrap gap-4 text-sm text-dark/70 mb-4">
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
            <span class="flex items-center">
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
            <a href={@link_url} target="_blank" rel="noopener noreferrer" class="inline-flex items-center text-primary hover:text-primary/80 font-semibold transition">
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
end
