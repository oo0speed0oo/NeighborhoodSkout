# NeighborhoodSkout on your home box

One small Python program keeps the single shared copy of your map (and photos). Every device that opens
its address sees the same map, and every change saves to it automatically.
It uses only python3 (already on your box): no Docker, no pip, no database.

## Install (once)
    tar xzf skout.tar.gz
    cd skout
    bash install.sh

It listens on your Tailscale address only, on port 8095 (reel2txt uses 8090), and starts again after a reboot.
Open the address it prints, on your phone and PC (Tailscale on):  http://100.x.x.x:8095

## Settings (`config.env`, then `systemctl --user restart skout`)
- `SKOUT_PORT`     port (default 8095)
- `SKOUT_HOST`     address to listen on (install.sh sets your Tailscale address)
- `SKOUT_DATA`     data folder (default ~/skout-data). Back up this one folder.
- `SKOUT_PASSWORD` optional password; leave empty for none. Any username works.

## What is stored in `~/skout-data`
- `state.json`  your map and people
- `photos/`     house and resident photos
- `snapshots/`  automatic copies of older versions (about every 5 minutes while you edit, and always
                before a big shrink). To go back, copy one over `state.json` and reload the page.

## Update the app later
Put the new `index.html` in this folder and run `bash update.sh`. Your data is not touched.

## Handy commands
    systemctl --user status skout --no-pager
    journalctl --user -u skout -n 30 --no-pager

## Notes
- Do not expose this to the public internet (no port forwarding, no Tailscale Funnel).
- The first device you open sends its map to the server. A second device that already has its own
  map will ask which one to keep, and backs up the other one first.
- If the box is off, the app still works on each device and syncs when the box is back.
