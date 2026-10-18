#!/usr/bin/env bash
# Updates Fusion Menu without losing your settings, pictures or edits.
# Upload the zip from your Cfx.re keymaster to the "updates" folder, stop the server, then run: ./update-fusion.sh
exec bash "$(dirname "$0")/install/update.sh" fusion "$@"
