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

## License

[MIT](https://choosealicense.com/licenses/mit/)
