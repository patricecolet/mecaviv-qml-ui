#!/bin/bash

# Script de synchronisation vers le serveur distant
# Usage: ./scripts/sync-to-server.sh [--build] [--restart-client] [--ip IP] [--password PASSWORD]
#        --build           : Construit le projet avant la synchronisation (scripts/build.sh)
#        --restart-client  : Relance le client sur le Raspberry Pi après synchronisation
#        --ip IP           : Adresse IP du serveur (défaut: 192.168.1.46)
#        --password PASS   : Mot de passe SSH (défaut: SIRENS)

set -e  # Arrêter en cas d'erreur

# Vérifier les arguments
RESTART_CLIENT=false
DO_BUILD=false
SERVER_HOST="192.168.1.46"
SSH_PASSWORD="SIRENS"

while [[ $# -gt 0 ]]; do
  case $1 in
    --restart-client)
      RESTART_CLIENT=true
      shift
      ;;
    --build)
      DO_BUILD=true
      shift
      ;;
    --ip)
      SERVER_HOST="$2"
      shift 2
      ;;
    --password)
      SSH_PASSWORD="$2"
      shift 2
      ;;
    *)
      echo "Option inconnue: $1"
      echo "Usage: $0 [--build] [--restart-client] [--ip IP] [--password PASSWORD]"
      exit 1
      ;;
  esac
done

# Gestion de l'interruption (Ctrl-C)
trap "echo; echo -e \"${RED}⛔ Opération interrompue par l'utilisateur.${NC}\"; exit 130" INT

# Configuration
SERVER_USER="sirenateur"
SIRENE_PROJECT_PATH="/home/sirenateur/dev/src/mecaviv/patko-scratchpad/qtQmlSockets/SirenePupitre"
VOLANT_PROJECT_PATH="/home/sirenateur/dev/src/mecaviv/patko-scratchpad/volant"
CRITAPEC_LOCAL_PATH="${HOME}/dev/src/critapec-pd-externals"
CRITAPEC_REMOTE_PATH="/home/sirenateur/pd-externals/critapec"

# Commande rsync (comme dans le script qui fonctionne)
_COPY_COMMAND="rsync -avuPe ssh"


# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Synchronisation vers le serveur ${SERVER_HOST}${NC}"
echo ""

# Vérifier que nous sommes dans le bon répertoire
if [ ! -f "config.js" ]; then
    echo -e "${RED}❌ Erreur: config.js non trouvé. Exécutez ce script depuis la racine du projet SirenePupitre.${NC}"
    exit 1
fi

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

# 0. Build si demandé
if [ "$DO_BUILD" = true ]; then
    print_status 'Construction du projet (scripts/build.sh web)...'
    if ./scripts/build.sh web; then
        print_success "Build terminé"
    else
        print_error "Échec du build"
        exit 1
    fi
fi

# 1. Synchroniser config.js
print_status "Synchronisation de config.js..."
sshpass -p${SSH_PASSWORD} $_COPY_COMMAND config.js ${SERVER_USER}@${SERVER_HOST}:${SIRENE_PROJECT_PATH}/config.js
print_success "config.js synchronisé"

# 2. Synchroniser webfiles
print_status "Synchronisation du dossier webfiles..."
sshpass -p${SSH_PASSWORD} $_COPY_COMMAND webfiles/ ${SERVER_USER}@${SERVER_HOST}:${SIRENE_PROJECT_PATH}/webfiles/
print_success "webfiles synchronisé"

# 3. Synchroniser volant/config.json
print_status "Synchronisation de volant/config.json..."
sshpass -p${SSH_PASSWORD} $_COPY_COMMAND ../../volant/config.json ${SERVER_USER}@${SERVER_HOST}:${VOLANT_PROJECT_PATH}/config.json
print_success "volant/config.json synchronisé"

# 4. Synchroniser le script de relancement
print_status "Synchronisation du script de relancement..."
sshpass -p${SSH_PASSWORD} $_COPY_COMMAND scripts/restart-servers.sh ${SERVER_USER}@${SERVER_HOST}:${SIRENE_PROJECT_PATH}/restart-servers.sh
print_success "Script de relancement synchronisé"

# 5. Synchroniser le script de démarrage Raspberry Pi
print_status "Synchronisation de start-raspberry.sh..."
sshpass -p${SSH_PASSWORD} $_COPY_COMMAND scripts/start-raspberry.sh ${SERVER_USER}@${SERVER_HOST}:${SIRENE_PROJECT_PATH}/start-raspberry.sh
print_success "start-raspberry.sh synchronisé"

# 6. Synchroniser l'external PureData c-siren~ (critapec)
print_status "Synchronisation de l'external c-siren~ (critapec)..."
if [ -d "$CRITAPEC_LOCAL_PATH" ]; then
    TMP_CRITAPEC_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_CRITAPEC_DIR"; echo; echo -e "${RED}⛔ Opération interrompue par l'utilisateur.${NC}"; exit 130' INT

    # Copier uniquement les artefacts c-siren~ (binaire + help)
    find "$CRITAPEC_LOCAL_PATH" -type f \( \
        -name "c-siren~*.pd_linux" -o \
        -name "c-siren~*.so" -o \
        -name "c-siren~-help.pd" \
    \) -exec cp {} "$TMP_CRITAPEC_DIR"/ \;

    if ls "$TMP_CRITAPEC_DIR"/* >/dev/null 2>&1; then
        sshpass -p${SSH_PASSWORD} ssh ${SERVER_USER}@${SERVER_HOST} "mkdir -p ${CRITAPEC_REMOTE_PATH}"
        sshpass -p${SSH_PASSWORD} $_COPY_COMMAND "$TMP_CRITAPEC_DIR"/ ${SERVER_USER}@${SERVER_HOST}:${CRITAPEC_REMOTE_PATH}/
        print_success "External c-siren~ synchronisé vers ${CRITAPEC_REMOTE_PATH}"
    else
        print_error "Aucun artefact c-siren~ trouvé dans ${CRITAPEC_LOCAL_PATH}"
        rm -rf "$TMP_CRITAPEC_DIR"
        exit 1
    fi

    rm -rf "$TMP_CRITAPEC_DIR"
else
    print_error "Répertoire critapec introuvable: ${CRITAPEC_LOCAL_PATH}"
    exit 1
fi

echo ""
echo -e "${GREEN} Synchronisation terminée avec succès !${NC}"
echo -e "${BLUE} Fichiers synchronisés :${NC}"
echo "   • config.js"
echo "   • webfiles/"
echo "   • volant/config.json"
echo "   • restart-servers.sh"
echo "   • start-raspberry.sh"
echo "   • c-siren~ (critapec external)"

# 4. Relancer le client si demandé
if [ "$RESTART_CLIENT" = true ]; then
    echo ""
    print_status "Relancement du client sur le Raspberry Pi..."
    
    # Utiliser le script de relancement sur le Raspberry Pi
    print_status "Relancement des serveurs via script local..."
    sshpass -p${SSH_PASSWORD} ssh ${SERVER_USER}@${SERVER_HOST} "bash ${SIRENE_PROJECT_PATH}/restart-servers.sh"
    print_success "Serveurs relancés avec succès"
fi

echo ""
if [ "$RESTART_CLIENT" = true ]; then
    echo -e "${GREEN}🚀 Synchronisation et relancement terminés !${NC}"
else
    echo -e "${GREEN}🎉 Synchronisation terminée avec succès !${NC}"
fi
echo -e "${BLUE}📋 Fichiers synchronisés :${NC}"
echo "   • config.js"
echo "   • webfiles/"
echo "   • volant/config.json"
echo ""
echo -e "${YELLOW}💡 Usage:${NC}"
echo "   • Synchronisation seule: ./scripts/sync-to-server.sh"
echo "   • Avec relancement: ./scripts/sync-to-server.sh --restart-client"
echo "   • Avec IP personnalisée: ./scripts/sync-to-server.sh --ip 192.168.1.100"
echo "   • Avec mot de passe personnalisé: ./scripts/sync-to-server.sh --password MONPASSWORD"
