defmodule AnartistaWeb.ArtComponents do
  use Phoenix.Component

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :image_src, :string, required: true
  attr :image_alt, :string, required: true
  def category_card(assigns) do
    ~H"""
    <div class="bg-white bg-opacity-10 rounded-lg overflow-hidden transition transform duration-300 hover:-translate-y-2">
      <div class="h-64 overflow-hidden">
        <img src={@image_src} alt={@image_alt} class="w-full h-full object-cover transition duration-500 hover:scale-110 lightbox-trigger">
      </div>
      <div class="p-5">
        <h3 class="font-serif text-2xl mb-3"><%= @title %></h3>
        <p class="text-sm text-opacity-80"><%= @description %></p>
      </div>
    </div>
    """
  end

  attr :image_src, :string, required: true
  attr :image_alt, :string, required: true
  attr :title, :string, default: nil
  attr :description, :string, default: nil
  def mosaic_gallery_item(assigns) do
    ~H"""
    <div class="rounded-lg overflow-hidden shadow-md relative pt-[100%] group">
      <img
        src={@image_src}
        alt={@image_alt}
        class="absolute top-0 left-0 w-full h-full object-cover transition duration-500 hover:scale-110 lightbox-trigger"
      />
      <%= if @title do %>
        <div class="absolute bottom-0 left-0 w-full bg-black bg-opacity-70 text-white p-3 opacity-0 group-hover:opacity-100 transition duration-300">
          <h4 class="font-serif text-lg"><%= @title %></h4>
          <%= if @description do %>
            <p class="text-sm opacity-80"><%= @description %></p>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
