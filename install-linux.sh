#!/usr/bin/env bash
# Fusion Menu - Linux / VPS installer (Ubuntu & Debian)
#   chmod +x install-linux.sh && sudo ./install-linux.sh
# Sets up MariaDB, writes server.cfg, and can install FXServer + a systemd service.

set -euo pipefail
shopt -u patsub_replacement 2>/dev/null || true  # keep "&" literal in replacements (bash 5.2+)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$ROOT/install/server.cfg.template"
CONFIG="$ROOT/server.cfg"

c_title() { printf '\n\033[1;36m== %s ==\033[0m\n' "$1"; }
c_ok() { printf '\033[32m%s\033[0m\n' "$1"; }
c_warn() { printf '\033[33m%s\033[0m\n' "$1"; }
c_err() { printf '\033[31m%s\033[0m\n' "$1"; }

ask() { # ask "Question" "default" -> REPLY
    local q="$1" d="${2:-}"
    if [[ -n "$d" ]]; then read -r -p "$q [$d]: " REPLY; else read -r -p "$q: " REPLY; fi
    REPLY="${REPLY:-$d}"
}
ask_yn() { # ask_yn "Question" y|n
    local q="$1" d="${2:-n}" hint="y/N"
    [[ "$d" == "y" ]] && hint="Y/n"
    read -r -p "$q ($hint): " REPLY
    REPLY="${REPLY:-$d}"
    [[ "${REPLY,,}" == y* ]]
}
ask_secret() { read -r -s -p "$1: " REPLY; echo; }

if [[ $EUID -ne 0 ]]; then
    c_err "Please run as root:  sudo ./install-linux.sh"
    exit 1
fi
if [[ ! -f "$TEMPLATE" ]]; then
    c_err "Missing $TEMPLATE - is the download complete?"
    exit 1
fi
RUN_USER="${SUDO_USER:-root}"

printf '\033[1;35m%s\033[0m\n' "Fusion Menu installer"
echo "Press Enter to accept the [default]."

apt_install() {
    if command -v apt-get >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
    else
        c_err "Please install these packages yourself: $*"
        exit 1
    fi
}

# ------------------------------------------------------------------ Packages
c_title "Packages"
need=()
for p in curl tar xz openssl unzip; do command -v "$p" >/dev/null 2>&1 || need+=("$p"); done
if (( ${#need[@]} )); then
    echo "Installing: ${need[*]}"
    command -v apt-get >/dev/null 2>&1 && apt-get update -y
    pkgs=()
    for p in "${need[@]}"; do [[ "$p" == "xz" ]] && pkgs+=("xz-utils") || pkgs+=("$p"); done
    apt_install "${pkgs[@]}"
fi
c_ok "Base packages OK"

# ------------------------------------------------------------------ Fusion files
# Fusion Menu itself comes from portal.cfx.re (Granted Assets). Upload that zip anywhere in your home
# folder, /tmp or this folder (WinSCP / FileZilla) and it is found and unpacked automatically.
find_fusion_zip() {
    local z
    while IFS= read -r z; do
        [[ -f "$z" ]] || continue
        if unzip -Z1 "$z" 2>/dev/null | grep -E '(^|/)fusion-core/fxmanifest\.lua$' >/dev/null; then printf '%s\n' "$z"; return 0; fi
    done < <(ls -t "$ROOT"/*.zip /root/*.zip /root/Downloads/*.zip /home/*/*.zip /home/*/Downloads/*.zip /tmp/*.zip 2>/dev/null)
    return 1
}
add_fusion() {
    local z="$1" entry prefix tmp
    entry="$(unzip -Z1 "$z" | grep -E '(^|/)fusion-core/fxmanifest\.lua$' | sed -n 1p)"
    prefix="${entry%fusion-core/fxmanifest.lua}"
    tmp="$(mktemp -d)"
    unzip -q "$z" -d "$tmp"
    mkdir -p "$ROOT/resources/[fusion]"
    cp -a "$tmp/$prefix". "$ROOT/resources/[fusion]/"
    rm -rf "$tmp"
    c_ok "Fusion Menu unpacked into resources/[fusion]"
}
if ! find "$ROOT/resources" -type d -name fusion-core 2>/dev/null | grep . >/dev/null; then
    c_title "Fusion Menu files"
    while true; do
        if zip="$(find_fusion_zip)"; then echo "Found $zip"; add_fusion "$zip"; break; fi
        c_warn "Fusion Menu itself comes from the Cfx.re portal (it is protected, so it cannot be downloaded for you):"
        echo "  1. Sign in at https://portal.cfx.re > Granted Assets > Fusion Menu > Download"
        echo "  2. Upload the zip to this server (WinSCP or FileZilla), e.g. into $ROOT"
        ask "Press Enter when it is uploaded (or type its path, or 'skip')" ""
        if [[ "$REPLY" == "skip" ]]; then c_warn "Skipped - put Fusion Menu into resources/[fusion] before starting."; break; fi
        if [[ -n "$REPLY" && -f "$REPLY" ]]; then
            if unzip -Z1 "$REPLY" 2>/dev/null | grep -E '(^|/)fusion-core/fxmanifest\.lua$' >/dev/null; then add_fusion "$REPLY"; break; fi
            c_err "That zip does not contain Fusion Menu."
        elif [[ -n "$REPLY" && -d "$REPLY" ]]; then
            # an already unzipped download: copy the folder that holds fusion-core
            core="$(find "$REPLY" -maxdepth 3 -type d -name fusion-core 2>/dev/null | sed -n 1p)"
            if [[ -n "$core" ]]; then
                mkdir -p "$ROOT/resources/[fusion]"
                cp -a "$(dirname "$core")/." "$ROOT/resources/[fusion]/"
                c_ok "Fusion Menu copied into resources/[fusion]"
                break
            fi
            c_err "That folder does not contain Fusion Menu."
        fi
    done
fi

# ------------------------------------------------------------------ Database
c_title "Database (MariaDB / MySQL)"
DB_HOST="localhost"; DB_PORT="3306"; DB_NAME="fusion"; DB_USER="fusion"; DB_PASS=""

if ask_yn "Set up a local MariaDB database on this machine (recommended)?" y; then
    if ! command -v mysql >/dev/null 2>&1 && ! command -v mariadb >/dev/null 2>&1; then
        echo "Installing MariaDB..."
        apt-get update -y
        apt_install mariadb-server
    fi
    systemctl enable --now mariadb >/dev/null 2>&1 || systemctl enable --now mysql >/dev/null 2>&1 || true
    MYSQL_BIN="$(command -v mariadb || command -v mysql)"
    ask "Database name" "fusion"; DB_NAME="$REPLY"
    ask "Database user to create" "fusion"; DB_USER="$REPLY"
    DB_PASS="$(openssl rand -hex 16)"
    SQL="CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;"
    if ! "$MYSQL_BIN" -u root -e "$SQL" 2>/dev/null; then
        c_warn "Root login without a password failed."
        ask_secret "MySQL root password"
        MYSQL_PWD="$REPLY" "$MYSQL_BIN" -u root -e "$SQL"
    fi
    c_ok "Database '$DB_NAME' and user '$DB_USER' are ready (password generated automatically)."
else
    ask "Database host" "localhost"; DB_HOST="$REPLY"
    ask "Database port" "3306"; DB_PORT="$REPLY"
    ask "Database name" "fusion"; DB_NAME="$REPLY"
    ask "Database user" "root"; DB_USER="$REPLY"
    ask_secret "Database password"; DB_PASS="$REPLY"
    if command -v mysql >/dev/null 2>&1; then
        if MYSQL_PWD="$DB_PASS" mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4;"; then
            c_ok "Connected and database '$DB_NAME' is ready."
        else
            c_warn "Could not connect - make sure the database exists before starting the server."
        fi
    fi
fi

urlencode() { local LC_ALL=C s="$1" out="" c; for (( i=0; i<${#s}; i++ )); do c="${s:i:1}"; case "$c" in [a-zA-Z0-9.~_-]) out+="$c";; *) printf -v c '%%%02X' "'$c"; out+="$c";; esac; done; echo "$out"; }
USER_PART="$(urlencode "$DB_USER")"
[[ -n "$DB_PASS" ]] && USER_PART="$USER_PART:$(urlencode "$DB_PASS")"
CONNECTION="mysql://$USER_PART@$DB_HOST:$DB_PORT/$DB_NAME?charset=utf8mb4"

# keep the login where the owner can find it (tools like HeidiSQL, or txAdmin's database step)
if [[ -n "$DB_PASS" ]]; then
    cat > "$ROOT/database-login.txt" <<EOF
FUSION MENU - DATABASE LOGIN (keep this file private)

Host:     $DB_HOST
Port:     $DB_PORT
Database: $DB_NAME
Username: $DB_USER
Password: $DB_PASS

The server already uses this login (mysql_connection_string in server.cfg).
EOF
    chmod 600 "$ROOT/database-login.txt"
    chown "$RUN_USER" "$ROOT/database-login.txt" 2>/dev/null || true
    c_ok "Database login saved in $ROOT/database-login.txt"
fi

# ------------------------------------------------------------------ Server
c_title "Server"
echo "Get a free license key at https://portal.cfx.re (Server Registration Keys)."
while true; do
    ask "License key (cfxk_...)" ""; LICENSE="$REPLY"
    [[ "$LICENSE" == cfxk_* ]] && break
    ask_yn "That does not look like a license key. Use it anyway?" n && break
done
ask "Server name" "Fusion Menu Server"; SERVER_NAME="${REPLY//\"/\'}"
ask "Max players" "48"; MAX_PLAYERS="$REPLY"
ask "Port" "30120"; PORT="$REPLY"

c_title "Owner"
echo "Your identifier makes you Owner right away, e.g. fivem:1234567 or license:abc123..."
echo "Leave empty to claim ownership in game instead (the console shows a /claimowner code)."
ask "Owner identifier" ""; OWNER="$REPLY"
PRINCIPALS=""
if [[ -n "$OWNER" ]]; then
    if [[ "$OWNER" =~ ^[a-z0-9]+: ]]; then PRINCIPALS="add_principal identifier.$OWNER group.admin"
    else c_warn "Not a valid identifier - use /claimowner in game instead."; fi
fi

# ------------------------------------------------------------------ server.cfg
[[ -f "$CONFIG" ]] && cp "$CONFIG" "$CONFIG.bak-$(date +%Y%m%d-%H%M%S)" && c_warn "Existing server.cfg backed up."
ENDPOINTS="endpoint_add_tcp \"0.0.0.0:$PORT\"
endpoint_add_udp \"0.0.0.0:$PORT\""
TEMPLATE_TEXT="$(cat "$TEMPLATE")"
TEMPLATE_TEXT="${TEMPLATE_TEXT//\{\{serverEndpoints\}\}/$ENDPOINTS}"
TEMPLATE_TEXT="${TEMPLATE_TEXT//\{\{maxClients\}\}/$MAX_PLAYERS}"
TEMPLATE_TEXT="${TEMPLATE_TEXT//\{\{svLicense\}\}/$LICENSE}"
TEMPLATE_TEXT="${TEMPLATE_TEXT//\{\{serverName\}\}/$SERVER_NAME}"
TEMPLATE_TEXT="${TEMPLATE_TEXT//\{\{dbConnectionString\}\}/$CONNECTION}"
TEMPLATE_TEXT="${TEMPLATE_TEXT//\{\{addPrincipalsMaster\}\}/$PRINCIPALS}"
printf '%s\n' "$TEMPLATE_TEXT" > "$CONFIG"
chmod 600 "$CONFIG"
c_ok "Wrote $CONFIG"

# ------------------------------------------------------------------ FXServer
c_title "FiveM server software (FXServer)"
FX_DIR=""
if ask_yn "Download FXServer and run Fusion as a system service?" y; then
    ask "Install FXServer to" "/opt/fxserver"; FX_DIR="$REPLY"
    mkdir -p "$FX_DIR"
    echo "Finding the recommended FXServer build..."
    URL="$(curl -fsSL https://changelogs-live.fivem.net/api/changelog/versions/linux/server | grep -o '"recommended_download":"[^"]*"' | cut -d'"' -f4)"
    if [[ -z "$URL" ]]; then
        c_err "Could not find the download link. Download it yourself from https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/"
        FX_DIR=""
    else
        echo "Downloading $URL"
        curl -fL "$URL" -o "$FX_DIR/fx.tar.xz"
        tar -xf "$FX_DIR/fx.tar.xz" -C "$FX_DIR"
        rm -f "$FX_DIR/fx.tar.xz"
        c_ok "FXServer installed in $FX_DIR"
    fi
fi

if [[ -n "$FX_DIR" ]]; then
    echo
    echo "How do you want to run the server?"
    echo "  1) With txAdmin web panel (recommended) - manage it from your browser on port 40120"
    echo "  2) Directly, without txAdmin"
    ask "Choose 1 or 2" "1"; MODE="$REPLY"
    if [[ "$MODE" == "2" ]]; then
        EXEC="$FX_DIR/run.sh +set onesync on +exec $CONFIG"
    else
        mkdir -p "$FX_DIR/txData"
        # txAdmin expects server folders inside its data folder: give it a path there to this one
        TX_SERVER="$FX_DIR/txData/fusion"
        [[ -e "$TX_SERVER" && ! -L "$TX_SERVER" ]] || ln -sfn "$ROOT" "$TX_SERVER"
        EXEC="$FX_DIR/run.sh +set txDataPath $FX_DIR/txData"
    fi
    chown -R "$RUN_USER":"$RUN_USER" "$FX_DIR" "$ROOT"
    cat > /etc/systemd/system/fusion.service <<EOF
[Unit]
Description=Fusion Menu FiveM server
After=network.target mariadb.service mysql.service

[Service]
Type=simple
User=$RUN_USER
WorkingDirectory=$ROOT
ExecStart=$EXEC
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    # Files copied in as root (sudo unzip, WinSCP logged in as root) would stop Fusion saving into them:
    # every minute, hand anything in the server folder that isn't the server user's back to it.
    cat > /etc/systemd/system/fusion-owner.service <<EOF
[Unit]
Description=Fusion Menu - give server files back to $RUN_USER

[Service]
Type=oneshot
ExecStart=/usr/bin/find "$ROOT" -xdev ! -user $RUN_USER -exec chown -h $RUN_USER:$RUN_USER {} +
EOF
    cat > /etc/systemd/system/fusion-owner.timer <<EOF
[Unit]
Description=Fusion Menu - check server file ownership every minute

[Timer]
OnBootSec=20
OnUnitActiveSec=60
AccuracySec=5

[Install]
WantedBy=timers.target
EOF
    systemctl daemon-reload
    systemctl enable fusion.service >/dev/null
    systemctl enable --now fusion-owner.timer >/dev/null
    c_ok "Created the 'fusion' service."

    if command -v ufw >/dev/null 2>&1 && ufw status | grep "Status: active" >/dev/null; then
        if ask_yn "Open the firewall ports (ufw) for the server?" y; then
            ufw allow "$PORT"/tcp >/dev/null; ufw allow "$PORT"/udp >/dev/null
            [[ "$MODE" != "2" ]] && ufw allow 40120/tcp >/dev/null
            c_ok "Firewall ports opened."
        fi
    fi

    if ask_yn "Start the server now?" y; then systemctl start fusion.service; fi

    c_title "Done"
    if [[ "$MODE" == "2" ]]; then
        echo "The server is running. Logs:  journalctl -u fusion -f"
    else
        echo "Open http://YOUR_SERVER_IP:40120 in your browser. The PIN is in the log:"
        echo "    journalctl -u fusion -f"
        echo "In the txAdmin setup choose 'Existing server data' and use:"
        echo "    Server Data Folder: ${TX_SERVER:-$ROOT}"
        echo "    CFG File:          ${TX_SERVER:-$ROOT}/server.cfg"
        echo "(${TX_SERVER:-$ROOT} is the same folder as $ROOT.)"
        echo "Then turn OneSync on (Settings > FXServer) and start the server."
    fi
    echo "Control it with:  systemctl start|stop|restart fusion"
else
    c_title "Done"
    echo "server.cfg is ready. Start FXServer with this folder as the server data folder:"
    echo "    cd $ROOT && /path/to/fxserver/run.sh +set onesync on +exec server.cfg"
fi
[[ -z "$PRINCIPALS" ]] && c_warn "Watch the server console for your /claimowner code."
echo "Full guide: $ROOT/README.md"
