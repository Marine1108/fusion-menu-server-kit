#!/usr/bin/env bash
# Updates the FiveM server program (FXServer), and with it txAdmin, which is built into it. Linux.
#
#   sudo bash update-fxserver.sh              the "recommended" build (the safe choice)
#   sudo bash update-fxserver.sh latest       the newest build (the newest txAdmin patch, e.g. 8.1.2)
#   sudo bash update-fxserver.sh rollback     back to the build you had before the last update
#
# Your server, Fusion Menu, its database, server.cfg and txAdmin's settings (txData) are never touched:
# only FXServer's own program files (the "alpine" folder and run.sh) are replaced. The old ones are kept
# next to them as alpine.previous until the next update, so "rollback" can put them back.
# Run it as root (sudo): it stops and starts the "fusion" service.

set -euo pipefail
CHOICE="${1:-recommended}"
c_red=$'\e[31m'; c_grn=$'\e[32m'; c_yel=$'\e[33m'; c_cyn=$'\e[36m'; c_off=$'\e[0m'
fail() { echo "${c_red}$1${c_off}"; exit 1; }

# where FXServer is: from the "fusion" service (ExecStart=.../run.sh), else /opt/fxserver
FX_DIR=""
if command -v systemctl >/dev/null && systemctl cat fusion >/dev/null 2>&1; then
    FX_DIR="$(systemctl cat fusion | sed -nE 's/^ExecStart=([^ ]*)\/run\.sh.*/\1/p' | head -n1)"
fi
[[ -n $FX_DIR ]] || FX_DIR="/opt/fxserver"
[[ -f $FX_DIR/run.sh ]] || fail "FXServer was not found in $FX_DIR (no run.sh). Tell this script where it is: FX_DIR=/path/to/fxserver bash update-fxserver.sh"
[[ $EUID -eq 0 ]] || fail "Run it with sudo: sudo bash update-fxserver.sh $CHOICE"

# the build this script installed last (unknown before its first run)
current() { cat "$FX_DIR/alpine/.fusion-build" 2>/dev/null || true; }

stop_server() {
    if command -v systemctl >/dev/null && systemctl is-active --quiet fusion 2>/dev/null; then
        echo "Stopping the server..."
        systemctl stop fusion
    fi
    if pgrep -f "$FX_DIR/alpine" >/dev/null 2>&1; then fail "FXServer is still running. Stop it (txAdmin > Stop server, or sudo systemctl stop fusion) and run this again."; fi
}
start_server() {
    if command -v systemctl >/dev/null && systemctl cat fusion >/dev/null 2>&1; then
        echo "Starting the server..."
        systemctl start fusion
    else
        echo "${c_yel}Start your server again the way you normally do.${c_off}"
    fi
}

if [[ $CHOICE == rollback ]]; then
    [[ -d $FX_DIR/alpine.previous ]] || fail "There is no earlier build to go back to ($FX_DIR/alpine.previous is missing)."
    stop_server
    rm -rf "$FX_DIR/alpine.failed"
    mv "$FX_DIR/alpine" "$FX_DIR/alpine.failed"
    mv "$FX_DIR/alpine.previous" "$FX_DIR/alpine"
    [[ -f $FX_DIR/run.sh.previous ]] && mv -f "$FX_DIR/run.sh.previous" "$FX_DIR/run.sh"
    rm -rf "$FX_DIR/alpine.failed"
    echo "${c_grn}Back on build $(current).${c_off}"
    start_server
    exit 0
fi
[[ $CHOICE == recommended || $CHOICE == latest ]] || fail "Use: bash update-fxserver.sh [recommended|latest|rollback]"

for tool in curl tar xz; do command -v "$tool" >/dev/null || fail "Missing tool: $tool (sudo apt install -y curl tar xz-utils)"; done

echo "Asking FiveM for the $CHOICE build..."
INFO="$(curl -fsSL https://changelogs-live.fivem.net/api/changelog/versions/linux/server)" || fail "Could not reach FiveM's download server. Try again in a minute."
BUILD="$(echo "$INFO" | grep -o "\"$CHOICE\":\"[0-9]*\"" | cut -d'"' -f4)"
URL="$(echo "$INFO" | grep -o "\"${CHOICE}_download\":\"[^\"]*\"" | cut -d'"' -f4)"
TXA="$(echo "$INFO" | grep -o "\"${CHOICE}_txadmin\":\"[^\"]*\"" | cut -d'"' -f4)"
[[ -n $BUILD && -n $URL ]] || fail "FiveM did not say which build that is. Try again in a minute."
NOW="$(current)"
echo "${c_cyn}Installed: build ${NOW:-unknown}.  ${CHOICE^}: build $BUILD with txAdmin ${TXA:-?}.${c_off}"
if [[ $NOW == "$BUILD" ]]; then echo "${c_grn}You already have build $BUILD. Nothing to do.${c_off}"; exit 0; fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Downloading build $BUILD..."
curl -fL --progress-bar "$URL" -o "$TMP/fx.tar.xz" || fail "The download failed. Nothing was changed."
mkdir -p "$TMP/new"
tar -xf "$TMP/fx.tar.xz" -C "$TMP/new" || fail "The download is damaged. Nothing was changed."
[[ -d $TMP/new/alpine && -f $TMP/new/run.sh ]] || fail "The download does not look like FXServer. Nothing was changed."

stop_server
# keep the current build for "rollback", then swap in the new one (txData and everything else stay where they are)
rm -rf "$FX_DIR/alpine.previous"
mv "$FX_DIR/alpine" "$FX_DIR/alpine.previous"
cp -f "$FX_DIR/run.sh" "$FX_DIR/run.sh.previous"
mv "$TMP/new/alpine" "$FX_DIR/alpine"
echo "$BUILD" > "$FX_DIR/alpine/.fusion-build"
cp -f "$TMP/new/run.sh" "$FX_DIR/run.sh"
chmod +x "$FX_DIR/run.sh"
# the same owner as the rest of the folder (the user the server runs as)
OWNER="$(stat -c '%U:%G' "$FX_DIR")"
chown -R "$OWNER" "$FX_DIR/alpine" "$FX_DIR/run.sh" 2>/dev/null || true

echo "${c_grn}FXServer updated to build $BUILD (txAdmin ${TXA:-?}). The previous build is kept: sudo bash update-fxserver.sh rollback${c_off}"
start_server
