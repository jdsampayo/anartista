# Anartista

Personal website for https://anartista.com

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

Open `/admin` to access the dashboard for messages, the store, exhibitions, and artwork (**Obra**). Visitors without a valid session are sent to `/admin/login`; successful login returns to the requested admin page, or the dashboard by default. All admin pages require authentication, including LiveView connections and actions. There is no public registration.

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

### Artwork (Obra)

Manage artwork at `/admin/obra`. Each record has a title, image, image description, free-entry **Tipo**, display order, and **Obra seleccionada** checkbox. Selected works appear in `/about`; all works appear in `/obra`, grouped by type with shareable type filters. New types such as Mosaico, Pintura, Linograbado, or Cerámica need no code changes. Display order accepts whole numbers from 0 to 2,147,483,647.

Optional object-label details are date/year (including ranges), technique, materials, dimensions, edition, collection/location, and description. Empty details are omitted from the public label. There is no artist field and the label does not repeat the artist name.

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
