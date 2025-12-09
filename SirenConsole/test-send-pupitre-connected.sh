#!/bin/bash
# Script pour tester l'envoi de PUPITRE_CONNECTED
# Usage: ./test-send-pupitre-connected.sh P1

PUPITRE_ID=${1:-P1}
API_URL="https://127.0.0.1:8001"

echo "📤 Envoi PUPITRE_CONNECTED pour $PUPITRE_ID..."

curl -k -X POST "$API_URL/api/test/pupitre-connected" \
  -H "Content-Type: application/json" \
  -d "{\"pupitreId\": \"$PUPITRE_ID\"}"

echo ""
