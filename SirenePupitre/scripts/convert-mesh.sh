#!/bin/bash

##############################################################################
# Script de conversion .obj vers .mesh pour Qt Quick 3D
# Usage: ./convert-mesh.sh <fichier.obj> <nom_final.mesh>
# Exemple: ./convert-mesh.sh TrebleKey.obj Clef3D.mesh
##############################################################################

set -e  # Arrêter en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Fonction pour afficher l'aide
show_help() {
    cat << EOF
🎨 Script de conversion .obj vers .mesh pour Qt Quick 3D

Usage:
    $0 <fichier.obj> <nom_final.mesh>

Arguments:
    fichier.obj     Fichier source au format Wavefront OBJ
    nom_final.mesh  Nom du fichier .mesh de sortie

Exemples:
    $0 TrebleKey.obj Clef3D.mesh
    $0 BassKey.obj ClefBass3D.mesh
    $0 ../models/Piano.obj Piano.mesh

Notes:
    - L'outil balsam de Qt doit être installé
    - Le script gère automatiquement les fichiers temporaires
    - Le fichier .mesh sera placé dans le même dossier que le .obj

EOF
}

# Vérifier les arguments
if [ "$#" -lt 1 ]; then
    print_error "Arguments manquants"
    show_help
    exit 1
fi

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    show_help
    exit 0
fi

if [ "$#" -lt 2 ]; then
    print_error "Vous devez spécifier le fichier source ET le nom de sortie"
    show_help
    exit 1
fi

# Arguments
SOURCE_OBJ="$1"
OUTPUT_MESH="$2"

# Vérifier que le fichier source existe
if [ ! -f "$SOURCE_OBJ" ]; then
    print_error "Fichier source non trouvé: $SOURCE_OBJ"
    exit 1
fi

# Trouver balsam
print_info "Recherche de l'outil balsam..."
BALSAM_PATH=""

# Essayer différents chemins
POSSIBLE_PATHS=(
    "$HOME/Qt/6.10.0/macos/bin/balsam"
    "$HOME/Qt/6.10.0/gcc_64/bin/balsam"
    "$HOME/Qt/6.9.0/macos/bin/balsam"
    "$HOME/Qt/6.9.0/gcc_64/bin/balsam"
    "/usr/local/bin/balsam"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$path" ]; then
        BALSAM_PATH="$path"
        break
    fi
done

# Si pas trouvé, chercher avec find
if [ -z "$BALSAM_PATH" ]; then
    print_warning "balsam non trouvé dans les chemins standards, recherche..."
    BALSAM_PATH=$(find "$HOME/Qt" -name balsam -type f 2>/dev/null | head -1)
fi

if [ -z "$BALSAM_PATH" ] || [ ! -f "$BALSAM_PATH" ]; then
    print_error "balsam non trouvé. Veuillez installer Qt Quick 3D."
    exit 1
fi

print_success "balsam trouvé: $BALSAM_PATH"

# Obtenir le dossier du fichier source
SOURCE_DIR=$(dirname "$SOURCE_OBJ")
SOURCE_BASENAME=$(basename "$SOURCE_OBJ" .obj)
cd "$SOURCE_DIR" || exit 1

print_info "Conversion de $SOURCE_OBJ vers $OUTPUT_MESH..."

# Créer un nom temporaire unique pour éviter les conflits
TEMP_NAME="temp_$RANDOM"

# Lancer balsam
print_info "Exécution de balsam..."
"$BALSAM_PATH" "$SOURCE_BASENAME.obj" "$TEMP_NAME.mesh" 2>&1 | grep -v "Failed to import" || true

# Attendre un peu que balsam finisse d'écrire
sleep 0.5

# Chercher le fichier .mesh généré
MESH_FILE=""

# Vérifier dans le sous-dossier meshes/
if [ -d "./meshes" ]; then
    MESH_FILE=$(find ./meshes -name "*.mesh" -type f | head -1)
fi

# Si pas trouvé dans meshes/, vérifier dans le dossier courant
if [ -z "$MESH_FILE" ] || [ ! -f "$MESH_FILE" ]; then
    MESH_FILE=$(find . -maxdepth 1 -name "*.mesh" -type f | head -1)
fi

if [ -z "$MESH_FILE" ] || [ ! -f "$MESH_FILE" ]; then
    print_error "Aucun fichier .mesh n'a été généré"
    # Nettoyer les fichiers temporaires
    rm -f "$TEMP_NAME.qml"
    rm -rf ./meshes/
    exit 1
fi

print_success "Fichier .mesh trouvé: $MESH_FILE"

# Copier vers le nom final
cp "$MESH_FILE" "./$OUTPUT_MESH"
print_success "Fichier copié vers: $OUTPUT_MESH"

# Nettoyer les fichiers temporaires
print_info "Nettoyage des fichiers temporaires..."
rm -f "$SOURCE_BASENAME.qml"
rm -f "$TEMP_NAME.qml"
rm -rf ./meshes/

# Afficher les informations du fichier
FILE_SIZE=$(ls -lh "$OUTPUT_MESH" | awk '{print $5}')
print_success "Conversion terminée !"
echo ""
echo "📊 Résultat:"
echo "   Fichier: $OUTPUT_MESH"
echo "   Taille: $FILE_SIZE"
echo ""
print_info "Vous pouvez maintenant utiliser ce fichier dans QML:"
echo "   Model { source: \"qrc:/chemin/vers/$OUTPUT_MESH\" }"

