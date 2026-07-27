#!/usr/bin/env bash
#
# pedalier-deploy — déploiement du pédalier depuis le poste de développement.
#
# Répartition des rôles : le Pi va chercher le code lui-même par git (il a
# internet), le Mac ne pousse que ce que git ne transporte pas — les artefacts
# du build Qt, wasm de 40 Mo en tête. Le reste est piloté via pedalier-ctl.
#
#   ./pedalier-deploy.sh                 mise à jour complète
#   ./pedalier-deploy.sh bootstrap       première installation
#   ./pedalier-deploy.sh build           pousse seulement les artefacts de build
#   ./pedalier-deploy.sh doctor          diagnostic de la machine
#   ./pedalier-deploy.sh --help

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

PROJECT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
WEB_DIR="$PROJECT_DIR/webfiles"
WASM="qmlwebsocketserver.wasm"

HOST="${PEDALIER_HOST:-192.168.1.21}"
USER_NAME="${PEDALIER_USER:-sirenateur}"
DO_BUILD=false
DO_REBOOT=false
EXTRA_ARGS=()

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)

usage() {
    cat <<'EOF'
pedalier-deploy — déploiement du pédalier sur le Raspberry (à lancer sur le Mac)

  deploy (défaut)   met à jour la machine puis pousse le build
  bootstrap         première installation sur une Debian vierge
  build             pousse les artefacts de build : wasm, glue JS, page, module QML
                    (alias : wasm — remplace testServerOnRasp.sh)
  status            état des services
  doctor            diagnostic complet
  logs [unité]      journal en direct (défaut : pedalier-pd)
  ctl <phase…>      exécute une phase isolée de pedalier-ctl (deps, pd-build…)
  restart           relance les services
  songs pull        rapatrie les morceaux du Pi
  songs push <arch> renvoie une sauvegarde de morceaux vers le Pi
  legacy-fetch      rapatrie l'ancien server.js du Pi (référence historique)
  node-modules      pousse node_modules/ si npm est inutilisable sur le Pi
  setup-ssh         installe une clé ssh sur la machine
  shell             ouvre une session ssh

Options :
  --host <ip>       défaut : 192.168.1.21 (ou $PEDALIER_HOST)
  --user <nom>      défaut : sirenateur
  --build           reconstruit le wasm avant de déployer
  --dry-run         simulation, des deux côtés
  --yes             ne pose aucune question
  --reboot          redémarre la machine à la fin
EOF
}

remote() { ssh "${SSH_OPTS[@]}" "$USER_NAME@$HOST" "$@"; }

require_host() {
    info "connexion à $USER_NAME@$HOST"
    remote true 2>/dev/null || die "machine injoignable — vérifier qu'elle est allumée et sur le réseau"
}

# Le script distant tourne depuis une copie dans /tmp, jamais depuis le dépôt
# cloné : une phase qui fait avancer git réécrirait le fichier en cours
# d'exécution et bash se mettrait à lire du charabia.
stage_scripts() {
    STAGE="/tmp/pedalier-deploy.$(date +%s)"
    debug "envoi des scripts vers $STAGE"
    rsync -a --delete -e "ssh ${SSH_OPTS[*]}" "$SCRIPT_DIR/" "$USER_NAME@$HOST:$STAGE/" \
        || die "envoi des scripts impossible"
    remote "chmod +x $STAGE/pedalier-ctl.sh $STAGE/device/pedalier-kiosk.sh"
}

ctl() {
    local opts=""
    [ "$DRY_RUN" = true ] && opts="$opts --dry-run"
    [ "$ASSUME_YES" = true ] && opts="$opts --yes"
    [ "$VERBOSE" = true ] && opts="$opts --verbose"
    # -t seulement si on a un vrai terminal : le script distant peut demander une
    # confirmation, mais réclamer un pty depuis un pipe ne fait que du bruit.
    if [ -t 0 ]; then
        ssh -t "${SSH_OPTS[@]}" "$USER_NAME@$HOST" "$STAGE/pedalier-ctl.sh $opts $*"
    else
        ssh "${SSH_OPTS[@]}" "$USER_NAME@$HOST" "$STAGE/pedalier-ctl.sh $opts $*"
    fi
}

remote_web_dir() {
    local dir; dir=$(remote "grep -E '^PEDALIER_REPO=' ~/.config/pedalier/env 2>/dev/null | cut -d= -f2" | tr -d '\r')
    printf '%s/pedalierSirenium/webfiles' "${dir:-/home/$USER_NAME/dev/src/mecaviv-qml-ui}"
}

# Les sorties du build forment un tout : le wasm, la glue JS, la page et le
# module QML viennent de la même compilation et ne se mélangent pas entre
# versions. Git ne transporte que les sources et le serveur — les artefacts
# passent tous par ici, ensemble.
push_build() {
    phase "Transfert du build"
    [ -f "$WEB_DIR/$WASM" ] || die "$WEB_DIR/$WASM absent — le construire avec ./scripts/build_run_web.sh"

    local remote_web; remote_web=$(remote_web_dir)
    local local_sha remote_sha
    local_sha=$(sha_of "$WEB_DIR/$WASM")
    remote_sha=$(remote "sha256sum '$remote_web/$WASM' 2>/dev/null | cut -d' ' -f1" | tr -d '\r')

    if [ "$local_sha" = "$remote_sha" ]; then
        skip "build ($(du -h "$WEB_DIR/$WASM" | cut -f1), identique)"
        return 0
    fi

    local rsync_opts=(-a -e "ssh ${SSH_OPTS[*]}")
    [ "$DRY_RUN" = true ] && rsync_opts+=(-n)
    remote "mkdir -p '$remote_web'"

    # Le wasm est servi au moment même où on le remplace : on écrit à côté, on
    # vérifie l'empreinte, et on bascule d'un seul mv. Un transfert coupé laisse
    # l'ancien binaire intact plutôt qu'une page morte.
    info "envoi du wasm ($(du -h "$WEB_DIR/$WASM" | cut -f1))"
    rsync "${rsync_opts[@]}" --info=progress2 "$WEB_DIR/$WASM" "$USER_NAME@$HOST:$remote_web/$WASM.new" \
        || die "transfert interrompu — l'ancien wasm est intact"

    info "envoi de la glue JS, de la page et du module QML"
    rsync "${rsync_opts[@]}" --delete \
        "$WEB_DIR/qmlwebsocketserver.js" "$WEB_DIR/qmlwebsocketserver.html" \
        "$WEB_DIR/qtloader.js" "$WEB_DIR/qtlogo.svg" "$WEB_DIR/config.js" \
        "$WEB_DIR/qmlwebsocketserver" \
        "$USER_NAME@$HOST:$remote_web/" || die "envoi des artefacts échoué"

    if [ "$DRY_RUN" = true ]; then
        printf '%s  [simulation] bascule de %s.new%s\n' "$C_DIM" "$WASM" "$C_RESET"
        return 0
    fi

    local check; check=$(remote "sha256sum '$remote_web/$WASM.new' | cut -d' ' -f1" | tr -d '\r')
    [ "$check" = "$local_sha" ] || { remote "rm -f '$remote_web/$WASM.new'"; die "empreinte incorrecte après transfert — rien n'a été remplacé"; }
    remote "mv '$remote_web/$WASM.new' '$remote_web/$WASM'"
    ok "build déployé (wasm sha $(printf '%s' "$local_sha" | cut -c1-12))"
}

build_wasm() {
    phase "Construction du wasm"
    run_sh "cd '$PROJECT_DIR' && ./scripts/build_run_web.sh --no-clean --no-open" || die "build échoué"
}

cmd_deploy() {
    local mode="${1:-update}"
    require_host
    [ "$DO_BUILD" = true ] && build_wasm
    stage_scripts
    ctl "$mode" --no-restart || die "pedalier-ctl a échoué"
    push_build
    ctl restart
    ctl doctor
    [ "$DO_REBOOT" = true ] && { info "redémarrage"; remote "sudo reboot" || true; }
    phase "Déploiement terminé sur $HOST"
}

cmd_songs_pull() {
    require_host
    stage_scripts
    ctl songs save
    local dest="$PROJECT_DIR/songs/$HOST"
    run mkdir -p "$dest"
    info "rapatriement des sauvegardes vers songs/$HOST/"
    local rsync_opts=(-av -e "ssh ${SSH_OPTS[*]}")
    [ "$DRY_RUN" = true ] && rsync_opts+=(-n)
    rsync "${rsync_opts[@]}" "$USER_NAME@$HOST:pedalier-data/backups/" "$dest/" || die "rsync échoué"
    ok "morceaux dans $dest"
}

cmd_songs_push() {
    local archive="${1:?usage: songs push <archive.tar.gz>}"
    [ -f "$archive" ] || die "archive introuvable : $archive"
    require_host
    stage_scripts
    local base; base=$(basename "$archive")
    remote "mkdir -p pedalier-data/backups"
    run_sh "rsync -av -e 'ssh ${SSH_OPTS[*]}' '$archive' '$USER_NAME@$HOST:pedalier-data/backups/$base'" || die "envoi échoué"
    ctl songs restore "$base"
}

cmd_legacy_fetch() {
    require_host
    local dest="$PROJECT_DIR/deploy/legacy"
    run mkdir -p "$dest"
    run_sh "rsync -av -e 'ssh ${SSH_OPTS[*]}' '$USER_NAME@$HOST:dev/src/mecaviv/patko-scratchpad/qtQmlSockets/pedalierSirenium/webfiles/server.js' '$dest/server.js.pi'" \
        && ok "ancien server.js dans $dest/server.js.pi"
}

cmd_node_modules() {
    require_host
    [ -d "$WEB_DIR/node_modules" ] || die "node_modules absent en local — npm install d'abord"
    local remote_web="/home/$USER_NAME/dev/src/mecaviv-qml-ui/pedalierSirenium/webfiles"
    info "envoi de node_modules/ (express est du JS pur, portable Mac → aarch64)"
    local rsync_opts=(-a --delete -e "ssh ${SSH_OPTS[*]}")
    [ "$DRY_RUN" = true ] && rsync_opts+=(-n)
    rsync "${rsync_opts[@]}" "$WEB_DIR/node_modules/" "$USER_NAME@$HOST:$remote_web/node_modules/" && ok "node_modules déployé"
}

cmd_setup_ssh() {
    local key="$HOME/.ssh/id_ed25519"
    [ -f "$key" ] || run ssh-keygen -t ed25519 -f "$key" -N ''
    run ssh-copy-id -i "$key.pub" "$USER_NAME@$HOST" && ok "clé installée sur $HOST"
}

main() {
    local cmd=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --host) HOST="${2:?}"; shift ;;
            --user) USER_NAME="${2:?}"; shift ;;
            --build) DO_BUILD=true ;;
            --reboot) DO_REBOOT=true ;;
            --dry-run) DRY_RUN=true ;;
            --yes|-y) ASSUME_YES=true ;;
            --verbose|-v) VERBOSE=true ;;
            --help|-h) usage; exit 0 ;;
            -*) die "option inconnue : $1" ;;
            *) [ -z "$cmd" ] && cmd="$1" || EXTRA_ARGS+=("$1") ;;
        esac
        shift
    done

    [ "$DRY_RUN" = true ] && warn "mode simulation : aucune modification, ici comme sur le Pi"

    case "${cmd:-deploy}" in
        deploy)       cmd_deploy update ;;
        bootstrap)    cmd_deploy bootstrap ;;
        build|wasm)   require_host; push_build ;;
        status)       require_host; stage_scripts; ctl status ;;
        doctor)       require_host; stage_scripts; ctl doctor ;;
        restart)      require_host; stage_scripts; ctl restart ;;
        logs)         require_host; stage_scripts; ctl logs "${EXTRA_ARGS[0]:-}" ;;
        # Passe-plat vers pedalier-ctl, pour une phase isolée :
        #   ./pedalier-deploy.sh ctl pd-build
        ctl)          require_host; stage_scripts; ctl "${EXTRA_ARGS[@]:-status}" ;;
        songs)
            case "${EXTRA_ARGS[0]:-pull}" in
                pull) cmd_songs_pull ;;
                push) cmd_songs_push "${EXTRA_ARGS[1]:-}" ;;
                *) die "songs : pull | push <archive>" ;;
            esac ;;
        legacy-fetch) cmd_legacy_fetch ;;
        node-modules) cmd_node_modules ;;
        setup-ssh)    cmd_setup_ssh ;;
        shell)        exec ssh -t "$USER_NAME@$HOST" ;;
        *) err "commande inconnue : $cmd"; usage; exit 1 ;;
    esac
}

main "$@"
