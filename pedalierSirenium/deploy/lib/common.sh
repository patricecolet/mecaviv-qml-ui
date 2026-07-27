# shellcheck shell=bash
#
# Socle commun aux deux moitiés du déploiement : pedalier-ctl.sh (sur le Pi) et
# pedalier-deploy.sh (sur le Mac). Journalisation, exécution sous --dry-run,
# verrou, jalons d'idempotence, attentes actives.
#
# Ce fichier est sourcé, jamais exécuté.

set -uo pipefail

# --- Couleurs (désactivées si la sortie n'est pas un terminal) ---------------

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
    C_RESET=''; C_BOLD=''; C_DIM=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''
fi

DRY_RUN="${DRY_RUN:-false}"
ASSUME_YES="${ASSUME_YES:-false}"
VERBOSE="${VERBOSE:-false}"

# --- Journalisation ---------------------------------------------------------

log()      { printf '%s\n' "$*"; }
info()     { printf '%s→%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()       { printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
skip()     { printf '%s·%s %s %s(déjà à jour)%s\n' "$C_DIM" "$C_RESET" "$*" "$C_DIM" "$C_RESET"; }
warn()     { printf '%s⚠%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()      { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
debug()    { [ "$VERBOSE" = true ] && printf '%s  %s%s\n' "$C_DIM" "$*" "$C_RESET" >&2; return 0; }
die()      { err "$*"; exit 1; }

phase()    { printf '\n%s▌ %s%s\n' "$C_BOLD" "$*" "$C_RESET"; }

# --- Exécution --------------------------------------------------------------
#
# TOUTE mutation passe par run(). C'est la seule chose qui rend --dry-run
# crédible : si une commande modifie l'état sans passer par ici, la simulation
# ment. Les lectures (test, grep, git rev-parse…) s'appellent directement.

run() {
    if [ "$DRY_RUN" = true ]; then
        printf '%s  [simulation] %s%s\n' "$C_DIM" "$*" "$C_RESET"
        return 0
    fi
    debug "\$ $*"
    "$@"
}

# Idem, mais pour une commande qui a besoin d'un shell (pipes, redirections).
run_sh() {
    if [ "$DRY_RUN" = true ]; then
        printf '%s  [simulation] sh -c %s%s\n' "$C_DIM" "$1" "$C_RESET"
        return 0
    fi
    debug "\$ $1"
    sh -c "$1"
}

confirm() {
    [ "$ASSUME_YES" = true ] && return 0
    [ "$DRY_RUN" = true ] && return 0
    printf '%s? %s [o/N] %s' "$C_YELLOW" "$*" "$C_RESET"
    local answer=''
    read -r answer </dev/tty || return 1
    case "$answer" in o|O|y|Y|oui|yes) return 0 ;; *) return 1 ;; esac
}

# --- Verrou -----------------------------------------------------------------
#
# Deux déploiements concurrents sur la même machine s'écraseraient l'un l'autre
# au milieu d'un build ou d'un git merge.

acquire_lock() {
    local lockfile="${1:?}"
    mkdir -p "$(dirname "$lockfile")"
    if command -v flock >/dev/null 2>&1; then
        exec 9>"$lockfile"
        flock -n 9 || die "un déploiement est déjà en cours (verrou $lockfile)"
    fi
}

# --- Jalons d'idempotence ---------------------------------------------------
#
# Un jalon retient ce qui a été fait et avec quelle entrée, pour qu'une phase
# sache se sauter quand rien n'a bougé.

STATE_DIR="${STATE_DIR:-$HOME/.local/state/pedalier}"

stamp_read()  { cat "$STATE_DIR/$1" 2>/dev/null || true; }
stamp_write() {
    [ "$DRY_RUN" = true ] && { printf '%s  [simulation] jalon %s=%s%s\n' "$C_DIM" "$1" "$2" "$C_RESET"; return 0; }
    mkdir -p "$STATE_DIR" && printf '%s\n' "$2" > "$STATE_DIR/$1"
}
stamp_matches() { [ -n "$2" ] && [ "$(stamp_read "$1")" = "$2" ]; }

# Âge d'un jalon en jours ; 99999 s'il n'existe pas.
stamp_age_days() {
    local f="$STATE_DIR/$1"
    [ -f "$f" ] || { echo 99999; return; }
    local now mtime
    now=$(date +%s)
    mtime=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0)
    echo $(( (now - mtime) / 86400 ))
}

sha_of() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1; }

# --- Attentes actives -------------------------------------------------------
#
# Remplacent les `sleep 3` de l'ancien start.pedalier.sh : on attend l'état
# voulu, pas une durée devinée.

wait_tcp() {
    local port="${1:?}" timeout="${2:-30}" waited=0
    while [ "$waited" -lt "$timeout" ]; do
        if ss -ltn 2>/dev/null | grep -q ":$port "; then return 0; fi
        sleep 0.5; waited=$(( waited + 1 ))
    done
    return 1
}

wait_http() {
    local url="${1:?}" timeout="${2:-60}" waited=0
    while [ "$waited" -lt "$timeout" ]; do
        if curl -fsS -o /dev/null --max-time 2 "$url"; then return 0; fi
        sleep 0.5; waited=$(( waited + 1 ))
    done
    return 1
}

wait_alsa_client() {
    local pattern="${1:?}" timeout="${2:-30}" waited=0
    while [ "$waited" -lt "$timeout" ]; do
        if aconnect -l 2>/dev/null | grep -qi "$pattern"; then return 0; fi
        sleep 0.5; waited=$(( waited + 1 ))
    done
    return 1
}

# --- Blocs gérés dans un fichier partagé ------------------------------------
#
# Réécrit intégralement la zone délimitée plutôt que d'ajouter en fin de
# fichier : rejouable sans accumuler de doublons.

BLOCK_BEGIN='# >>> pedalier (géré par pedalier-ctl, ne pas éditer) >>>'
BLOCK_END='# <<< pedalier <<<'

write_managed_block() {
    local file="${1:?}" content="${2:?}"
    local current='' desired
    desired="$BLOCK_BEGIN
$content
$BLOCK_END"

    if [ -f "$file" ]; then
        current=$(sed -n "/^$(printf '%s' "$BLOCK_BEGIN" | sed 's/[][\.*^$/]/\\&/g')$/,/^$(printf '%s' "$BLOCK_END" | sed 's/[][\.*^$/]/\\&/g')$/p" "$file")
    fi
    if [ "$current" = "$desired" ]; then
        return 1   # rien à faire
    fi
    if [ "$DRY_RUN" = true ]; then
        printf '%s  [simulation] bloc pedalier réécrit dans %s%s\n' "$C_DIM" "$file" "$C_RESET"
        return 0
    fi
    mkdir -p "$(dirname "$file")"
    local tmp; tmp=$(mktemp)
    if [ -f "$file" ] && [ -n "$current" ]; then
        sed "/^$(printf '%s' "$BLOCK_BEGIN" | sed 's/[][\.*^$/]/\\&/g')$/,/^$(printf '%s' "$BLOCK_END" | sed 's/[][\.*^$/]/\\&/g')$/d" "$file" > "$tmp"
    elif [ -f "$file" ]; then
        cat "$file" > "$tmp"
    fi
    printf '%s\n' "$desired" >> "$tmp"
    mv "$tmp" "$file"
    return 0
}

# Installe un fichier seulement s'il diffère de ce qu'on veut y mettre.
# Renvoie 0 si le fichier a changé, 1 s'il était déjà bon.
install_file() {
    local dest="${1:?}" content="${2:?}" mode="${3:-644}"
    if [ -f "$dest" ] && [ "$(cat "$dest")" = "$content" ]; then
        return 1
    fi
    if [ "$DRY_RUN" = true ]; then
        printf '%s  [simulation] écriture de %s%s\n' "$C_DIM" "$dest" "$C_RESET"
        return 0
    fi
    mkdir -p "$(dirname "$dest")"
    printf '%s\n' "$content" > "$dest"
    chmod "$mode" "$dest"
    return 0
}
