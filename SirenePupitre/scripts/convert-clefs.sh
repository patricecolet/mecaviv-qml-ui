#!/bin/bash

##############################################################################
# Script de conversion des clés musicales .obj vers .mesh
# Convertit automatiquement TrebleKey.obj et BassKey.obj
# Usage: ./convert-clefs.sh
##############################################################################

set -e

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

echo ""
echo "🎼 Conversion des clés musicales"
echo "================================"
echo ""

# Chemin vers le dossier meshes
MESH_DIR="$(cd "$(dirname "$0")/../QML/utils/meshes" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

print_info "Dossier des meshes: $MESH_DIR"
echo ""

# Vérifier que les fichiers sources existent
if [ ! -f "$MESH_DIR/TrebleKey.obj" ]; then
    echo "❌ TrebleKey.obj non trouvé dans $MESH_DIR"
    exit 1
fi

if [ ! -f "$MESH_DIR/BassKey.obj" ]; then
    echo "❌ BassKey.obj non trouvé dans $MESH_DIR"
    exit 1
fi

# Convertir la clé de Sol
print_info "Conversion de la clé de Sol (TrebleKey.obj → TrebleKey.mesh)..."
cd "$MESH_DIR"
"$SCRIPT_DIR/convert-mesh.sh" TrebleKey.obj TrebleKey.mesh
echo ""

# Convertir la clé de Fa
print_info "Conversion de la clé de Fa (BassKey.obj → BassKey.mesh)..."
cd "$MESH_DIR"
"$SCRIPT_DIR/convert-mesh.sh" BassKey.obj BassKey.mesh
echo ""

print_success "Toutes les clés ont été converties avec succès !"
echo ""
echo "📁 Fichiers générés:"
ls -lh "$MESH_DIR"/*.mesh | awk '{print "   " $9 " (" $5 ")"}'
echo ""
print_info "Les fichiers sont prêts à être utilisés dans le projet QML"

