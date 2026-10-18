#!/usr/bin/env bash
# Installs or upgrades a QBCore script, vehicle, EUP or map pack. Your config and locale changes are kept.
# Usage: ./install-script.sh /path/to/script.zip   (or a folder)
exec bash "$(dirname "$0")/install/update.sh" script "$@"
