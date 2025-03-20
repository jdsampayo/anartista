# Anartista

Personal website for https://anartista.com

## Deploy

```sh
cd ~/apps/anartista
git pull
mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release
sudo systemctl restart anartista
```

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
