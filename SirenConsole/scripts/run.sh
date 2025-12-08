#!/bin/bash

# Script simple pour SirenConsole
# Usage: ./scripts/run.sh

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Tuer les serveurs existants
print "🛑 Arrêt des serveurs existants..."
PIDS=$(ps aux | grep "node server.js" | grep -v grep | awk '{print $2}')
if [ -n "$PIDS" ]; then
    for PID in $PIDS; do
        kill $PID 2>/dev/null || true
    done
    sleep 1
fi
success "Serveurs arrêtés"

# 2. Build
print "🔨 Build WebAssembly..."
./scripts/build.sh web
success "Build terminé"

# 3. Lancer le serveur
print "🚀 Démarrage du serveur..."
cd webfiles
node server.js &
SERVER_PID=$!
cd ..

# Attendre que le serveur démarre
sleep 3

# Vérifier que le serveur répond (avec -k pour ignorer le certificat auto-signé)
if curl -s -k https://localhost:8001 >/dev/null; then
    success "Serveur démarré sur https://localhost:8001"
    
    # 4. Ouvrir Chrome avec les logs
    print "🌐 Ouverture de Chrome avec les logs..."
    if [ -d "/Applications/Google Chrome.app" ]; then
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --auto-open-devtools-for-tabs --disable-web-security --user-data-dir=/tmp/sirenconsole-dev https://localhost:8001 &
    else
        warning "Chrome non trouvé, ouverture manuelle requise"
        print "Ouvrez https://localhost:8001 dans Chrome et appuyez sur F12"
    fi
    
    success "Application ouverte dans Chrome"
    print "Consultez la console du navigateur pour voir les logs"
    print "Appuyez sur Entrée pour arrêter le serveur..."
    read -r
    
    # Arrêter le serveur
    print "Arrêt du serveur..."
    kill $SERVER_PID 2>/dev/null || true
    success "Serveur arrêté"
    
else
    error "Le serveur n'a pas démarré correctement"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi
