#!/bin/bash
#
# Setup SSH access to all sirens for SirenManager.
#
# What it does:
#   1. Generates an SSH key (~/.ssh/id_rsa_sirenes) if it doesn't exist.
#   2. Optionally adds Host aliases to ~/.ssh/config (linux-maître,
#      sirene-s1, sirene-s2, …) with the legacy SHA-1 KEX/HostKey/Pubkey
#      algorithms required by the Artila M508 sirens.
#   3. Pushes the public key to each machine via ssh-copy-id, prompting
#      for the root password once per host.
#
# Usage:
#   ./scripts/setup-ssh.sh                  # keys + push, leave ~/.ssh/config untouched
#   ./scripts/setup-ssh.sh --config         # also append Host aliases to ~/.ssh/config
#   ./scripts/setup-ssh.sh --only linux-maître,sirene-s1   # operate on a subset
#   ./scripts/setup-ssh.sh --skip-existing  # don't push to hosts where key already works
#
# After this, `node backend/server.js` can talk to every machine without prompting.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()     { echo -e "${RED}[ERROR]${NC} $1"; }

UPDATE_SSH_CONFIG=0
SKIP_EXISTING=0
ONLY_HOSTS=""

SSH_KEY_PATH="$HOME/.ssh/id_rsa_sirenes"
SSH_PUB_KEY_PATH="$SSH_KEY_PATH.pub"

# ALIAS  IP  USER
declare -a machines=(
    "linux-maître   192.168.1.101  root"
    "raspberry-clic 192.168.1.104  pi"
    "sirene-s1      192.168.1.11   root"
    "sirene-s2      192.168.1.12   root"
    "sirene-s3      192.168.1.13   root"
    "sirene-s4      192.168.1.14   root"
    "sirene-s5      192.168.1.15   root"
    "sirene-s6      192.168.1.16   root"
    "sirene-s7      192.168.1.17   root"
    "voiture-a      192.168.1.50   root"
    "voiture-b      192.168.1.51   root"
    "pavillon-1     192.168.1.52   root"
    "pavillon-2     192.168.1.53   root"
)

generate_ssh_key() {
    if [ -f "$SSH_KEY_PATH" ]; then
        info "Clé SSH déjà présente: $SSH_KEY_PATH"
    else
        info "Génération de la clé SSH..."
        ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "sirenmanager-$(hostname)"
        info "Clé générée: $SSH_KEY_PATH"
    fi
}

# Append a Host stanza per machine to ~/.ssh/config — idempotent: skips
# if the alias is already declared anywhere in the file.
update_ssh_config() {
    local cfg="$HOME/.ssh/config"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    touch "$cfg"
    chmod 600 "$cfg"

    local backup="$cfg.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$cfg" "$backup"
    info "Sauvegarde de ~/.ssh/config: $backup"

    local added=0
    for machine in "${machines[@]}"; do
        read -r alias ip user <<< "$machine"
        if grep -qE "^[[:space:]]*Host[[:space:]]+$alias([[:space:]]|$)" "$cfg"; then
            info "Host '$alias' déjà présent dans ~/.ssh/config — laissé intact"
            continue
        fi
        cat >> "$cfg" <<EOF

Host $alias
    HostName $ip
    User $user
    IdentityFile $SSH_KEY_PATH
    KexAlgorithms +diffie-hellman-group-exchange-sha1,diffie-hellman-group1-sha1,diffie-hellman-group14-sha1
    HostKeyAlgorithms +ssh-rsa
    PubkeyAcceptedAlgorithms +ssh-rsa
    IdentitiesOnly yes
    ForwardX11 no
EOF
        added=$((added + 1))
        info "Host '$alias' ajouté"
    done
    info "$added entrée(s) ajoutée(s) à ~/.ssh/config"
}

# Try a no-op SSH command in BatchMode — succeeds only when the key is already
# accepted, so we know whether to skip pushing.
test_passwordless() {
    local alias=$1
    ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
        "$alias" "true" 2>/dev/null
}

push_key() {
    local alias=$1
    local ip=$2
    local user=$3

    if [ "$SKIP_EXISTING" -eq 1 ] && test_passwordless "$alias"; then
        info "✓ $alias: clé déjà installée, skip"
        return 0
    fi

    info "Push clé sur $alias ($user@$ip) — mot de passe demandé une fois…"
    if ssh-copy-id \
        -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=5 \
        -o KexAlgorithms=+diffie-hellman-group-exchange-sha1,diffie-hellman-group1-sha1,diffie-hellman-group14-sha1 \
        -o HostKeyAlgorithms=+ssh-rsa \
        -o PubkeyAcceptedAlgorithms=+ssh-rsa \
        -i "$SSH_PUB_KEY_PATH" \
        "$alias" 2>&1; then
        info "✓ $alias: clé installée"
        return 0
    fi
    err "✗ $alias: échec (host injoignable ou mauvais mot de passe)"
    return 1
}

# Parse args
for arg in "$@"; do
    case "$arg" in
        --config|--ssh-config) UPDATE_SSH_CONFIG=1 ;;
        --skip-existing)       SKIP_EXISTING=1 ;;
        --only) shift; ONLY_HOSTS="$1" ;;
        --only=*) ONLY_HOSTS="${arg#--only=}" ;;
        -h|--help)
            sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
    esac
done

main() {
    echo "=========================================="
    echo "  SirenManager — Setup SSH"
    echo "=========================================="

    generate_ssh_key

    if [ "$UPDATE_SSH_CONFIG" -eq 1 ]; then
        update_ssh_config
    else
        info "~/.ssh/config laissé intact (utilise --config pour ajouter les Host alias)"
    fi
    echo ""

    local success=0 failed=0 skipped=0
    for machine in "${machines[@]}"; do
        read -r alias ip user <<< "$machine"
        if [ -n "$ONLY_HOSTS" ] && [[ ",$ONLY_HOSTS," != *",$alias,"* ]]; then
            skipped=$((skipped + 1))
            continue
        fi
        if push_key "$alias" "$ip" "$user"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
        fi
        echo ""
    done

    echo "=========================================="
    info "Succès: $success    Échecs: $failed    Filtrés: $skipped"
    if [ "$failed" -gt 0 ]; then
        warn "Certaines machines ont échoué — vérifie qu'elles répondent au ping et que le mot de passe est correct."
    fi
}

main
