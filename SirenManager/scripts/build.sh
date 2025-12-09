#!/bin/bash

# Script de build pour SirenManager

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Couleurs pour les messages
print_info() {
    echo "ℹ️  $1"
}

print_success() {
    echo "✅ $1"
}

print_error() {
    echo "❌ $1"
}

# Fonction pour build WebAssembly
build_web() {
    print_info "Build pour WebAssembly..."
    
    # Vérifier Qt6 pour WebAssembly
    QT6_WASM_PATH="$HOME/Qt/6.10.0/wasm_singlethread"
    if [ ! -d "$QT6_WASM_PATH" ]; then
        print_error "Qt6 pour WebAssembly non trouvé dans $QT6_WASM_PATH"
        print_info "Installez Qt6 pour WebAssembly depuis Qt Installer"
        exit 1
    fi
    
    # Vérifier qt-cmake
    QMAKE="$QT6_WASM_PATH/bin/qt-cmake"
    if [ ! -f "$QMAKE" ]; then
        print_error "qt-cmake non trouvé dans $QMAKE"
        print_info "Vérifiez que Qt6 pour WebAssembly est correctement installé"
        exit 1
    fi
    
    print_success "Qt6 WebAssembly trouvé: $QT6_WASM_PATH"
    print_success "qt-cmake trouvé: $QMAKE"
    
    # Créer le dossier build pour web
    mkdir -p build
    cd build
    
    # Configuration CMake avec qt-cmake
    print_info "Configuration CMake pour WebAssembly..."
    "$QMAKE" ..
    
    # Compilation
    print_info "Compilation WebAssembly..."
    make -j$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
    
    cd ..
    
    # Copier les fichiers dans webfiles
    print_info "Copie des fichiers WebAssembly..."
    cp build/appSirenManager.* webfiles/ 2>/dev/null || true
    cp build/qtloader.js webfiles/ 2>/dev/null || true
    cp build/qtlogo.svg webfiles/ 2>/dev/null || true
    
    # FIX : Corriger l'ordre des scripts dans le HTML
    print_info "Correction de l'ordre des scripts dans le HTML..."
    if [ -f "webfiles/appSirenManager.html" ]; then
        # Créer une sauvegarde
        cp webfiles/appSirenManager.html webfiles/appSirenManager.html.bak
        
        # Supprimer la ligne appSirenManager.js
        sed -i.bak -e '/<script src="appSirenManager.js"><\/script>/d' webfiles/appSirenManager.html
        
        # Réinsérer appSirenManager.js APRÈS qtloader.js
        sed -i.bak -e 's|<script type="text/javascript" src="qtloader.js"></script>|<script type="text/javascript" src="qtloader.js"></script>\n    <script src="appSirenManager.js"></script>|' webfiles/appSirenManager.html
        
        print_success "Fichier HTML corrigé"
    fi
    
    print_success "Build WebAssembly terminé !"
    print_info "Fichiers disponibles dans webfiles/"
}

# Exécuter le build
build_web


