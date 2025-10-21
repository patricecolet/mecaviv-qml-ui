#!/bin/bash

# Script simple pour lancer le serveur Node.js de SirenConsole
# Usage: ./scripts/start-server.sh

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

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier qu'on est dans le bon répertoire
if [ ! -f "CMakeLists.txt" ]; then
    error "Ce script doit être exécuté depuis le répertoire SirenConsole/"
    exit 1
fi

# Vérifier que node_modules existe
if [ ! -d "webfiles/node_modules" ]; then
    print "📦 Installation des dépendances Node.js..."
    cd webfiles
    npm install
    cd ..
    success "Dépendances installées"
fi

# Vérifier si un serveur est déjà lancé sur le port 8001
if lsof -i :8001 >/dev/null 2>&1; then
    error "Un serveur est déjà lancé sur le port 8001"
    print "Arrêtez-le avec: lsof -ti :8001 | xargs kill"
    exit 1
fi

# Lancer le serveur
print "🚀 Démarrage du serveur SirenConsole sur http://localhost:8001"
print "📊 Console de contrôle disponible sur http://localhost:8001/appSirenConsole.html"
print ""
print "Appuyez sur Ctrl+C pour arrêter le serveur"
print ""

cd webfiles
node server.js


