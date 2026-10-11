# Anartista

Personal website for https://anartista.com

## Public navigation

The seven public pages (`/`, `/about`, `/obra`, `/exhibit`, `/exhibitions`, `/writing`, `/contact`) share `AnartistaWeb.PageLive` in the `:public` LiveView session. Internal links use `<.link patch={...}>`: the URL and content change without replacing the browser document. Exhibit is an independent navigation destination, not an Obra view switch; its immersive route hides the normal site header/footer and restores them when leaving. `/store` still redirects to `/`.

Page changes scroll to the top and close the mobile menu; Obra and Exhibit query-string filters preserve scroll position. Titles and description/social metadata follow the current page, including the server-rendered initial response. Browser back/forward and direct URLs remain supported.

The contact form is a child LiveView. The mosaic uses a mount/destroy hook, and lightboxes use delegated events so both work after navigation. External links and in-page anchors remain ordinary links. Without a connected LiveView, public links fall back to normal page loads; crossing between public and authenticated admin sessions also performs a full load.

### Exhibit

Use the **Exhibit** link in desktop or mobile navigation to enter `/exhibit`. Exhibit displays only rooms and artwork selections saved at `/admin/exhibit`; `/obra` remains the complete artwork archive. Both accept an independent `?type=` filter, but Exhibit offers only types attached to its saved rooms. Artwork images and object-label details stay at `/admin/obra`, with no duplicate artwork dataset or model upload.

Exhibit fills the browser viewport with named CSS 3D rooms, wall-mounted images, museum labels, and pedestal displays. Locally authored plaster and limestone textures, layered architectural trim, warm gallery lights, beveled frames, and pedestal contact shadows add physical detail without a WebGL dependency. Rooms support standard, larger/wider/deeper, and open skylit layouts. The skylit variation has a recessed, mullioned rooflight, diffuse daylight, and more widely spaced pedestals; it has no interior divider blocking the works. Their geometry expands to accommodate selected works rather than silently dropping pieces beyond five. Compact filters, room navigation, camera controls, and **Salir** sit over the scene; there is no normal site header, footer, or page-length artwork list. Categories containing Escultura, Cerámica, Objeto, Instalación, Tridimensional, or 3D (case/accent-insensitive, including supported plurals) use pedestals; other categories use the walls. Materials do not determine placement, so ceramic or stone mosaics remain on the wall. Pedestal images are not generated 3D models.

Drag in either direction to look around, zoom with the mouse wheel/trackpad or a two-finger pinch, use the camera controls, or focus the room and use arrow keys, `+` / `−`, and `Home` to reset. Camera changes use frame-time-based easing; dragging stays responsive without momentum, and the animation stops when the camera settles. Reduced-motion preferences apply camera changes immediately. Touch gestures inside the room control the camera; the separate Fichas list retains native scrolling. Room navigation is bounded at the first and last room. Selecting an artwork opens its complete record in an in-place **Fichas** drawer; the drawer also exposes every record directly, including works in other rooms, and remains accessible without JavaScript. `Escape` closes a full-image lightbox first, otherwise the drawer. The fullscreen icon requests native browser fullscreen when supported; the viewport-filling layout works without that permission, and full-image lightboxes mount inside the active fullscreen element. Reset, room/filter changes, and leaving Exhibit clear active gestures and obsolete animation frames.

#### Development demo archive

Run `mix anartista.seed_exhibit_demo` in `MIX_ENV=dev` to add only enough clearly labeled **DEMO** records to reach 30 total. Existing records and selections are preserved, and reruns at 30 insert nothing. The task refuses other environments before starting the application. It does not run during deployment.

Starting from the three original entries, the result is 27 demo records: 8 ceramics, 5 sculptures, 5 paintings, 5 prints, and 4 mosaics. Ceramic images are four locally authored, transparent synthetic illustrations with protected portfolio assets and matching thumbnails under `priv/static/images/portafolio/exhibit-demo/`; other demo records reuse existing portfolio imagery. Their metadata is explicitly fictional, and they are not selected for Acerca de. Development records intentionally remain in the database for exploration.

## Deploy

```sh
cd ~/apps/anartista
git pull
mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix ecto.migrate
env -u PHX_SERVER MIX_ENV=prod mix anartista.seed_exhibitions
env -u PHX_SERVER MIX_ENV=prod mix anartista.seed_artworks
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release
sudo systemctl restart anartista
```

## Administration

Open `/admin` to access the dashboard for messages, the store, exhibitions, artwork (**Obra**), and **Exhibit** rooms. Visitors without a valid session are sent to `/admin/login`; successful login returns to the requested admin page, or the dashboard by default. All admin pages require authentication, including LiveView connections and actions. There is no public registration.

After fetching dependencies, create the account tables and provision an administrator from the project directory:

```sh
mix ecto.migrate
mix anartista.create_admin ana@example.com
```

The command requires a POSIX terminal and prompts for a concealed password and confirmation. Passwords must be 12–72 UTF-8 bytes; email addresses are trimmed and lowercased. Duplicate accounts are rejected, never overwritten. Every account provisioned this way has admin access.

For production, migrate as shown above, load the service's `DATABASE_URL`, `SECRET_KEY_BASE`, and other runtime environment values, then run:

```sh
env -u PHX_SERVER MIX_ENV=prod mix anartista.create_admin ana@example.com
```

Unsetting `PHX_SERVER` prevents the provisioning process from starting another web server. Bcrypt's native dependency requires a C compiler when building.

The migration creates `users` and `users_tokens`. Passwords are bcrypt hashes; session tokens are stored only as SHA-256 digests. Cookies are browser-session cookies, and server-side tokens expire after seven days. **Cerrar sesión** revokes the token and disconnects its active LiveViews. Serve production over HTTPS: session cookies are Secure, HttpOnly, and SameSite=Lax.

`ADMIN_USER` and `ADMIN_PASS` are no longer used. Provision an account before accessing administration, and remove those variables from the service configuration.

Manage the public exhibition archive at `/admin/exhibitions`: add, edit, delete, upload a photo, and set display order (lower numbers appear first). Changes appear on `/exhibitions` immediately after saving. Optional external links must use HTTPS and can contain up to 2,000 characters.

After migrating, preserve the two original exhibitions with:

```sh
mix anartista.seed_exhibitions
# Production, with the service's runtime environment loaded:
env -u PHX_SERVER MIX_ENV=prod mix anartista.seed_exhibitions
```

Run this **before restarting the service with the new code**, as shown in the deploy steps. It inserts Universos Personales and Mujeres Creadoras with their original content, links, images, and order. Repeated runs skip existing seed keys: no duplicates and no overwriting administrator edits. Explicitly running the command after deleting a seeded exhibition restores that missing original.

### Exhibit rooms (Salas)

Manage the virtual gallery at `/admin/exhibit`. Create, edit, and delete salas; set a name, layout (**Sala estándar**, **Sala amplia**, or **Sala cenital**), display order, and artwork checkboxes from the existing Obra archive. Cenital is an open room lit through a frosted skylight rather than divided by an unused central wall. Lower order numbers appear first; ties use room creation order. Saving publishes the room configuration for subsequent visits or navigation to `/exhibit`.

Selections are independent of **Obra seleccionada** in Acerca de. A work can belong to several rooms, and its Fichas record appears only once. Clearing every checkbox saves an empty room; it remains explorable without a type filter. Filters omit rooms with no matching works. New artwork does not enter Exhibit until attached to a room. Deleting a room removes its memberships, never its artworks; deleting an artwork removes its room memberships.

Migration `20261010120000_create_exhibit_rooms` creates `exhibit_rooms` and the ordered join table `exhibit_room_artworks`. It converts the existing automatically generated arrangement into persisted standard rooms named Sala 1, Sala 2, etc., preserving all current artworks and their initial five-per-room grouping. Run `mix ecto.migrate` before deploying the new code; no separate Exhibit seed command is needed. Room metadata and membership replacements save atomically, with database foreign keys and unique room/artwork pairs.

Migration `20261010130000_replace_divided_rooms_with_skylit` replaces the retired `divided` type with `skylit` and updates the database type constraint. Existing room IDs, order, and artwork memberships are preserved. Rooms named exactly **Sala con muro central** or **Muro central** become **Sala cenital**; custom names (including Sala 3) remain unchanged. Run `mix ecto.migrate` before deploying this layout update. Rollback restores the old type without guessing former names or changing memberships.

### Artwork (Obra)

Manage artwork at `/admin/obra`. Each record has a title, image, image description, free-entry **Tipo**, display order, and **Obra seleccionada** checkbox. Selected works appear in `/about`; all works appear in `/obra`, grouped by type with shareable type filters. Works appear in `/exhibit` only when attached to a sala through `/admin/exhibit`. New types such as Mosaico, Pintura, Linograbado, or Cerámica need no code changes. Display order accepts whole numbers from 0 to 2,147,483,647.

Optional object-label details are date/year (including ranges), technique, materials, dimensions, edition, collection/location, and description. Empty details are omitted from the public label. There is no artist field; Obra records do not repeat the artist name, while Exhibit museum labels identify Ana Alvarez Vega.

For a ceramic today, add an artwork with **Tipo: Cerámica**, upload a JPG/PNG/WebP photo (up to 10 MB), and enter technique, materials, dimensions, and image description. Exhibit automatically places its image on a pedestal. A tightly cropped transparent PNG/WebP gives the cleanest object silhouette; a normal photo retains its background. Genuine all-angle viewing would require an optional scanned/modeled `.glb` asset plus a shared WebGL room renderer; neither model upload nor automatic 3D reconstruction from a single photo is implemented.

After migrating, preserve the three original selected entries with:

```sh
mix anartista.seed_artworks
# Production, with the service's runtime environment loaded:
env -u PHX_SERVER MIX_ENV=prod mix anartista.seed_artworks
```

Run this before restarting the service with the new code. It preserves Mosaico, Pintura, and Grabado with their original images, descriptions, selection, and order. Unknown object-label facts remain empty. Repeated runs do not duplicate entries or overwrite administrator edits, including changes to selection or type. Explicitly rerunning the command restores any deleted original seed.

Uploaded photos are stored in `priv/static/uploads/pieces`, `priv/static/uploads/exhibitions`, and `priv/static/uploads/artworks`. Keep all three directories writable and persistent across deployments. Replacing or deleting an exhibition or artwork removes its uploaded photo, but never images shipped under `priv/static/images`.

## Check errors

```sh
journalctl -u anartista.service -n 50
```

## Resize images

Thumbnails

```sh
❯ magick dibujo.webp -resize 50% dibujo_thumb@2x.webp
❯ magick dibujo.webp -resize 25% dibujo_thumb.webp
```

Specific size:

```sh
❯ magick flor.webp -resize 320x315 flor_thumb.webp
```

## License

[MIT](https://choosealicense.com/licenses/mit/)
