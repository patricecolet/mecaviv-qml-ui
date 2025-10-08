#!/bin/bash

# Script de téléchargement du fichier WASM depuis Google Drive
# Usage: ./scripts/download_wasm.sh

set -e

echo "📥 Téléchargement du fichier WASM depuis Google Drive..."

# ID du fichier Google Drive
GOOGLE_DRIVE_ID="1itBpRCFBakVglWZNU7g1_b-6RQi0IA62"
OUTPUT_FILE="../webfiles/qmlwebsocketserver.wasm"

# Créer le dossier webfiles s'il n'existe pas
mkdir -p ../webfiles

# Vérifier si le fichier existe déjà
if [ -f "$OUTPUT_FILE" ]; then
    echo "⚠️  Le fichier $OUTPUT_FILE existe déjà."
    read -p "Voulez-vous le remplacer ? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Téléchargement annulé."
        exit 1
    fi
fi

# Télécharger le fichier (plusieurs méthodes de fallback)
echo "🌐 Téléchargement en cours..."

# Méthode 1: Essayer d'abord le téléchargement direct
echo "📋 Tentative 1/3: Téléchargement direct..."
if wget --progress=bar --no-check-certificate \
        "https://drive.google.com/uc?export=download&id=${GOOGLE_DRIVE_ID}" \
        -O "$OUTPUT_FILE" 2>/dev/null; then
    echo "✅ Téléchargement direct réussi !"
else
    echo "📋 Tentative 2/3: Méthode avec cookies..."
    
    # Méthode 2: Avec cookies pour gros fichiers
    wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate \
         "https://drive.google.com/uc?export=download&id=${GOOGLE_DRIVE_ID}" \
         -O- | grep -o 'confirm=[^&]*' | cut -d= -f2 > /tmp/confirm.txt 2>/dev/null

    CONFIRM_TOKEN=$(cat /tmp/confirm.txt 2>/dev/null)
    
    if [ ! -z "$CONFIRM_TOKEN" ]; then
        echo "🔑 Token trouvé: ${CONFIRM_TOKEN}"
        wget --load-cookies /tmp/cookies.txt \
             --progress=bar --no-check-certificate \
             "https://drive.google.com/uc?export=download&confirm=${CONFIRM_TOKEN}&id=${GOOGLE_DRIVE_ID}" \
             -O "$OUTPUT_FILE"
    else
        echo "📋 Tentative 3/3: URL alternative..."
        # Méthode 3: URL alternative
        wget --progress=bar --no-check-certificate \
             "https://drive.google.com/u/0/uc?id=${GOOGLE_DRIVE_ID}&export=download&confirm=t" \
             -O "$OUTPUT_FILE"
    fi
    
    # Nettoyage
    rm -f /tmp/cookies.txt /tmp/confirm.txt
fi

# Vérifier le téléchargement
if [ -f "$OUTPUT_FILE" ]; then
    FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo "✅ Téléchargement terminé !"
    echo "📁 Fichier: $OUTPUT_FILE"
    echo "📊 Taille: $FILE_SIZE"
    echo ""
    echo "🚀 Vous pouvez maintenant lancer:"
    echo "   ./scripts/build_run_web.sh"
    echo "   ou"
    echo "   node webfiles/server.js"
else
    echo "❌ Erreur lors du téléchargement !"
    exit 1
fi 