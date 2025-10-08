#!/bin/bash

# Script de relancement des serveurs pour Raspberry Pi
# Ce script sera copié sur le Raspberry Pi et exécuté via SSH

PROJECT_PATH="/home/sirenateur/dev/src/mecaviv/patko-scratchpad/qtQmlSockets/SirenePupitre"

echo "🔄 Arrêt des processus existants..."

# Arrêter les processus (méthode robuste)
pkill -f appSirenePupitre 2>/dev/null || true
pkill -f server.js 2>/dev/null || true
pkill -f "python3 -m http.server" 2>/dev/null || true
pkill -f chromium 2>/dev/null || true
pkill -f chrome 2>/dev/null || true

# Attendre que les processus se terminent
sleep 2

echo "✅ Processus arrêtés"

# Aller dans le bon répertoire
cd "$PROJECT_PATH/webfiles" || {
    echo "❌ Erreur: Impossible d'accéder au répertoire $PROJECT_PATH/webfiles"
    exit 1
}

echo "🚀 Lancement du serveur Node.js..."
nohup node server.js > server.log 2>&1 &
NODE_PID=$!

echo "🌐 Lancement du serveur web..."
nohup python3 -m http.server 8080 > web.log 2>&1 &
WEB_PID=$!

# Vérifier que les processus sont lancés
sleep 1
if kill -0 $NODE_PID 2>/dev/null; then
    echo "✅ Serveur Node.js lancé (PID: $NODE_PID)"
else
    echo "❌ Erreur: Serveur Node.js n'a pas pu démarrer"
fi

if kill -0 $WEB_PID 2>/dev/null; then
    echo "✅ Serveur web lancé (PID: $WEB_PID)"
else
    echo "❌ Erreur: Serveur web n'a pas pu démarrer"
fi

# Attendre que les serveurs soient prêts
sleep 3

echo "🌐 Lancement de Chromium..."
# Lancer Chromium en mode kiosk (plein écran) sur l'URL locale
nohup chromium-browser --kiosk --no-sandbox --disable-web-security --disable-features=VizDisplayCompositor http://localhost:8080/appSirenePupitre.html > chromium.log 2>&1 &
CHROMIUM_PID=$!

# Vérifier que Chromium est lancé
sleep 2
if kill -0 $CHROMIUM_PID 2>/dev/null; then
    echo "✅ Chromium lancé (PID: $CHROMIUM_PID)"
else
    echo "❌ Erreur: Chromium n'a pas pu démarrer"
fi

# Attendre que les serveurs soient complètement prêts
echo "⏳ Attente que les serveurs soient prêts..."
sleep 5

echo "🎉 Relancement terminé !"
