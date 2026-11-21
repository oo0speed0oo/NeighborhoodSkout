#!/usr/bin/env bash
# One-time install for Ubuntu. Run from inside the skout folder:  bash install.sh
# Needs only python3 (already on your box). No Docker, no pip, no database.
set -e
cd "$(dirname "$0")"
HERE="$(pwd)"
command -v python3 >/dev/null || { echo "python3 is missing. Run: sudo apt install -y python3"; exit 1; }

echo "== 1/3 settings =="
if [ ! -f config.env ]; then
  IP=$(command -v tailscale >/dev/null && tailscale ip -4 2>/dev/null | head -1 || true)
  sed "s#%HOME%#$HOME#" config.env.example > config.env
  if [ -n "$IP" ]; then sed -i "s#^SKOUT_HOST=.*#SKOUT_HOST=$IP#" config.env; echo "Listening on your Tailscale address $IP only."
  else echo "Tailscale address not found; listening on this machine only (127.0.0.1). Edit config.env later."; fi
else echo "config.env already exists, kept."; fi
chmod 600 config.env
chmod +x run.sh

echo "== 2/3 start-on-boot service =="
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/skout.service" <<UNIT
[Unit]
Description=NeighborhoodSkout storage server
After=network-online.target

[Service]
EnvironmentFile=$HERE/config.env
ExecStart=$HERE/run.sh
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now skout
sudo loginctl enable-linger "$USER"   # keeps it running at boot, even when nobody is logged in

echo "== 3/3 done =="
sleep 2
systemctl --user status skout --no-pager | head -5
HOSTV=$(grep -E '^SKOUT_HOST=' config.env | cut -d= -f2); PORT=$(grep -E '^SKOUT_PORT=' config.env | cut -d= -f2)
echo
echo "Open on your phone and PC (Tailscale on):  http://${HOSTV}:${PORT}"
