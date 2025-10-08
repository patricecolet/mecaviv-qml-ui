#!/bin/bash

# Script helper pour configurer le projet avec CMake
# Usage: ./configure.sh [preset]
# Presets: default, release, wasm, macos, linux, raspberry-pi

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

PRESET="${1:-default}"

echo "================================================"
echo "🔧 Configuration CMake - Preset: $PRESET"
echo "================================================"
echo ""

cd "$ROOT_DIR"

# Vérifier que CMake est installé
if ! command -v cmake &> /dev/null; then
    echo "❌ CMake n'est pas installé"
    echo "   Installation: brew install cmake (macOS) ou apt-get install cmake (Linux)"
    exit 1
fi

# Vérifier la version de CMake
CMAKE_VERSION=$(cmake --version | head -n1 | cut -d' ' -f3)
echo "✓ CMake version: $CMAKE_VERSION"
echo ""

# Configuration
echo "⚙️  Configuration du projet..."
cmake --preset="$PRESET"

echo ""
echo "================================================"
echo "✅ Configuration terminée !"
echo "================================================"
echo ""
echo "Pour builder :"
echo "  cmake --build build"
echo ""
echo "Ou avec le preset :"
echo "  cmake --build --preset=$PRESET"
echo ""

