#!/bin/bash
# Script pour mettre à jour tous les pupitres
# Usage: ./scripts/update-all-pupitres.sh [OPTIONS]

set -e  # Arrêter en cas d'erreur

# Configuration par défaut
SSH_PASSWORD="SIRENS"
SERVER_USER="sirenateur"
CRITAPEC_REPO_URL="https://github.com/patricecolet/critapec-pd-externals.git"
# Git >= 2.27 exige une stratégie explicite si pull.rebase n'est pas configuré sur la machine distante.
# GIT_MERGE_AUTOEDIT=no évite d'ouvrir un éditeur lors d'un merge (sessions SSH non interactives).
GIT_PULL="env GIT_MERGE_AUTOEDIT=no git pull --no-rebase"
# SSH client : évite le message « X11 forwarding request failed » côté serveur
SSH_BASE_OPTS="-o StrictHostKeyChecking=no -o ForwardX11=no"
# ComposeSiren (mecaviv/ComposeSiren) suit master ; surcharge possible : COMPOSESIREN_BRANCH=main ./scripts/...
COMPOSESIREN_BRANCH="${COMPOSESIREN_BRANCH:-master}"
REBOOT_AFTER_UPDATE=false
SELECTED_PUPITRES=""
EXCLUDED_PUPITRES=""
INTERACTIVE_MODE=false
BUILD_COMPOSESIREN=false
BUILD_ONLY=false
DEPLOY_COMPOSESIREN=false
COMPOSESIREN_DEB=""
BUILDER_IP=""
# Évite les verrous apt (packagekitd / unattended-upgrades) avant les installs sur les pupitres
DISABLE_AUTO_UPDATES=true

# Fonction d'aide
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --password PASSWORD       Mot de passe SSH (défaut: SIRENS)"
    echo "  --reboot                  Redémarre les pupitres après mise à jour"
    echo "  --pupitres IPS            Met à jour uniquement les IPs spécifiées (séparées par des virgules)"
    echo "                            Les IPs peuvent être hors config (ex: 10.14.14.144)"
    echo "                            Exemple: --pupitres \"192.168.1.41,10.14.14.144\""
    echo "  --exclude IPS             Exclut les IPs spécifiées"
    echo "                            Exemple: --exclude \"192.168.1.47\""
    echo "  --interactive, -i         Mode interactif pour sélectionner les pupitres"
    echo "  --build-composesiren      Compile et package ComposeSiren sur un Raspberry sélectionné"
    echo "  --build-only              Compile uniquement ComposeSiren (implique --build-composesiren)"
    echo "  --deploy-composesiren     Déploie ComposeSiren sur les pupitres sélectionnés"
    echo "  --composesiren-deb PATH   Utilise ce package .deb pour l'installation (active le déploiement)"
    echo "  --skip-disable-auto-updates  Ne pas désactiver unattended-upgrades / apt timers / packagekit"
    echo "                            (par défaut: désactivation pour limiter les verrous apt sur les pupitres)"
    echo ""
    echo "  Variable d'environnement : COMPOSESIREN_BRANCH=main (défaut: master) pour aligner le dépôt ComposeSiren"
    echo "                            sur origin/<branche> lors du déploiement."
    echo "  --help, -h                Affiche cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0                                    # Tous les pupitres"
    echo "  $0 --pupitres \"192.168.1.41,192.168.1.42\"  # Pupitres spécifiques"
    echo "  $0 --exclude \"192.168.1.47\"                # Tous sauf un"
    echo "  $0 --interactive --reboot             # Mode interactif avec reboot"
}

# Gestion des arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --password)
      SSH_PASSWORD="$2"
      shift 2
      ;;
    --reboot)
      REBOOT_AFTER_UPDATE=true
      shift
      ;;
    --pupitres)
      SELECTED_PUPITRES="$2"
      shift 2
      ;;
    --exclude)
      EXCLUDED_PUPITRES="$2"
      shift 2
      ;;
    --interactive|-i)
      INTERACTIVE_MODE=true
      shift
      ;;
    --build-composesiren)
      BUILD_COMPOSESIREN=true
      shift
      ;;
    --build-only)
      BUILD_COMPOSESIREN=true
      BUILD_ONLY=true
      shift
      ;;
    --deploy-composesiren)
      DEPLOY_COMPOSESIREN=true
      shift
      ;;
    --composesiren-deb)
      COMPOSESIREN_DEB="$2"
      DEPLOY_COMPOSESIREN=true
      shift 2
      ;;
    --skip-disable-auto-updates)
      DISABLE_AUTO_UPDATES=false
      shift
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      echo "Option inconnue: $1"
      echo ""
      show_help
      exit 1
      ;;
  esac
done

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Gestion de l'interruption (Ctrl-C)
trap "echo; echo -e \"${RED}⛔ Opération interrompue par l'utilisateur.${NC}\"; exit 130" INT

# Fonction pour afficher le statut
print_status() {
    echo -e "${YELLOW}📤 $1${NC}"
}

# Fonction pour afficher le succès
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Fonction pour afficher l'erreur
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Fonction pour afficher l'info
print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Normaliser le chemin du package ComposeSiren si fourni
if [ -n "$COMPOSESIREN_DEB" ]; then
    if [ ! -f "$COMPOSESIREN_DEB" ]; then
        print_error "Package ComposeSiren introuvable: $COMPOSESIREN_DEB"
        exit 1
    fi
    COMPOSESIREN_DEB="$(cd "$(dirname "$COMPOSESIREN_DEB")" && pwd)/$(basename "$COMPOSESIREN_DEB")"
    print_info "Package ComposeSiren : $COMPOSESIREN_DEB"
fi

# Fonction pour sélectionner un builder (utilisé avec --build-composesiren)
select_builder() {
    echo -e "${BLUE}🛠️ Sélection du Raspberry builder :${NC}"
    echo ""
    local i=1
    for ip in "${PUPITRE_IPS[@]}"; do
        echo -e "  ${CYAN}[$i]${NC} $ip"
        ((i++))
    done
    echo ""
    echo -e "${YELLOW}Choisissez le builder (1 par défaut, Entrée pour continuer) :${NC}"
    read -r selection
    if [ -z "$selection" ]; then
        selection=1
    fi
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#PUPITRE_IPS[@]} ]; then
        print_info "Sélection invalide, utilisation du premier pupitre de la liste."
        selection=1
    fi
    BUILDER_IP=${PUPITRE_IPS[$((selection-1))]}
    echo ""
    print_info "Builder sélectionné : ${BUILDER_IP}"
}

# Mise à jour ComposeSiren sur un pupitre : fetch, branche de déploiement (origin/master par défaut),
# reset/clean pour éviter blocages checkout, sous-modules (JUCE). Contourne « no tracking information ».
compose_siren_git_update() {
    local host=$1
    local br="${COMPOSESIREN_BRANCH}"
    print_status "Mise à jour de ~/dev/src/ComposeSiren (origin/${br}, sous-modules)..."
    if ! sshpass -p"${SSH_PASSWORD}" ssh -o ConnectTimeout=60 ${SSH_BASE_OPTS} ${SERVER_USER}@${host} bash -s <<EOF
set -e
export GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no'
cd ~/dev/src/ComposeSiren
git reset --hard HEAD
git clean -fd
git fetch origin
if git rev-parse --verify "origin/${br}" >/dev/null 2>&1; then
  git checkout -B "${br}" "origin/${br}"
elif git rev-parse --verify origin/main >/dev/null 2>&1; then
  git checkout -B main origin/main
else
  echo "Branche origin/${br} ou origin/main introuvable" >&2
  exit 1
fi
git submodule sync --recursive 2>/dev/null || true
git submodule update --init --recursive
EOF
    then
        return 1
    fi
    return 0
}

# Fonction pour lancer la compilation/package ComposeSiren sur un Raspberry dédié
build_composesiren_on() {
    local host=$1
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🛠️ Build ComposeSiren sur: ${host}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    print_status "Test de connexion à ${host}..."
    if ! test_ssh_connection ${host}; then
        print_error "Impossible de se connecter à ${host} (timeout ou refus)"
        return 1
    fi
    print_success "Connexion builder établie"
    
    if ! compose_siren_git_update "${host}"; then
        print_error "Échec de la mise à jour ComposeSiren sur ${host}"
        return 1
    fi
    print_success "Repository ComposeSiren mis à jour"
    
    print_status "Compilation de c-siren~ (pd-lib-builder)..."
    if sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
        "cd ~/dev/src/ComposeSiren/Source/PureData/c-siren~ && make clean && make"; then
        print_success "Build c-siren~ terminé"
    else
        print_error "Échec de la compilation c-siren~ sur ${host}"
        return 1
    fi
    
    return 0
}

# Charger les IPs depuis SirenConsole/config.js
load_pupitre_ips() {
    local config_file="SirenConsole/config.js"
    
    if [ ! -f "$config_file" ]; then
        print_error "Fichier $config_file non trouvé"
        return 1
    fi
    
    # Extraire les IPs avec sed (compatible macOS)
    # On cherche les lignes "host:" dans la section pupitres (entre "pupitres: [" et le prochain "]")
    # Puis on supprime les doublons avec sort -u
    PUPITRE_IPS=($(sed -n '/pupitres:/,/^[[:space:]]*\]/p' "$config_file" | \
                   sed -n 's/.*host:[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p' | \
                   sort -u))
    
    if [ ${#PUPITRE_IPS[@]} -eq 0 ]; then
        print_error "Aucune IP trouvée dans $config_file"
        return 1
    fi
    
    return 0
}

# Fonction pour le mode interactif
interactive_select_pupitres() {
    echo -e "${BLUE}📋 Pupitres disponibles :${NC}"
    echo ""
    
    local i=1
    for ip in "${PUPITRE_IPS[@]}"; do
        echo -e "  ${CYAN}[$i]${NC} $ip"
        ((i++))
    done
    
    echo ""
    echo -e "${YELLOW}Sélectionnez les pupitres (exemples: 1,2,5 ou 1-3 ou 'all' pour tous):${NC}"
    read -r selection
    
    if [ "$selection" = "all" ] || [ "$selection" = "" ]; then
        return 0
    fi
    
    # Convertir la sélection en liste d'IPs
    local selected_ips=()
    IFS=',' read -ra SELECTIONS <<< "$selection"
    
    for sel in "${SELECTIONS[@]}"; do
        # Gérer les plages (ex: 1-3)
        if [[ $sel =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local start=${BASH_REMATCH[1]}
            local end=${BASH_REMATCH[2]}
            for ((j=start; j<=end; j++)); do
                if [ $j -le ${#PUPITRE_IPS[@]} ]; then
                    selected_ips+=("${PUPITRE_IPS[$((j-1))]}")
                fi
            done
        else
            # Sélection simple
            sel=$(echo "$sel" | xargs)  # Trim whitespace
            if [ $sel -le ${#PUPITRE_IPS[@]} ] && [ $sel -gt 0 ]; then
                selected_ips+=("${PUPITRE_IPS[$((sel-1))]}")
            fi
        fi
    done
    
    PUPITRE_IPS=("${selected_ips[@]}")
    
    if [ ${#PUPITRE_IPS[@]} -eq 0 ]; then
        print_error "Aucun pupitre sélectionné"
        exit 1
    fi
}

# Fonction pour filtrer les pupitres selon les options
filter_pupitres() {
    # Si des pupitres spécifiques sont demandés
    if [ -n "$SELECTED_PUPITRES" ]; then
        IFS=',' read -ra SELECTED_IPS <<< "$SELECTED_PUPITRES"
        local filtered=()
        for ip in "${SELECTED_IPS[@]}"; do
            ip=$(echo "$ip" | xargs)  # Trim whitespace
            [ -z "$ip" ] && continue
            if [[ " ${PUPITRE_IPS[*]} " =~ " ${ip} " ]]; then
                filtered+=("$ip")
            else
                # IP non présente dans config.js : on l'accepte quand même (pupitre hors config)
                if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    print_info "IP $ip non dans la config, utilisation directe"
                    filtered+=("$ip")
                else
                    print_error "IP invalide: $ip"
                fi
            fi
        done
        PUPITRE_IPS=("${filtered[@]}")
    fi
    
    # Si des pupitres sont exclus
    if [ -n "$EXCLUDED_PUPITRES" ]; then
        IFS=',' read -ra EXCLUDED_IPS <<< "$EXCLUDED_PUPITRES"
        local filtered=()
        for ip in "${PUPITRE_IPS[@]}"; do
            local exclude=false
            for excluded_ip in "${EXCLUDED_IPS[@]}"; do
                excluded_ip=$(echo "$excluded_ip" | xargs)  # Trim whitespace
                if [ "$ip" = "$excluded_ip" ]; then
                    exclude=true
                    break
                fi
            done
            if [ "$exclude" = false ]; then
                filtered+=("$ip")
            fi
        done
        PUPITRE_IPS=("${filtered[@]}")
    fi
    
    if [ ${#PUPITRE_IPS[@]} -eq 0 ]; then
        print_error "Aucun pupitre à traiter après filtrage"
        exit 1
    fi
}

echo -e "${BLUE}🚀 Mise à jour de tous les pupitres${NC}"
echo ""

# Vérifier que nous sommes dans le bon répertoire
if [ ! -d "SirenePupitre/webfiles" ]; then
    echo -e "${RED}❌ Erreur: SirenePupitre/webfiles non trouvé. Exécutez ce script depuis la racine du projet mecaviv-qml-ui.${NC}"
    exit 1
fi

# Vérifier que sshpass est installé
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}❌ Erreur: sshpass n'est pas installé.${NC}"
    echo -e "${YELLOW}💡 Installation: brew install hudochenkov/sshpass/sshpass (macOS)${NC}"
    exit 1
fi

# Charger les IPs des pupitres depuis config.js
print_status "Chargement des IPs depuis SirenConsole/config.js..."
if ! load_pupitre_ips; then
    echo -e "${RED}❌ Erreur lors du chargement des IPs${NC}"
    exit 1
fi

# Appliquer les filtres (--pupitres ou --exclude)
filter_pupitres

# Mode interactif si demandé
if [ "$INTERACTIVE_MODE" = true ]; then
    interactive_select_pupitres
fi

echo -e "${GREEN}✅ ${#PUPITRE_IPS[@]} pupitre(s) sélectionné(s):${NC}"
for ip in "${PUPITRE_IPS[@]}"; do
    echo "   • $ip"
done
echo ""

# Étape optionnelle de build ComposeSiren
if [ "$BUILD_COMPOSESIREN" = true ]; then
    if [ ${#PUPITRE_IPS[@]} -eq 0 ]; then
        print_error "Aucun pupitre disponible pour sélectionner un builder"
        exit 1
    fi
    
    select_builder
    if ! build_composesiren_on "$BUILDER_IP"; then
        print_error "Échec de la phase build ComposeSiren"
        exit 1
    fi
    
    echo ""
    print_success "Phase build ComposeSiren terminée avec succès"
    echo ""
    
    if [ "$BUILD_ONLY" = true ]; then
        print_info "Mode build-only demandé : fin du script après la compilation."
        exit 0
    elif [ "$DEPLOY_COMPOSESIREN" != true ]; then
        print_info "Build réalisé. Ajoutez --deploy-composesiren ou --composesiren-deb pour installer ComposeSiren."
    fi
fi

# Fonction pour tester la connexion SSH
test_ssh_connection() {
    local host=$1
    sshpass -p"${SSH_PASSWORD}" ssh -o ConnectTimeout=5 ${SSH_BASE_OPTS} \
        ${SERVER_USER}@${host} "echo 'OK'" &>/dev/null
    return $?
}

# Désactive unattended-upgrades, timers apt et PackageKit sur le pupitre (évite verrous apt / packagekitd).
# Best-effort : les unités absentes sont ignorées. Nécessite sudo sans mot de passe sur le pupitre.
disable_auto_updates_remote() {
    local host=$1
    print_status "Désactivation des mises à jour automatiques sur ${host}..."
    if sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} 'bash -s' <<'REMOTE'
sudo systemctl stop unattended-upgrades 2>/dev/null || true
sudo systemctl disable unattended-upgrades 2>/dev/null || true
sudo systemctl stop apt-daily.timer 2>/dev/null || true
sudo systemctl stop apt-daily-upgrade.timer 2>/dev/null || true
sudo systemctl disable apt-daily.timer 2>/dev/null || true
sudo systemctl disable apt-daily-upgrade.timer 2>/dev/null || true
sudo systemctl stop packagekit 2>/dev/null || true
sudo systemctl disable packagekit 2>/dev/null || true
sudo systemctl mask packagekit 2>/dev/null || true
sleep 2
REMOTE
    then
        print_success "Mises à jour auto désactivées (unattended-upgrades, timers apt, packagekit)"
    else
        print_info "Désactivation auto-update non appliquée sur ${host} (SSH) — poursuite du script"
    fi
}

# Fonction pour mettre à jour un pupitre
update_pupitre() {
    local host=$1
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🎹 Mise à jour du pupitre: ${host}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Test de connexion
    print_status "Test de connexion à ${host}..."
    if ! test_ssh_connection ${host}; then
        print_error "Impossible de se connecter à ${host} (timeout ou refus)"
        return 1
    fi
    print_success "Connexion établie"

    if [ "$DISABLE_AUTO_UPDATES" = true ]; then
        disable_auto_updates_remote "${host}"
    fi
    
    # 1. Git pull puredata-abstractions
    print_status "Mise à jour de ~/dev/src/mecaviv/puredata-abstractions..."
    if sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
        "cd ~/dev/src/mecaviv/puredata-abstractions && \
         GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no' ${GIT_PULL}"; then
        print_success "puredata-abstractions mis à jour"
    else
        print_error "Échec du git pull puredata-abstractions sur ${host}"
        return 1
    fi
    
    # 2. Git pull compositions (fichiers MIDI)
    print_status "Mise à jour de ~/dev/src/mecaviv/compositions..."
    if sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
        "cd ~/dev/src/mecaviv/compositions && \
         GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no' ${GIT_PULL}"; then
        print_success "compositions mis à jour"
    else
        print_error "Échec du git pull compositions sur ${host}"
        return 1
    fi
    
    # 3. ComposeSiren : fetch + branche origin/master + sous-modules (évite branche locale sans tracking)
    if ! compose_siren_git_update "${host}"; then
        print_error "Échec de la mise à jour ComposeSiren sur ${host}"
        return 1
    fi
    print_success "ComposeSiren mis à jour"

    if [ "$DEPLOY_COMPOSESIREN" = true ]; then
        # Installation ComposeSiren via package
        if [ -n "$COMPOSESIREN_DEB" ]; then
            local remote_deb="/tmp/$(basename "$COMPOSESIREN_DEB")"
            
            print_status "Transfert du package ComposeSiren..."
            if ! sshpass -p"${SSH_PASSWORD}" scp ${SSH_BASE_OPTS} "$COMPOSESIREN_DEB" ${SERVER_USER}@${host}:"$remote_deb"; then
                print_error "Échec du transfert du package ComposeSiren sur ${host}"
                return 1
            fi
            print_success "Package transféré"
            
            print_status "Installation de ComposeSiren depuis le package..."
            local install_cmd="sudo dpkg -i '$remote_deb' || (sudo apt-get install -f -y && sudo dpkg -i '$remote_deb')"
            if ! sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} "$install_cmd"; then
                print_error "Échec de l'installation ComposeSiren sur ${host}"
                return 1
            fi
            print_success "ComposeSiren installé via dpkg"
            
            print_status "Nettoyage du package temporaire..."
            sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} "rm -f '$remote_deb'" &>/dev/null || true
        else
            print_status "Compilation et déploiement de c-siren~ sur ${host}..."
            if sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
                "cd ~/dev/src/ComposeSiren/Source/PureData/c-siren~ && make clean && make && \
                 mkdir -p ~/dev/src/critapec-pd-externals && \
                 cp c-siren~.pd_linux ~/dev/src/critapec-pd-externals/ && \
                 cp c-siren~-help.pd ~/dev/src/critapec-pd-externals/ 2>/dev/null; true"; then
                print_success "c-siren~ compilé et déployé"
            else
                print_error "Échec de la compilation/déploiement c-siren~ sur ${host}"
                return 1
            fi
        fi
    else
        print_info "ComposeSiren non déployé (ajoutez --deploy-composesiren pour l'activer)."
    fi
    
    # 4. Git pull mecaviv-qml-ui (commenté - non utilisé)
#    print_status "Mise à jour de ~/dev/src/mecaviv-qml-ui..."
#    if sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
#        "cd ~/dev/src/mecaviv-qml-ui && \
#         GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no' git pull || \
#         (git checkout -- SirenePupitre/webfiles/* && git pull)"; then
#        print_success "mecaviv-qml-ui mis à jour"
#    else
#        print_error "Échec du git pull mecaviv-qml-ui sur ${host}"
#        return 1
#    fi
    
    # 5. Préparation GPIO pour les externals critapec
    print_status "Vérification de libgpiod..."
    if ! sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
        "dpkg -s libgpiod2 >/dev/null 2>&1"; then
        print_info "libgpiod2 absent, installation en cours..."
    fi
    if ! sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
        "dpkg -s libgpiod-dev >/dev/null 2>&1"; then
        print_info "libgpiod-dev absent, installation en cours..."
    fi
    if sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
        "sudo apt-get update && sudo apt-get install -y libgpiod2 libgpiod-dev"; then
        print_success "libgpiod/libgpiod-dev installés"
    else
        print_error "Impossible d'installer libgpiod/libgpiod-dev sur ${host}"
        return 1
    fi

    print_status "Ajout de ${SERVER_USER} au groupe gpio..."
    if ! sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
        "getent group gpio >/dev/null 2>&1 || sudo groupadd gpio"; then
        print_error "Impossible de créer/vérifier le groupe gpio sur ${host}"
        return 1
    fi
    if sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
        "sudo usermod -aG gpio ${SERVER_USER}"; then
        print_success "${SERVER_USER} appartient au groupe gpio (reboot nécessaire pour prise en compte)"
    else
        print_error "Impossible d'ajouter ${SERVER_USER} au groupe gpio sur ${host}"
        return 1
    fi

    print_status "Configuration des pull-ups GPIO (15/22/24)..."
    if ! sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
        "command -v pinctrl >/dev/null 2>&1"; then
        print_error "pinctrl introuvable sur ${host} (Pi 5 requis)."
        return 1
    fi
    if sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
        "sudo pinctrl set 15 pu && sudo pinctrl set 22 pu && sudo pinctrl set 24 pu"; then
        print_success "Pull-ups configurés sur 15 (switch), 22 (A), 24 (B)"
    else
        print_error "Échec de la configuration pinctrl sur ${host}"
        return 1
    fi

    print_status "Vérification des externals critapec..."
    
    # Vérifier si c'est un dépôt Git valide, sinon supprimer et cloner
    if sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
        "[ -d ~/dev/src/critapec-pd-externals/.git ]"; then
        # C'est un dépôt Git valide, faire un pull
        print_status "Mise à jour de critapec-pd-externals..."
        if ! sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
            "cd ~/dev/src/critapec-pd-externals && \
             GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no' ${GIT_PULL}"; then
            print_error "Échec du git pull critapec-pd-externals sur ${host}"
            return 1
        fi
        print_success "critapec-pd-externals mis à jour"
    else
        # Le répertoire existe mais n'est pas un dépôt Git valide, ou n'existe pas
        if sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
            "[ -d ~/dev/src/critapec-pd-externals ]"; then
            print_status "Suppression de l'ancien répertoire critapec-pd-externals..."
            sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
                "rm -rf ~/dev/src/critapec-pd-externals"
        fi
        print_status "Clonage de critapec-pd-externals..."
        if ! sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
            "mkdir -p ~/dev/src && cd ~/dev/src && \
             GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no' git clone ${CRITAPEC_REPO_URL} critapec-pd-externals"; then
            print_error "Échec du clone critapec-pd-externals sur ${host}"
            return 1
        fi
        print_success "critapec-pd-externals cloné"
    fi
    
    # Compilation et installation de c-siren~ (external PD depuis ComposeSiren)
    local CSIREN_SRC="~/dev/src/ComposeSiren/Source/PureData/c-siren~"
    local CSIREN_BIN="c-siren~.pd_linux"
    local CRITAPEC_DIR="~/pd-externals"

    print_status "Vérification de la synchronisation de c-siren~..."
    NEEDS_BUILD=$(sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
        "CSRC=${CSIREN_SRC}; CBIN=${CRITAPEC_DIR}/${CSIREN_BIN}; \
         if [ ! -d \"\$CSRC\" ]; then echo 'MISSING'; exit 0; fi; \
         if [ ! -f \"\$CBIN\" ]; then echo 'REBUILD'; exit 0; fi; \
         src_time=\$(stat -c '%Y' \"\$CSRC\"/src/*.cpp \"\$CSRC\"/src/*.h \"\$CSRC\"/Makefile 2>/dev/null | sort -n | tail -1); \
         bin_time=\$(stat -c '%Y' \"\$CBIN\" 2>/dev/null); \
         if [ -z \"\$src_time\" ]; then echo 'REBUILD'; \
         elif [ \"\$src_time\" -gt \"\$bin_time\" ]; then echo 'REBUILD'; \
         else echo 'OK'; fi")

    if [ "$NEEDS_BUILD" = "MISSING" ]; then
        print_error "Répertoire c-siren~ introuvable dans ComposeSiren (Source/PureData/c-siren~)"
        print_info "Vérifiez que le dépôt ComposeSiren est à jour sur ${host}"
        return 1
    fi

    if [ "$NEEDS_BUILD" = "REBUILD" ]; then
        print_status "Compilation de c-siren~ (pd-lib-builder)..."

        local build_output
        build_output=$(sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
            "cd ${CSIREN_SRC} && make clean && make" 2>&1)
        local build_status=$?

        if [ $build_status -ne 0 ]; then
            # Tenter d'installer les dépendances manquantes puis réessayer
            if echo "$build_output" | grep -qE "fatal error:.*m_pd\.h|cannot find -lpd"; then
                print_info "Headers Pure Data manquants, installation de puredata-dev..."
                sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
                    "sudo apt-get update && sudo apt-get install -y puredata-dev" 2>&1
                build_output=$(sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
                    "cd ${CSIREN_SRC} && make clean && make" 2>&1)
                build_status=$?
            fi
        fi

        if [ $build_status -ne 0 ]; then
            print_error "Échec de la compilation de c-siren~ sur ${host}"
            echo -e "${YELLOW}Sortie de compilation:${NC}"
            echo "$build_output" | tail -30
            return 1
        fi
        print_success "c-siren~ compilé"

        print_status "Installation de c-siren~ dans critapec-pd-externals..."
        if sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
            "mkdir -p ${CRITAPEC_DIR} && \
             cp ${CSIREN_SRC}/${CSIREN_BIN} ${CRITAPEC_DIR}/ && \
             cp ${CSIREN_SRC}/c-siren~-help.pd ${CRITAPEC_DIR}/ 2>/dev/null; true"; then
            print_success "c-siren~ et help patch installés"
        else
            print_error "Échec de la copie de c-siren~ vers critapec-pd-externals sur ${host}"
            return 1
        fi

        if ! sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
            "test -f ${CRITAPEC_DIR}/${CSIREN_BIN}"; then
            print_error "c-siren~.pd_linux introuvable après installation"
            return 1
        fi
    else
        print_success "c-siren~ déjà à jour"
    fi
    
    # 6. Rsync webfiles
    print_status "Rsync de SirenePupitre/webfiles..."
    if sshpass -p"${SSH_PASSWORD}" rsync -avz -e "ssh ${SSH_BASE_OPTS}" \
        SirenePupitre/webfiles/ ${SERVER_USER}@${host}:~/dev/src/mecaviv-qml-ui/SirenePupitre/webfiles/; then
        print_success "webfiles synchronisé"
    else
        print_error "Échec du rsync webfiles sur ${host}"
        return 1
    fi
    
    # 7. Rsync scripts (start-raspberry.sh, etc.)
    print_status "Rsync de SirenePupitre/scripts..."
    if sshpass -p"${SSH_PASSWORD}" rsync -avz -e "ssh ${SSH_BASE_OPTS}" \
        SirenePupitre/scripts/ ${SERVER_USER}@${host}:~/dev/src/mecaviv-qml-ui/SirenePupitre/scripts/; then
        print_success "scripts synchronisés"
    else
        print_error "Échec du rsync scripts sur ${host}"
        return 1
    fi
    
    # 8. Reboot si demandé
    if [ "$REBOOT_AFTER_UPDATE" = true ]; then
        print_status "Redémarrage du pupitre ${host}..."
        if sshpass -p"${SSH_PASSWORD}" ssh ${SSH_BASE_OPTS} ${SERVER_USER}@${host} \
            "sudo reboot" &>/dev/null; then
            print_success "Pupitre ${host} redémarré (il sera de nouveau opérationnel dans 1-2 minutes)"
        else
            print_error "Échec du redémarrage sur ${host}"
            return 1
        fi
    fi
    
    print_success "Pupitre ${host} mis à jour avec succès !"
    return 0
}

# Compteurs
total=${#PUPITRE_IPS[@]}
success=0
failed=0
failed_ips=()

# Mettre à jour chaque pupitre
for ip in "${PUPITRE_IPS[@]}"; do
    if update_pupitre ${ip}; then
        ((success++))
    else
        ((failed++))
        failed_ips+=("${ip}")
    fi
done

# Résumé final
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 Résumé de la mise à jour${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Total: ${total} pupitres"
echo -e "${GREEN}Réussis: ${success}${NC}"
if [ ${failed} -gt 0 ]; then
    echo -e "${RED}Échoués: ${failed}${NC}"
    echo -e "${RED}IPs en échec:${NC}"
    for ip in "${failed_ips[@]}"; do
        echo -e "  • ${ip}"
    done
else
    echo -e "${GREEN}Aucun échec ✨${NC}"
fi

if [ "$REBOOT_AFTER_UPDATE" = true ]; then
    echo -e "${YELLOW}🔄 Les pupitres ont été redémarrés (délai de 1-2 minutes)${NC}"
fi
echo ""

if [ ${failed} -eq 0 ]; then
    if [ "$REBOOT_AFTER_UPDATE" = true ]; then
        echo -e "${GREEN}🎉 Tous les pupitres ont été mis à jour et redémarrés avec succès !${NC}"
    else
        echo -e "${GREEN}🎉 Tous les pupitres ont été mis à jour avec succès !${NC}"
    fi
    exit 0
else
    echo -e "${YELLOW}⚠️  Certains pupitres n'ont pas pu être mis à jour.${NC}"
    exit 1
fi

