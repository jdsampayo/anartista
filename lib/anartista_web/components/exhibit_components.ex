defmodule AnartistaWeb.ExhibitComponents do
  use Phoenix.Component

  import AnartistaWeb.ArtComponents, only: [artwork_card: 1]
  import AnartistaWeb.CoreComponents, only: [icon: 1]

  attr(:rooms, :list, required: true)

  def exhibit_gallery(assigns) do
    artworks = assigns.rooms |> Enum.flat_map(& &1.artworks) |> Enum.uniq_by(& &1.id)

    assigns =
      assigns
      |> assign(:artworks, artworks)
      |> assign(:rooms, Enum.map(assigns.rooms, &room_layout/1))

    ~H"""
    <div :if={@rooms != []} id="exhibit-gallery" class="exhibit-gallery" phx-hook="Exhibit">
      <div class="exhibit-toolbar">
        <p id="exhibit-room-status" role="status" aria-live="polite">{hd(@rooms).name} · Sala 1 de {length(@rooms)}</p>
        <div class="exhibit-controls" aria-label="Navegar por las salas">
          <button type="button" data-room-step="-1" disabled={true}>Sala anterior</button>
          <button type="button" data-room-step="1" disabled={length(@rooms) < 2}>Siguiente sala</button>
        </div>
      </div>
      <div class="exhibit-viewport" tabindex="0" role="region" aria-label={"Sala de exposición: #{hd(@rooms).name}"} aria-describedby="exhibit-instructions">
        <div class="exhibit-camera">
          <div
            :for={{room, index} <- Enum.with_index(@rooms)}
            class={["exhibit-room", "exhibit-room-#{room.type}"]}
            data-room={index}
            data-room-name={room.name}
            data-room-width={room.width}
            data-room-depth={room.depth}
            data-room-height={room.height}
            data-room-type={room.type}
            style={"--room-width: #{room.width}px; --room-depth: #{room.depth}px; --room-height: #{room.height}px"}
            role="group"
            aria-label={room.name}
            hidden={index != 0}
          >
            <div class="exhibit-wall exhibit-wall-back">
              <.wall_details width={room.width} count={room.back_count} />
              <p class="exhibit-wall-title">{room.name} <span>Ana Alvarez Vega</span></p>
              <.wall_work :for={{artwork, slot} <- Enum.with_index(room.back_works)} artwork={artwork} left={wall_position(room.width, room.back_count, slot)} />
            </div>
            <div class="exhibit-wall exhibit-wall-left">
              <.wall_details width={room.depth} count={room.left_count} />
              <.wall_work :for={{artwork, slot} <- Enum.with_index(room.left_works)} artwork={artwork} left={wall_position(room.depth, room.left_count, slot)} />
            </div>
            <div class="exhibit-wall exhibit-wall-right">
              <.wall_details width={room.depth} count={room.right_count} />
              <.wall_work :for={{artwork, slot} <- Enum.with_index(room.right_works)} artwork={artwork} left={wall_position(room.depth, room.right_count, slot)} />
            </div>
            <div class="exhibit-floor" aria-hidden="true"></div>
            <div class="exhibit-ceiling" aria-hidden="true">
              <div :if={room.type == "skylit"} class="exhibit-skylight">
                <div class="exhibit-skylight-glass"></div>
              </div>
            </div>
            <div :for={{artwork, slot} <- Enum.with_index(room.objects)} class="exhibit-object" style={object_position(room, slot)}>
              <div class="exhibit-object-shadow" aria-hidden="true"></div>
              <a href={"#exhibit-record-#{artwork.id}"} class="exhibit-object-image" aria-label={"Ver ficha: #{artwork.title}"}>
                <img src={artwork.photo} alt={artwork.image_alt} loading="lazy" draggable="false" />
              </a>
              <div class="exhibit-pedestal" aria-hidden="true">
                <div class="exhibit-pedestal-front"></div>
                <div class="exhibit-pedestal-side"></div>
                <div class="exhibit-pedestal-left"></div>
                <div class="exhibit-pedestal-back"></div>
                <div class="exhibit-pedestal-top"></div>
              </div>
              <a href={"#exhibit-record-#{artwork.id}"} class="exhibit-object-label"><.museum_label artwork={artwork} /></a>
            </div>
          </div>
        </div>
      </div>
      <div class="exhibit-toolbar exhibit-toolbar-bottom">
        <p id="exhibit-instructions">Arrastra para mirar. Acércate con la rueda, dos dedos o + / −. Usa las flechas para girar. Selecciona una obra para leer su ficha.</p>
        <div class="exhibit-controls" aria-label="Controlar la vista">
          <button type="button" data-camera="left" aria-label="Mirar a la izquierda"><.icon name="hero-arrow-left" class="h-4 w-4" /></button>
          <button type="button" data-camera="right" aria-label="Mirar a la derecha"><.icon name="hero-arrow-right" class="h-4 w-4" /></button>
          <button type="button" data-camera="out" aria-label="Alejar"><.icon name="hero-minus" class="h-4 w-4" /></button>
          <button type="button" data-camera="in" aria-label="Acercar"><.icon name="hero-plus" class="h-4 w-4" /></button>
          <button type="button" data-camera="reset">Restablecer</button>
          <button type="button" data-fullscreen hidden aria-label="Activar pantalla completa"><.icon name="hero-arrows-pointing-out" class="h-4 w-4" /></button>
        </div>
      </div>
      <details id="exhibit-records-panel" class="exhibit-records-panel">
        <summary class="exhibit-records-toggle"><span class="exhibit-records-open-label">Fichas ({length(@artworks)})</span><span class="exhibit-records-close-label">Cerrar fichas</span></summary>
        <section class="exhibit-records" aria-labelledby="exhibit-records-heading">
          <h2 id="exhibit-records-heading" class="font-serif text-3xl">Fichas de sala</h2>
          <p class="mt-3 text-sm text-muted">Consulta todas las obras, también las de otras salas.</p>
          <p :if={Enum.any?(@rooms, &(&1.objects != []))} class="mt-3 text-sm text-muted">Las piezas sobre pedestal se muestran como imágenes, no como modelos 3D.</p>
          <div class="exhibit-records-list">
            <details :for={artwork <- @artworks} id={"exhibit-record-#{artwork.id}"} class="exhibit-record">
              <summary><span>{artwork.title}</span><span class="text-sm font-sans">{artwork.category}{if artwork.year, do: " · #{artwork.year}"}</span></summary>
              <div class="bg-dark px-5 pb-6 pt-2"><.artwork_card artwork={artwork} /></div>
            </details>
          </div>
        </section>
      </details>
    </div>
    """
  end

  defp room_layout(room) do
    {objects, wall_works} = Enum.split_with(room.artworks, &pedestal?/1)
    wall_count = length(wall_works)
    back_count = min(wall_count, max(3, ceil(wall_count / 3)))
    {back_works, side_works} = Enum.split(wall_works, back_count)
    left_count = ceil((wall_count - back_count) / 2)
    {left_works, right_works} = Enum.split(side_works, left_count)
    object_count = length(objects)

    {base_width, base_depth} =
      case room.type do
        "large" -> {1600, 1300}
        "skylit" -> {1440, 1100}
        _ -> {1200, 900}
      end

    %{
      name: room.name,
      type: room.type,
      objects: objects,
      back_works: back_works,
      left_works: left_works,
      right_works: right_works,
      back_count: back_count,
      left_count: left_count,
      right_count: wall_count - back_count - left_count,
      object_count: object_count,
      width: base_width + max(0, max(back_count * 330 + 160, object_count * 240 + 160) - 1200),
      depth: base_depth + max(0, left_count * 330 + 160 - 900),
      height: 650
    }
  end

  defp wall_position(wall_width, count, slot) do
    wall_width * (slot + 1) / (count + 1) - 125
  end

  defp object_position(room, slot) do
    left =
      if room.type == "skylit" do
        room.width * (slot + 1) / (room.object_count + 1) - 90
      else
        (room.width - room.object_count * 240) / 2 + slot * 240 + 30
      end

    "left: #{left}px; --object-depth: 60px"
  end

  # Categories are the only type input. Materials cannot identify objects: mosaics also use ceramic and stone.
  defp pedestal?(artwork) do
    category =
      artwork.category
      |> String.downcase()
      |> String.normalize(:nfd)
      |> String.replace(~r/\p{Mn}/u, "")

    Regex.match?(
      ~r/\b(esculturas?|ceramicas?|objetos?|instalacion(?:es)?|tridimensional|3d)\b/u,
      category
    )
  end

  attr(:width, :integer, required: true)
  attr(:count, :integer, required: true)

  defp wall_details(assigns) do
    ~H"""
    <div class="exhibit-wall-details" aria-hidden="true">
      <div class="exhibit-light-rail"></div>
      <div
        :for={slot <- 0..(max(@count, 2) - 1)}
        class="exhibit-wall-light"
        style={"left: #{wall_position(@width, max(@count, 2), slot) + 125}px"}
      >
        <div class="exhibit-light-pool"></div>
        <div class="exhibit-light-fixture"></div>
      </div>
    </div>
    """
  end

  attr(:artwork, :map, required: true)
  attr(:left, :float, required: true)

  defp wall_work(assigns) do
    ~H"""
    <a href={"#exhibit-record-#{@artwork.id}"} class="exhibit-wall-work" style={"left: #{@left}px"} aria-label={"Ver ficha: #{@artwork.title}"}>
      <div class="exhibit-frame"><img src={@artwork.photo} alt={@artwork.image_alt} loading="lazy" draggable="false" /></div>
      <div class="exhibit-wall-label"><.museum_label artwork={@artwork} /></div>
    </a>
    """
  end

  attr(:artwork, :map, required: true)

  defp museum_label(assigns) do
    ~H"""
    <span class="exhibit-label-title">{@artwork.title}<span :if={@artwork.year}>, {@artwork.year}</span></span>
    <span>Ana Alvarez Vega</span>
    <span>{@artwork.technique || @artwork.category}</span>
    <span :if={@artwork.materials}>{@artwork.materials}</span>
    <span :if={@artwork.dimensions}>{@artwork.dimensions}</span>
    """
  end
end
