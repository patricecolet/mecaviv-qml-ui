#!/bin/bash

# Script de nettoyage pour tous les projets
# Supprime les dossiers build/ et node_modules/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "================================================"
echo "🧹 Nettoyage de tous les projets"
echo "================================================"
echo ""

# Fonction pour nettoyer un projet
clean_project() {
    local project_name=$1
    local project_dir=$2
    
    echo "🧹 Nettoyage de $project_name..."
    
    # Supprimer build/
    if [ -d "$project_dir/build" ]; then
        rm -rf "$project_dir/build"
        echo "  ✓ build/ supprimé"
    fi
    
    # Supprimer build-*/
    find "$project_dir" -maxdepth 1 -type d -name "build-*" -exec rm -rf {} + 2>/dev/null || true
    
    # Supprimer node_modules/
    if [ -d "$project_dir/node_modules" ]; then
        rm -rf "$project_dir/node_modules"
        echo "  ✓ node_modules/ supprimé"
    fi
    
    # Supprimer les fichiers wasm dans webfiles/
    if [ -d "$project_dir/webfiles" ]; then
        find "$project_dir/webfiles" -name "*.wasm" -delete 2>/dev/null || true
        echo "  ✓ fichiers wasm nettoyés"
    fi
    
    echo "  ✅ $project_name nettoyé"
    echo ""
}

# Nettoyer SirenePupitre
clean_project "SirenePupitre" "$ROOT_DIR/SirenePupitre"

# Nettoyer SirenConsole
clean_project "SirenConsole" "$ROOT_DIR/SirenConsole"

# Nettoyer pedalierSirenium
clean_project "pedalierSirenium" "$ROOT_DIR/pedalierSirenium"
if [ -d "$ROOT_DIR/pedalierSirenium/QtFiles/build" ]; then
    rm -rf "$ROOT_DIR/pedalierSirenium/QtFiles/build"
    echo "  ✓ QtFiles/build/ supprimé"
fi

# Nettoyer sirenRouter
clean_project "sirenRouter" "$ROOT_DIR/sirenRouter"

# Nettoyer les logs temporaires
echo "🧹 Nettoyage des logs temporaires..."
rm -f /tmp/sirenepupitre_server.log
rm -f /tmp/sirenconsole_server.log
rm -f /tmp/pedalier_server.log
echo "  ✓ logs temporaires supprimés"
echo ""

# Tuer les serveurs Node.js en cours
echo "🛑 Arrêt des serveurs en cours..."
lsof -ti:8000 | xargs kill -9 2>/dev/null || true
lsof -ti:8001 | xargs kill -9 2>/dev/null || true
lsof -ti:8002 | xargs kill -9 2>/dev/null || true
lsof -ti:8003 | xargs kill -9 2>/dev/null || true
lsof -ti:8004 | xargs kill -9 2>/dev/null || true
lsof -ti:8010 | xargs kill -9 2>/dev/null || true
echo "  ✓ serveurs arrêtés"
echo ""

echo "================================================"
echo "✅ Nettoyage terminé !"
echo "================================================"
echo ""
echo "Pour rebuilder les projets :"
echo "  ./scripts/build-all.sh"

