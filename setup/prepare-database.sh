#!/usr/bin/env bash
# Fusion Menu - database for txAdmin's recipe deployer on your own Linux VPS (Ubuntu / Debian):
#   curl -fsSL https://raw.githubusercontent.com/Marine1108/fusion-menu-server-kit/main/setup/prepare-database.sh | sudo bash
# txAdmin's deployer needs a database login it can sign in to with a password. A fresh VPS has none:
# MariaDB isn't installed, or its root account only works through sudo. This installs MariaDB if needed
# and creates the login "txadmin" (local only) with a random password, then shows what to type in txAdmin.
# Running it again gives the login a new password. Game hosts don't need this: their panel has a database.
set -euo pipefail

if [[ "$(id -u)" != "0" ]]; then echo "Run it with sudo:  curl -fsSL <this link> | sudo bash"; exit 1; fi
command -v apt-get >/dev/null 2>&1 || { echo "This needs Ubuntu or Debian (apt). Install MySQL / MariaDB yourself and create a login for txAdmin."; exit 1; }

if ! command -v mariadb >/dev/null 2>&1 && ! command -v mysql >/dev/null 2>&1; then
    echo "Installing MariaDB..."
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server
fi
systemctl enable --now mariadb >/dev/null 2>&1 || systemctl enable --now mysql >/dev/null 2>&1 || true
DB="$(command -v mariadb || command -v mysql)"

PASS="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' | cut -c1-24)"
ROOT_ARGS=(-u root)
if ! "$DB" -u root -e "SELECT 1" >/dev/null 2>&1; then
    # some providers give MariaDB's root a password; ask for it (the keyboard, not the piped script)
    read -r -s -p "MariaDB root password: " RP < /dev/tty; echo
    export MYSQL_PWD="$RP"
fi
"$DB" "${ROOT_ARGS[@]}" -e "CREATE USER IF NOT EXISTS 'txadmin'@'localhost' IDENTIFIED BY '$PASS';
ALTER USER 'txadmin'@'localhost' IDENTIFIED BY '$PASS';
CREATE USER IF NOT EXISTS 'txadmin'@'127.0.0.1' IDENTIFIED BY '$PASS';
ALTER USER 'txadmin'@'127.0.0.1' IDENTIFIED BY '$PASS';
GRANT ALL PRIVILEGES ON *.* TO 'txadmin'@'localhost';
GRANT ALL PRIVILEGES ON *.* TO 'txadmin'@'127.0.0.1';
FLUSH PRIVILEGES;"

HOME_DIR="$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)"
FILE="${HOME_DIR:-/root}/fusion-database-login.txt"
cat > "$FILE" <<EOF
FUSION MENU - DATABASE LOGIN FOR TXADMIN (keep this file private)

Host:     localhost
Port:     3306
Username: txadmin
Password: $PASS

Type these into txAdmin's database step. The database name can be anything (e.g. fusion).
EOF
chmod 600 "$FILE"
chown "${SUDO_USER:-root}" "$FILE" 2>/dev/null || true

printf '\n\033[32m%s\033[0m\n\n' "MariaDB is ready for txAdmin. In txAdmin's database step enter:"
echo "  Host:      localhost"
echo "  Port:      3306"
echo "  Username:  txadmin"
echo "  Password:  $PASS"
echo "  Database:  anything you like, e.g. fusion"
echo
echo "Saved in $FILE"
