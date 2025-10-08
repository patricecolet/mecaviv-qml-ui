#!/bin/bash

# Script de développement pour SirenePupitre
# Usage: ./scripts/dev.sh [web|desktop]

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

# Fonction d'aide
show_help() {
    echo "Script de développement pour SirenePupitre"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  web         Build WebAssembly + démarre le serveur + ouvre Chrome"
    echo "  server      Démarre seulement le serveur"
    echo "  help        Afficher cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0 web"
    echo "  $0 server"
}

# Fonction pour arrêter les processus
cleanup() {
    print_info "Arrêt des processus..."
    
    # Arrêter le serveur Node.js
    if [ ! -z "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null || true
        print_info "Serveur arrêté"
    fi
    
    # Arrêter l'application desktop
    if [ ! -z "$APP_PID" ]; then
        kill $APP_PID 2>/dev/null || true
        print_info "Application arrêtée"
    fi
    
    exit 0
}

# Capturer Ctrl+C
trap cleanup SIGINT SIGTERM

# Mode de développement Web
dev_web() {
    print_info "=== Mode développement Web ==="
    
    # Build WebAssembly
    print_info "Build WebAssembly..."
    ./scripts/build.sh web
    
    # Démarrer le serveur
    print_info "Démarrage du serveur..."
    ./scripts/start-server.sh &
    SERVER_PID=$!
    
    # Attendre que le serveur démarre
    sleep 3
    
    # Ouvrir Chrome
    print_info "Ouverture de Chrome..."
    if command -v google-chrome &> /dev/null; then
        google-chrome --new-window http://localhost:8000 &
    elif command -v chromium-browser &> /dev/null; then
        chromium-browser --new-window http://localhost:8000 &
    elif command -v open &> /dev/null; then
        # macOS
        open -a "Google Chrome" http://localhost:8000
    else
        print_warning "Chrome non trouvé, ouvrez manuellement: http://localhost:8000"
    fi
    
    print_success "Environnement de développement web prêt!"
    print_info "Serveur: http://localhost:8000"
    print_info "Appuyez sur Ctrl+C pour arrêter"
    
    # Attendre
    wait $SERVER_PID
}

# Mode serveur seulement
dev_server() {
    print_info "=== Mode serveur seulement ==="
    
    # Démarrer le serveur
    print_info "Démarrage du serveur..."
    ./scripts/start-server.sh &
    SERVER_PID=$!
    
    # Attendre que le serveur démarre
    sleep 3
    
    # Ouvrir Chrome
    print_info "Ouverture de Chrome..."
    if command -v google-chrome &> /dev/null; then
        google-chrome --new-window http://localhost:8000 &
    elif command -v chromium-browser &> /dev/null; then
        chromium-browser --new-window http://localhost:8000 &
    elif command -v open &> /dev/null; then
        # macOS
        open -a "Google Chrome" http://localhost:8000
    else
        print_warning "Chrome non trouvé, ouvrez manuellement: http://localhost:8000"
    fi
    
    print_success "Serveur prêt!"
    print_info "Serveur: http://localhost:8000"
    print_info "Appuyez sur Ctrl+C pour arrêter"
    
    # Attendre
    wait $SERVER_PID
}

# Script principal
main() {
    print_info "=== Développement SirenePupitre ==="
    
    # Vérifier les arguments
    if [ $# -eq 0 ]; then
        print_error "Aucun mode spécifié"
        show_help
        exit 1
    fi
    
    case "$1" in
        "web")
            dev_web
            ;;
        "server")
            dev_server
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
}

# Exécuter le script principal
main "$@"
