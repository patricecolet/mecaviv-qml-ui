#!/bin/bash

# Script de développement avec logs du navigateur pour SirenePupitre
# Usage: ./scripts/dev-with-logs.sh [build|serve|both]

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo "Script de développement avec logs du navigateur pour SirenePupitre"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  build       Build WebAssembly uniquement"
    echo "  serve       Démarrer le serveur + navigateur avec logs"
    echo "  both        Build + Serveur + Navigateur (défaut)"
    echo "  kill        Tuer tous les serveurs"
    echo "  help        Afficher cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0 build"
    echo "  $0 serve"
    echo "  $0 both"
    echo "  $0 kill"
}

# Fonction pour tuer les serveurs
kill_servers() {
    print_info "🛑 Arrêt des serveurs existants..."
    
    # Trouver tous les processus node server.js
    PIDS=$(ps aux | grep "node server.js" | grep -v grep | awk '{print $2}')
    
    if [ -z "$PIDS" ]; then
        print_warning "Aucun serveur Node.js trouvé"
    else
        print_info "Processus trouvés: $PIDS"
        
        for PID in $PIDS; do
            print_info "Arrêt du processus $PID..."
            kill $PID 2>/dev/null || print_warning "Impossible d'arrêter le processus $PID"
        done
        
        # Attendre un peu pour que les processus se terminent
        sleep 1
        
        # Vérifier s'il reste des processus
        REMAINING=$(ps aux | grep "node server.js" | grep -v grep | awk '{print $2}')
        if [ -n "$REMAINING" ]; then
            print_warning "Forçage de l'arrêt des processus restants: $REMAINING"
            for PID in $REMAINING; do
                kill -9 $PID 2>/dev/null || true
            done
        fi
        
        print_success "Tous les serveurs Node.js arrêtés"
    fi
}

# Fonction pour build
build_app() {
    print_info "🔨 Build WebAssembly..."
    ./scripts/build.sh web
    print_success "✅ Build terminé"
}

# Fonction pour serveur + navigateur avec logs
start_server_with_browser() {
    print_info "🚀 Démarrage du serveur..."
    
    # Démarrer le serveur en arrière-plan
    ./scripts/start-server.sh &
    SERVER_PID=$!
    
    # Attendre que le serveur démarre
    print_info "⏳ Attente du démarrage du serveur..."
    sleep 3
    
    # Vérifier que le serveur répond
    if curl -s http://localhost:8000 >/dev/null; then
        print_success "✅ Serveur démarré sur http://localhost:8000"
        
        # Ouvrir le navigateur avec les logs
        print_info "🌐 Ouverture du navigateur avec logs..."
        
        # Détecter Chrome
        if [ -d "/Applications/Google Chrome.app" ]; then
            BROWSER="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        elif command -v google-chrome >/dev/null 2>&1; then
            BROWSER="google-chrome"
        elif command -v chromium >/dev/null 2>&1; then
            BROWSER="chromium"
        else
            print_warning "Chrome non trouvé, ouverture manuelle requise"
            print_info "Ouvrez http://localhost:8000 dans Chrome"
            print_info "Appuyez sur F12 pour ouvrir les outils de développement"
            return
        fi
        
        # Ouvrir Chrome avec les outils de développement
        print_info "Ouverture de Chrome avec les outils de développement..."
        $BROWSER --auto-open-devtools-for-tabs --disable-web-security --user-data-dir=/tmp/sirenepupitre-dev http://localhost:8000 &
        
        print_success "🎯 Application ouverte dans le navigateur"
        print_info "📊 Consultez la console du navigateur (F12) pour voir les logs"
        print_info "🛑 Pour arrêter: kill $SERVER_PID"
        
        # Attendre que l'utilisateur appuie sur une touche
        print_info "Appuyez sur Entrée pour arrêter le serveur..."
        read -r
        
        # Arrêter le serveur
        print_info "Arrêt du serveur..."
        kill $SERVER_PID 2>/dev/null || true
        print_success "Serveur arrêté"
        
    else
        print_error "❌ Le serveur n'a pas démarré correctement"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
}

# Fonction pour build + serveur + navigateur
build_and_serve_with_browser() {
    print_info "🔨 Build + Serveur + Navigateur..."
    build_app
    print_info "⏳ Attente de 2 secondes..."
    sleep 2
    start_server_with_browser
}

# Traitement des arguments
case "${1:-both}" in
    "build")
        build_app
        ;;
    "serve")
        kill_servers
        start_server_with_browser
        ;;
    "both")
        kill_servers
        build_and_serve_with_browser
        ;;
    "kill")
        kill_servers
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        print_error "Option non reconnue: $1"
        show_help
        exit 1
        ;;
esac
