#!/usr/bin/env bash
# Fusion Menu - one-command VPS setup (Ubuntu / Debian):
#   curl -fsSL https://raw.githubusercontent.com/Marine1108/fusion-menu-server-kit/main/setup/get-fusion.sh | sudo bash
# Downloads the free server kit and runs the installer (database, server.cfg, FXServer, service, firewall).
set -euo pipefail
KIT_ZIP="https://github.com/Marine1108/fusion-menu-server-kit/archive/refs/heads/main.zip"

if [[ "$(id -u)" != "0" ]]; then echo "Run it with sudo:  curl -fsSL <this link> | sudo bash"; exit 1; fi
need=()
for p in curl unzip; do command -v "$p" >/dev/null 2>&1 || need+=("$p"); done
if (( ${#need[@]} )); then apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y "${need[@]}"; fi

printf '\033[1;35m%s\033[0m\n' "FUSION MENU - SERVER SETUP"
DIR="/home/fivem/fusion"
read -r -p "Install folder [$DIR]: " answer < /dev/tty || true
DIR="${answer:-$DIR}"
mkdir -p "$DIR"

tmp="$(mktemp -d)"
echo "Downloading the Fusion Menu server kit..."
curl -fsSL -o "$tmp/kit.zip" "$KIT_ZIP"
unzip -q "$tmp/kit.zip" -d "$tmp"
src="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | sed -n 1p)"
[[ -f "$DIR/server.cfg" ]] && cp -a "$DIR/server.cfg" "$tmp/keep-server.cfg"
cp -a "$src/." "$DIR/"
[[ -f "$tmp/keep-server.cfg" ]] && cp -a "$tmp/keep-server.cfg" "$DIR/server.cfg"
rm -rf "$tmp"
chmod +x "$DIR"/*.sh "$DIR"/install/*.sh 2>/dev/null || true
echo "Server kit is in $DIR"

# the installer asks questions, so give it the keyboard (stdin is this script when piped)
exec bash "$DIR/install-linux.sh" < /dev/tty
