#!/bin/bash

# Configuration
RASPBERRY_IP="192.168.1.21"
RASPBERRY_USER="sirenateur"
REMOTE_PATH="/home/sirenateur/dev/src/mecaviv/patko-scratchpad/qtQmlSockets/pedalierSirenium"

echo " Déploiement rapide vers Raspberry Pi..."

# 1. Synchroniser les fichiers webfiles
echo "📁 Synchronisation des fichiers webfiles..."
rsync -avuP ../webfiles/ ${RASPBERRY_USER}@${RASPBERRY_IP}:${REMOTE_PATH}/webfiles/

if [ $? -ne 0 ]; then
    echo "❌ Erreur lors de la synchronisation"
    exit 1
fi

echo "✅ Fichiers synchronisés"

# 2. Redémarrer le serveur Node.js et Firefox via SSH
echo "🔄 Redémarrage du serveur Node.js et Firefox..."
ssh -t ${RASPBERRY_USER}@${RASPBERRY_IP} << 'EOF'
    cd /home/sirenateur/dev/src/mecaviv/patko-scratchpad/qtQmlSockets/pedalierSirenium/webfiles
    
    echo "🔧 Redémarrage du serveur Node.js..."
    
    # Tuer le processus Node.js existant s'il existe
    pkill -f "node.*server.js" || true
    
    # Attendre un peu
    sleep 2
    
    # Redémarrage du serveur
    nohup node server.js > server.log 2>&1 &
    
    # Vérifier que le serveur démarre
    sleep 3
    if pgrep -f "node.*server.js" > /dev/null; then
        echo "✅ Serveur Node.js redémarré avec succès"
        echo "📊 Logs disponibles dans webfiles/server.log"
    else
        echo "❌ Erreur lors du redémarrage du serveur"
        echo "📋 Vérifiez les logs dans webfiles/server.log"
        exit 1
    fi
    
    echo "🌐 Redémarrage de Firefox en mode kiosk..."
    
    # Tuer Firefox existant
    pkill firefox || true
    
    # Attendre que Firefox se ferme complètement
    sleep 3
    
    # Redémarrer Firefox en mode kiosk avec l'affichage local
    export DISPLAY=:0
    export XAUTHORITY=/home/sirenateur/.Xauthority
    chromium-browser  -url http://localhost:8010/qmlwebsocketserver.html &
    
    # Vérifier que Firefox démarre
    sleep 5
    if pgrep firefox > /dev/null; then
        echo "✅ Firefox redémarré en mode kiosk"
    else
        echo "❌ Erreur lors du redémarrage de Firefox"
        echo "🔍 Tentative avec chromium-browser..."
        chromium-browser  --disable-web-security --user-data-dir=/tmp/chrome-kiosk http://localhost:8010/qmlwebsocketserver.html &
        sleep 3
        if pgrep chromium > /dev/null; then
            echo "✅ Chromium redémarré en mode kiosk"
        else
            echo "❌ Erreur avec Chromium aussi"
        fi
    fi
    
    echo " Déploiement terminé sur le Raspberry Pi !"
EOF

if [ $? -eq 0 ]; then
    echo "✅ Déploiement réussi !"
    echo "🌐 Application accessible sur http://${RASPBERRY_IP}:8010"
    echo "��️  Firefox/Chromium en mode kiosk redémarré"
else
    echo "❌ Erreur lors du déploiement"
fi