#!/usr/bin/env bash
# Fusion Menu updater / script installer (Linux). Used by update-fusion.sh and install-script.sh.
#
#   update.sh fusion [zip|folder]      Update the framework in resources/[fusion]
#   update.sh script <zip|folder>      Install or upgrade QBCore scripts, vehicles, EUP, maps
#   Options: --yes  --force (allow downgrades / scripts Fusion replaces)  --ignore-running
#            --target qb|addons|"[addons]/[cars]"  (where new installs go; default: worked out from the files)
#
# Nothing you changed is lost. Every install writes .fusion-install.sha256 into the resource folder
# (a fingerprint of each file it installed). On the next update:
#   - files still matching their fingerprint are replaced with the new version
#   - files you edited (configs, pictures, media...) are kept; the new version is saved next to them as <file>.new
#   - files the new version no longer has are removed, unless you edited them
#   - files you added yourself are never touched
# The whole resource folder is backed up to backups/<date>/ first (and the database, for Fusion updates).
# Same behaviour and file format as install/update.ps1 on Windows.

set -euo pipefail

MODE="${1:-}"; shift || true
SOURCE="" TARGET="auto" FORCE=0 YES=0 IGNORE_RUNNING=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y) YES=1 ;;
        --force) FORCE=1 ;;
        --ignore-running) IGNORE_RUNNING=1 ;;
        --target) TARGET="$2"; shift ;;
        *) SOURCE="$1" ;;
    esac
    shift
done
[[ $MODE == fusion || $MODE == script ]] || { echo "Usage: $0 fusion|script [zip|folder] [--yes] [--force] [--target qb|addons]"; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOURCES="$ROOT/resources"
FUSION_DIR="$RESOURCES/[fusion]"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$ROOT/backups/$STAMP"
RECORD=".fusion-install.sha256"
REPORT=()
TEMP=""
ATTENTION=0

REPLACED=" qb-core qb-inventory qb-target qb-menu qb-input progressbar qb-multicharacter qb-spawn qb-garages qb-shops qb-clothing illenium-appearance qb-vehiclekeys qb-weathersync qb-ambulancejob qb-prison qb-management qb-banking LegacyFuel qb-hud "

c_red=$'\e[31m'; c_grn=$'\e[32m'; c_yel=$'\e[33m'; c_cyn=$'\e[36m'; c_off=$'\e[0m'
say()  { echo "${2:-}$1${c_off}"; REPORT+=("$1"); }
fail() { echo; echo "${c_red}$1${c_off}"; exit 1; }
confirm() { [[ $YES == 1 ]] && return 0; local a; read -r -p "$1 [Y/n] " a; [[ -z $a || $a =~ ^[Yy] ]]; }
sha() { sha256sum "$1" | cut -d' ' -f1; }
cleanup() { [[ -n $TEMP && -d $TEMP ]] && rm -rf "$TEMP"; return 0; }
trap cleanup EXIT

for tool in sha256sum find; do command -v "$tool" >/dev/null || fail "Missing tool: $tool"; done

is_protected() {
    local rel="$1"
    if [[ $MODE == fusion ]]; then [[ $rel =~ ^html/(img|images|media|sounds)/ || $rel =~ ^tiles/ || $rel =~ ^data/(labels|edited-postals)\.json$ ]]; return; fi
    [[ $rel =~ (^|/)config[^/]*\.lua$ || $rel =~ (^|/)(config|configs|locales|locale|lang)/ || $rel =~ \.cfg$ || $rel =~ (^|/)settings\.lua$ ]]
}
is_text() { [[ ${1,,} =~ \.(lua|js|json|cfg|html|htm|css|txt|md|yaml|yml|xml|meta|sql|ts|ini)$ ]]; }

# Three-way merge of one resource
merge_resource() {
    local pkg="$1" dest="$2" name="$3"
    local -A rec=() newmap=()
    local have_rec=0 existed=0 line rel f dst nh cur yours
    local added=0 updated=0 same=0 removed=0
    local -a kept=() leftover=()

    if [[ -f "$dest/$RECORD" ]]; then
        have_rec=1
        while IFS= read -r line || [[ -n $line ]]; do
            line="${line%$'\r'}"
            [[ $line =~ ^([0-9a-f]{64})\ \ (.+)$ ]] && rec["${BASH_REMATCH[2]}"]="${BASH_REMATCH[1]}"
        done < "$dest/$RECORD"
    fi
    if [[ -d $dest ]]; then existed=1; mkdir -p "$BACKUP_DIR"; cp -a "$dest" "$BACKUP_DIR/$name"; else mkdir -p "$dest"; fi

    local newrec; newrec="$(mktemp)"
    while IFS= read -r -d '' f; do
        rel="${f#"$pkg"/}"
        [[ $rel == "$RECORD" ]] && continue
        newmap["$rel"]=1
        nh="$(sha "$f")"
        printf '%s  %s\n' "$nh" "$rel" >> "$newrec"
        dst="$dest/$rel"
        if [[ ! -f $dst ]]; then mkdir -p "$(dirname "$dst")"; cp "$f" "$dst"; added=$((added + 1)); continue; fi
        cur="$(sha "$dst")"
        if [[ $cur == "$nh" ]]; then same=$((same + 1)); continue; fi
        # the update doesn't change this file: whatever is there (yours or ours) stays
        if [[ $have_rec == 1 && -n ${rec[$rel]+x} && ${rec[$rel]} == "$nh" ]]; then same=$((same + 1)); continue; fi
        yours=0
        if [[ $have_rec == 1 ]]; then
            [[ -n ${rec[$rel]+x} && ${rec[$rel]} == "$cur" ]] || yours=1
        elif is_protected "$rel"; then
            yours=1
        fi
        if [[ $yours == 0 ]]; then cp "$f" "$dst"; updated=$((updated + 1)); continue; fi
        if is_text "$rel"; then cp "$f" "$dst.new"; kept+=("$rel  (new version saved as $(basename "$rel").new)"); else kept+=("$rel"); fi
    done < <(find "$pkg" -type f -print0)

    if [[ $have_rec == 1 ]]; then
        for rel in "${!rec[@]}"; do
            [[ -n ${newmap[$rel]+x} ]] && continue
            dst="$dest/$rel"
            [[ -f $dst ]] || continue
            if [[ "$(sha "$dst")" == "${rec[$rel]}" ]]; then rm -f "$dst"; removed=$((removed + 1)); else leftover+=("$rel"); fi
        done
    fi
    sort -k2 "$newrec" > "$dest/$RECORD"; rm -f "$newrec"

    local verb="Installed"; [[ $existed == 1 ]] && verb="Updated"
    say "$(printf '  %-26s %s: %d new, %d changed, %d unchanged, %d removed' "$name" "$verb" "$added" "$updated" "$same" "$removed")" "$c_grn"
    local k
    for k in "${kept[@]+"${kept[@]}"}"; do say "      kept your version: $k" "$c_yel"; ATTENTION=1; done
    for k in "${leftover[@]+"${leftover[@]}"}"; do say "      no longer used, kept because you edited it: $k" "$c_yel"; ATTENTION=1; done
}

find_package() {
    if [[ -n $SOURCE ]]; then echo "$SOURCE"; return; fi
    if [[ $MODE == fusion ]]; then
        mkdir -p "$ROOT/updates"
        local zip; zip="$(ls -t "$ROOT"/updates/*.zip 2>/dev/null | head -n1 || true)"
        [[ -n $zip ]] || fail "Upload the Fusion Menu zip from your Cfx.re keymaster to $ROOT/updates/ and run this again."
        echo "$zip"; return
    fi
    fail "Give the script's zip or folder: $0 script /path/to/script.zip"
}

expand_package() {
    local p="$1"
    if [[ -d $p ]]; then echo "$p"; return; fi
    [[ -f $p ]] || fail "Not found: $p"
    [[ ${p,,} == *.zip ]] || fail "Only .zip files or folders are supported. Extract .rar / .7z files first."
    command -v unzip >/dev/null || fail "unzip is not installed (apt install unzip)"
    TEMP="$(mktemp -d)"
    unzip -q "$p" -d "$TEMP"
    echo "$TEMP"
}

# Resource roots = folders with an fxmanifest.lua / __resource.lua (not nested in another resource)
find_resources() {
    local -a roots=()
    local d r nested
    while IFS= read -r d; do
        nested=0
        for r in "${roots[@]+"${roots[@]}"}"; do [[ $d == "$r"/* ]] && nested=1 && break; done
        [[ $nested == 0 ]] && roots+=("$d")
    done < <(find "$1" -type f \( -name fxmanifest.lua -o -name __resource.lua \) -printf '%h\n' | sort -u | awk '{ print length, $0 }' | sort -n | cut -d' ' -f2-)
    printf '%s\n' "${roots[@]+"${roots[@]}"}"
}

get_version() { [[ -f $1/fxmanifest.lua ]] && sed -nE "s/^version[[:space:]]+'([^']+)'.*/\1/p" "$1/fxmanifest.lua" | head -n1; }

find_existing() {
    local name="$1" under="$2" d
    [[ -d $under ]] || return 0
    while IFS= read -r d; do
        if [[ -f $d/fxmanifest.lua || -f $d/__resource.lua ]]; then echo "$d"; return; fi
    done < <(find "$under" -type d -name "$name" 2>/dev/null)
}

version_lt() { [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" == "$1" ]]; }

# ------------------------------------------------------------------ Server must be stopped
if [[ $IGNORE_RUNNING == 0 ]]; then
    if { command -v systemctl >/dev/null && systemctl is-active --quiet fusion 2>/dev/null; } || pgrep -f 'cfx-server/FXServer|/FXServer ' >/dev/null 2>&1; then
        fail "The server is running. Stop it first (sudo systemctl stop fusion, or txAdmin > Stop server), then run this again."
    fi
fi

PKG_PATH="$(find_package)"
PKG="$(expand_package "$PKG_PATH")"
mapfile -t FOUND < <(find_resources "$PKG")
[[ ${#FOUND[@]} -gt 0 && -n ${FOUND[0]} ]] || fail "No resources found in $PKG_PATH (no fxmanifest.lua inside)."

if [[ $MODE == fusion ]]; then
    CORE=""
    for r in "${FOUND[@]}"; do [[ "$(basename "$r")" == fusion-core ]] && CORE="$r"; done
    [[ -n $CORE ]] || fail "This is not a Fusion Menu package (fusion-core is missing)."
    NEW_VER="$(get_version "$CORE")"
    INSTALLED_CORE="$(find_existing fusion-core "$FUSION_DIR")"
    OLD_VER=""; [[ -n $INSTALLED_CORE ]] && OLD_VER="$(get_version "$INSTALLED_CORE")"
    echo
    say "Fusion Menu update: $( [[ -n $OLD_VER ]] && echo "v$OLD_VER" || echo "not installed" ) -> v$NEW_VER" "$c_cyn"
    if [[ -n $OLD_VER && -n $NEW_VER && $FORCE == 0 ]] && version_lt "$NEW_VER" "$OLD_VER"; then
        fail "This package (v$NEW_VER) is older than what you have (v$OLD_VER). Run with --force to downgrade anyway."
    fi
    say "Backups go to backups/$STAMP"
    confirm "Continue?" || exit 0
    mkdir -p "$BACKUP_DIR"

    # database backup
    CFG="$ROOT/server.cfg"
    CS="$( [[ -f $CFG ]] && sed -nE 's/^[[:space:]]*set[[:space:]]+mysql_connection_string[[:space:]]+"([^"]+)".*/\1/p' "$CFG" | head -n1 || true)"
    if [[ -n $CS ]]; then
        DB_USER="" DB_PASS="" DB_HOST="localhost" DB_PORT="3306" DB_NAME=""
        if [[ $CS =~ ^mysql://([^:@/]+)(:([^@]*))?@([^:/]+)(:([0-9]+))?/([^?]+) ]]; then
            DB_USER="${BASH_REMATCH[1]}"; DB_PASS="${BASH_REMATCH[3]}"; DB_HOST="${BASH_REMATCH[4]}"; DB_PORT="${BASH_REMATCH[6]:-3306}"; DB_NAME="${BASH_REMATCH[7]}"
        else
            IFS=';' read -ra parts <<< "$CS"
            for part in "${parts[@]}"; do
                key="${part%%=*}"; val="${part#*=}"; key="${key,,}"; key="${key// /}"
                case "$key" in user|userid|uid|username) DB_USER="$val" ;; password|pwd) DB_PASS="$val" ;; host|server) DB_HOST="$val" ;; port) DB_PORT="$val" ;; database|db) DB_NAME="$val" ;; esac
            done
        fi
        if command -v mysqldump >/dev/null && [[ -n $DB_NAME ]]; then
            if MYSQL_PWD="$DB_PASS" mysqldump --user="$DB_USER" --host="$DB_HOST" --port="$DB_PORT" --single-transaction --routines "$DB_NAME" > "$BACKUP_DIR/database.sql" 2>/dev/null; then
                say "  Database '$DB_NAME' backed up to backups/$STAMP/database.sql" "$c_grn"
            else
                confirm "  Database backup failed (is MariaDB running?). Continue without it?" || exit 1
            fi
        else
            confirm "  mysqldump not found, so the database cannot be backed up. Continue without it?" || exit 1
        fi
    fi

    NEW_RESOURCES=()
    for r in "${FOUND[@]}"; do
        name="$(basename "$r")"
        dest="$(find_existing "$name" "$FUSION_DIR")"
        if [[ -z $dest ]]; then
            if [[ $name == fusion-* ]]; then dest="$FUSION_DIR/$name"; NEW_RESOURCES+=("$name"); else dest="$FUSION_DIR/[compat]/$name"; fi
        fi
        merge_resource "$r" "$dest" "$name"
    done

    # every Fusion module needs an ensure line (new ones, and any an earlier install missed),
    # added in order after the last "ensure fusion-..." line
    if [[ -f $CFG ]] && ! grep -Eq '^[[:space:]]*ensure[[:space:]]+\[fusion\][[:space:]]*'$'\r''?$' "$CFG"; then
        backed_up=0
        for r in "${FOUND[@]}"; do
            n="$(basename "$r")"
            [[ $n == fusion-* ]] || continue
            grep -Eq "^[[:space:]]*(ensure|start)[[:space:]]+$n[[:space:]]*"$'\r'"?\$" "$CFG" && continue
            [[ $backed_up == 1 ]] || { cp "$CFG" "$BACKUP_DIR/server.cfg"; backed_up=1; }
            last="$(grep -nE '^[[:space:]]*ensure[[:space:]]+fusion-[A-Za-z0-9_-]+[[:space:]]*'$'\r''?$' "$CFG" | tail -n1 | cut -d: -f1)"
            corel="$(grep -nE '^[[:space:]]*ensure[[:space:]]+fusion-core[[:space:]]*'$'\r''?$' "$CFG" | head -n1 | cut -d: -f1)"
            if [[ $n == fusion-updater && -n $corel ]]; then
                # before fusion-core, so it can repair an interrupted update before Fusion loads
                awk -v add="ensure $n" -v at="$corel" 'NR == at { print add (/\r$/ ? "\r" : "") } { print }' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
            elif [[ -n $last ]]; then
                awk -v add="ensure $n" -v at="$last" '{ print } NR == at { print add (/\r$/ ? "\r" : "") }' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
            else
                printf '\nensure %s\n' "$n" >> "$CFG"
            fi
            say "  Added 'ensure $n' to server.cfg" "$c_grn"
        done
    # F10 > Script Configs "Start with the server": server.cfg runs Fusion's start list at its very end
    if ! grep -Eq '^[[:space:]]*exec[[:space:]]+resources/\[fusion\]/fusion-core/permissions/startup\.cfg' "$CFG"; then
        [[ $backed_up == 1 ]] || { cp "$CFG" "$BACKUP_DIR/server.cfg"; backed_up=1; }
        printf '\n# Scripts set to "Start with the server" in F10 > Script Configs. Keep this line LAST.\nexec resources/[fusion]/fusion-core/permissions/startup.cfg\n' >> "$CFG"
        say "  Added 'exec resources/[fusion]/fusion-core/permissions/startup.cfg' to the end of server.cfg" "$c_grn"
    fi
    fi
else
    echo
    say "Installing from $PKG_PATH" "$c_cyn"
    PLAN=()
    for r in "${FOUND[@]}"; do
        name="$(basename "$r")"
        if [[ $REPLACED == *" $name "* && $FORCE == 0 ]]; then say "  $name skipped: Fusion Menu already does this job. To use it instead, turn Fusion's version off in Settings > Modules, then run this again with --force." "$c_yel"; continue; fi
        if [[ -n "$(find_existing "$name" "$FUSION_DIR")" ]]; then say "  $name skipped: that name belongs to Fusion Menu. Use update-fusion.sh for Fusion updates." "$c_yel"; continue; fi
        dest=""
        for top in "$RESOURCES"/*/; do
            top="${top%/}"
            case "$(basename "$top")" in "[fusion]"|"[cfx-default]") continue ;; esac
            if [[ "$(basename "$top")" == "$name" ]]; then dest="$top"; break; fi
            dest="$(find_existing "$name" "$top")"
            [[ -n $dest ]] && break
        done
        if [[ -z $dest ]]; then
            folder="$TARGET"
            if [[ $folder == auto ]]; then
                manifest="$r/fxmanifest.lua"; [[ -f $manifest ]] || manifest="$r/__resource.lua"
                if grep -Eq '^[[:space:]]*(client|server|shared)_scripts?\b' "$manifest"; then folder=qb; else folder=addons; fi
            fi
            if [[ $folder == qb || $folder == addons ]]; then sub="[$folder]"; else sub="${folder#/}"; sub="${sub%/}"; fi
            [[ $sub =~ ^\[(qb|addons)\] ]] || fail "Target must be qb, addons, or a folder inside [qb] / [addons] (e.g. \"[addons]/[cars]\")."
            dest="$RESOURCES/$sub/$name"
        fi
        PLAN+=("$r|$dest|$name")
        what="install"; [[ -d $dest ]] && what="upgrade"
        say "$(printf '  %-26s %s -> %s' "$name" "$what" "${dest#"$ROOT"/}")"
    done
    [[ ${#PLAN[@]} -gt 0 ]] || exit 0
    confirm "Continue?" || exit 0
    mkdir -p "$BACKUP_DIR"
    for p in "${PLAN[@]}"; do IFS='|' read -r r dest name <<< "$p"; merge_resource "$r" "$dest" "$name"; done
fi

mkdir -p "$BACKUP_DIR"
printf '%s\n' "${REPORT[@]}" > "$BACKUP_DIR/report.txt"
echo
if [[ $ATTENTION == 1 ]]; then
    say "Some files were kept because you had changed them (yellow above). Compare each with its .new file" "$c_yel"
    say "and copy over anything new you want, then delete the .new file." "$c_yel"
fi
say "Done. Backup and report: backups/$STAMP" "$c_cyn"
say "Start the server again (sudo systemctl start fusion, or from txAdmin)." "$c_cyn"
