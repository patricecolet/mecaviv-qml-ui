#!/bin/bash

# Script pour démarrer le serveur Node.js
# Usage: ./scripts/start-server.sh [port]

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonction pour afficher les messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Port par défaut
PORT=${1:-8000}

# Fonction d'aide
show_help() {
    echo "Script pour démarrer le serveur Node.js"
    echo ""
    echo "Usage: $0 [PORT]"
    echo ""
    echo "Arguments:"
    echo "  PORT        Port du serveur (défaut: 8000)"
    echo ""
    echo "Exemples:"
    echo "  $0"
    echo "  $0 8080"
}

# Vérifier si Node.js est installé
check_node() {
    if ! command -v node &> /dev/null; then
        print_error "Node.js n'est pas installé"
        print_info "Installez Node.js: https://nodejs.org/"
        exit 1
    fi
    
    print_success "Node.js trouvé: $(node --version)"
}

# Vérifier si le serveur existe
check_server() {
    if [ ! -f "webfiles/server.js" ]; then
        print_error "Fichier webfiles/server.js non trouvé"
        print_info "Assurez-vous d'être dans le répertoire racine du projet"
        exit 1
    fi
    
    print_success "Serveur trouvé: webfiles/server.js"
}

# Démarrer le serveur
start_server() {
    print_info "Démarrage du serveur sur le port $PORT..."
    
    cd webfiles
    
    # Vérifier si le port est déjà utilisé
    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_warning "Le port $PORT est déjà utilisé"
        print_info "Arrêt du processus existant..."
        lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    # Démarrer le serveur
    print_info "Lancement de node server.js..."
    node server.js &
    SERVER_PID=$!
    
    # Attendre que le serveur démarre
    sleep 3
    
    # Vérifier si le serveur fonctionne
    if curl -s http://localhost:$PORT > /dev/null 2>&1; then
        print_success "Serveur démarré avec succès sur http://localhost:$PORT"
        print_info "PID: $SERVER_PID"
        print_info "Pour arrêter: kill $SERVER_PID"
    else
        print_error "Le serveur n'a pas démarré correctement"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
    
    cd ..
}

# Script principal
main() {
    print_info "=== Démarrage du serveur SirenePupitre ==="
    
    # Vérifier les arguments
    if [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
        exit 0
    fi
    
    check_node
    check_server
    start_server
    
    print_success "Serveur prêt!"
    print_info "Ouvrez http://localhost:$PORT dans votre navigateur"
}

# Exécuter le script principal
main "$@"
