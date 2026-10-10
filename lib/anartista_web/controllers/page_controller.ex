defmodule AnartistaWeb.PageController do
  use AnartistaWeb, :controller

  alias Anartista.Store
  alias Anartista.Exhibitions
  alias Anartista.Artworks

  def home(conn, _params) do
    render(conn, :home,
      page_title: "Tienda",
      meta_description:
        "Piezas únicas y artesanía de Ana Alvarez Vega, disponibles directamente desde su estudio.",
      og_url: "https://anartista.com/",
      featured_piece: Store.latest_available_piece(),
      pieces_by_category: Store.list_pieces_by_category()
    )
  end

  def about(conn, _params) do
    render(conn, :about,
      page_title: "Acerca de Ana",
      meta_description:
        "La práctica multidisciplinaria de Ana Alvarez Vega: mosaico, pintura, grabado, escultura y dibujo.",
      og_url: "https://anartista.com/about",
      selected_artworks: Artworks.list_selected_artworks()
    )
  end

  def obra(conn, params) do
    category = if is_binary(params["type"]), do: params["type"], else: nil

    artworks_by_category =
      Artworks.list_artworks(category: category)
      |> Enum.group_by(& &1.category)
      |> Enum.sort_by(fn {type, _artworks} -> String.downcase(type) end)

    render(conn, :obra,
      page_title: "Obra",
      meta_description: "Archivo de obra, técnicas y materiales.",
      og_url: "https://anartista.com/obra",
      categories: Artworks.list_categories(),
      current_category: category,
      artworks_by_category: artworks_by_category
    )
  end

  def exhibitions(conn, _params) do
    render(conn, :exhibitions,
      page_title: "Exposiciones",
      meta_description:
        "Archivo de exposiciones, encuentros y contextos de la obra de Ana Alvarez Vega.",
      og_url: "https://anartista.com/exhibitions",
      exhibitions: Exhibitions.list_exhibitions()
    )
  end

  def writing(conn, _params) do
    render(conn, :writing,
      page_title: "Escritos",
      meta_description: "Notas y procesos de la práctica artística de Ana Alvarez Vega.",
      og_url: "https://anartista.com/writing",
      substack_posts: Anartista.Substack.posts(6)
    )
  end

  def contact(conn, _params) do
    render(conn, :contact,
      page_title: "Contacto",
      meta_description:
        "Contacta a Ana Alvarez Vega para conversar sobre obra, colaboración o exposición.",
      og_url: "https://anartista.com/contact"
    )
  end

  def shop(conn, _params), do: redirect(conn, to: ~p"/")
end
