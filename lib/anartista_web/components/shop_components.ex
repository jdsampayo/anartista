defmodule AnartistaWeb.ShopComponents do
  use Phoenix.Component

  @doc """
  Card of a product
  """
  attr :name, :string, required: true
  attr :price, :integer, required: true
  attr :category, :string, required: true
  attr :image, :string, required: true
  attr :description, :string, default: nil
  attr :sold_out, :boolean, default: false

  def product_card(assigns) do
    ~H"""
    <div class={[
      "group relative flex flex-col bg-white rounded-xl overflow-hidden shadow-md hover:shadow-xl transition-shadow duration-300",
      @sold_out && "opacity-60"
    ]}>
      <!-- Badge sold -->
      <%= if @sold_out do %>
        <span class="absolute top-3 right-3 z-10 bg-dark text-light text-xs font-semibold px-3 py-1 rounded-full">
          Agotado
        </span>
      <% end %>

      <!-- Image -->
      <div class="relative overflow-hidden aspect-square bg-gray-100">
        <img
          src={"/images/tienda/#{@image}.jpeg"}
          alt={@name}
          class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
          loading="lazy"
        />
      </div>

      <!-- Info -->
      <div class="flex flex-col flex-1 p-5 gap-2">
        <span class="text-xs uppercase tracking-widest text-primary font-semibold"><%= @category %></span>
        <h3 class="font-serif text-lg text-dark leading-tight"><%= @name %></h3>
        <%= if @description do %>
          <p class="text-sm text-gray-500 flex-1"><%= @description %></p>
        <% end %>
        <p class="text-xl font-bold text-dark mt-2">
          $<%= :erlang.integer_to_list(@price) |> to_string() %> <span class="text-sm font-normal text-gray-400">MXN</span>
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Category.
  """
  attr :title, :string, required: true

  def category_heading(assigns) do
    ~H"""
    <h2 class="font-serif text-2xl text-dark mb-6 pb-2 border-b border-primary/30">
      <%= @title %>
    </h2>
    """
  end
end
