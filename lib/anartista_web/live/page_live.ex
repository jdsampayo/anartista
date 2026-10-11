defmodule AnartistaWeb.PageLive do
  use AnartistaWeb, :live_view

  alias Anartista.{Artworks, Exhibit, Exhibitions, Store}

  import AnartistaWeb.ArtComponents
  import AnartistaWeb.ShopComponents
  import AnartistaWeb.ExhibitComponents

  embed_templates("page_live/*")

  @empty_content %{
    featured_piece: nil,
    pieces_by_category: [],
    selected_artworks: [],
    artworks_by_category: [],
    rooms: [],
    categories: [],
    current_category: nil,
    exhibitions: [],
    substack_posts: []
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :public_page, true)}
  end

  @impl true
  def handle_params(params, uri, socket) do
    path = URI.parse(uri).path
    {title, description, content} = page(socket.assigns.live_action, params)

    {:noreply,
     socket
     |> assign(@empty_content)
     |> assign(content)
     |> assign(
       page_title: title,
       meta_description: description,
       meta_image: "https://anartista.com" <> ~p"/images/apple-touch-icon.png",
       og_url: "https://anartista.com" <> path,
       page_path: path
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="public-page"
      phx-hook="PublicPage"
      data-page-title={@page_title}
      data-description={@meta_description}
      data-image={@meta_image}
      data-url={@og_url}
      data-path={@page_path}
    >
      <%= case @live_action do %>
        <% :home -> %>
          {home(assigns)}
        <% :about -> %>
          {about(assigns)}
        <% :obra -> %>
          {obra(assigns)}
        <% :exhibit -> %>
          {exhibit(assigns)}
        <% :exhibitions -> %>
          {exhibitions(assigns)}
        <% :writing -> %>
          {writing(assigns)}
        <% :contact -> %>
          {contact(assigns)}
      <% end %>
    </div>
    """
  end

  defp page(:home, _params) do
    {"Tienda",
     "Piezas únicas y artesanía de Ana Alvarez Vega, disponibles directamente desde su estudio.",
     %{
       featured_piece: Store.latest_available_piece(),
       pieces_by_category: Store.list_pieces_by_category()
     }}
  end

  defp page(:about, _params) do
    {"Acerca de Ana",
     "La práctica multidisciplinaria de Ana Alvarez Vega: mosaico, pintura, grabado, escultura y dibujo.",
     %{selected_artworks: Artworks.list_selected_artworks()}}
  end

  defp page(:obra, params) do
    category = if is_binary(params["type"]), do: params["type"], else: nil

    artworks_by_category =
      Artworks.list_artworks(category: category)
      |> Enum.group_by(& &1.category)
      |> Enum.sort_by(fn {type, _artworks} -> String.downcase(type) end)

    {"Obra", "Archivo de obra, técnicas y materiales.",
     %{
       categories: Artworks.list_categories(),
       current_category: category,
       artworks_by_category: artworks_by_category
     }}
  end

  defp page(:exhibit, params) do
    category = if is_binary(params["type"]), do: params["type"], else: nil
    rooms = Exhibit.list_rooms(category: category)
    all_rooms = if category in [nil, ""], do: rooms, else: Exhibit.list_rooms()

    categories =
      all_rooms
      |> Enum.flat_map(& &1.artworks)
      |> Enum.map(& &1.category)
      |> Enum.uniq()
      |> Enum.sort_by(&String.downcase/1)

    {"Exhibit", "Un recorrido tridimensional por la obra de Ana Alvarez Vega.",
     %{rooms: rooms, categories: categories, current_category: category}}
  end

  defp page(:exhibitions, _params) do
    {"Exposiciones",
     "Archivo de exposiciones, encuentros y contextos de la obra de Ana Alvarez Vega.",
     %{exhibitions: Exhibitions.list_exhibitions()}}
  end

  defp page(:writing, _params) do
    {"Escritos", "Notas y procesos de la práctica artística de Ana Alvarez Vega.",
     %{substack_posts: Anartista.Substack.posts(6)}}
  end

  defp page(:contact, _params) do
    {"Contacto",
     "Contacta a Ana Alvarez Vega para conversar sobre obra, colaboración o exposición.", %{}}
  end
end
