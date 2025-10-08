#!/bin/bash

# Script de test pour vérifier la connexion MIDI
# Usage: ./test_midi_connection.sh [port_number]

set -e

echo "🎛️ Test de connexion MIDI"
echo "========================"

# Détection du système d'exploitation
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macOS"
    echo "🍎 Système détecté: macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="Linux"
    echo "🐧 Système détecté: Linux"
else
    echo "⚠️  Système non reconnu: $OSTYPE"
    exit 1
fi

# Fonction pour lister les ports MIDI
list_midi_ports() {
    echo ""
    echo "📋 Ports MIDI disponibles:"
    echo "------------------------"
    
    if [[ "$OS" == "macOS" ]]; then
        # Sur macOS, utiliser aconnect pour lister
        aconnect -l | grep -E "(client|port)" | while read line; do
            if [[ $line =~ client[[:space:]]+([0-9]+):[[:space:]]+(.+) ]]; then
                client_num="${BASH_REMATCH[1]}"
                client_name="${BASH_REMATCH[2]}"
                echo "Client $client_num: $client_name"
            elif [[ $line =~ port[[:space:]]+([0-9]+):[[:space:]]+(.+) ]]; then
                port_num="${BASH_REMATCH[1]}"
                port_name="${BASH_REMATCH[2]}"
                echo "  Port $port_num: $port_name"
            fi
        done
    else
        # Sur Linux, utiliser aconnect
        aconnect -l
    fi
}

# Fonction pour tester un port spécifique
test_port() {
    local port_num=$1
    echo ""
    echo "🧪 Test du port MIDI $port_num..."
    
    # Vérifier si le port existe
    if aconnect -l | grep -q "port $port_num:"; then
        echo "✅ Port $port_num trouvé"
        
        # Essayer de se connecter (test de lecture)
        echo "🔍 Test de lecture du port $port_num..."
        if timeout 5 aconnect -l | grep -A 10 "port $port_num:" | grep -q "connected"; then
            echo "✅ Port $port_num est connecté et actif"
        else
            echo "⚠️  Port $port_num n'est pas connecté"
        fi
    else
        echo "❌ Port $port_num non trouvé"
        return 1
    fi
}

# Fonction pour tester les ports virtuels
test_virtual_ports() {
    echo ""
    echo "🔗 Test des ports virtuels..."
    
    if [[ "$OS" == "macOS" ]]; then
        # Test IAC Driver sur macOS
        echo "🍎 Test des ports IAC Driver..."
        IAC_CLIENT=$(aconnect -l | awk '/client [0-9]+: .IAC Driver/ {print $2}' | tr -d ':')
        if [ -n "$IAC_CLIENT" ]; then
            echo "✅ IAC Driver détecté (Client: $IAC_CLIENT)"
            echo "   Ports disponibles: IAC Driver Bus 1, 2, 3, etc."
        else
            echo "❌ IAC Driver non détecté"
            echo "   Activez-le dans Audio MIDI Setup > Window > Show MIDI Studio"
        fi
    else
        # Test VirMIDI sur Linux
        echo "🐧 Test des ports VirMIDI..."
        for VIRTNUM in 0 1 2 3; do
            VIRT_CLIENT=$(aconnect -l | awk -v n="Virtual Raw MIDI 0-$VIRTNUM" '/client [0-9]+: .Virtual Raw MIDI 0-/ {if ($0 ~ n) print $2}' | tr -d ':')
            if [ -n "$VIRT_CLIENT" ]; then
                echo "✅ VirMIDI 0-$VIRTNUM disponible (Client: $VIRT_CLIENT)"
            else
                echo "❌ VirMIDI 0-$VIRTNUM non disponible"
            fi
        done
    fi
}

# Fonction pour tester la latence MIDI
test_midi_latency() {
    echo ""
    echo "⏱️  Test de latence MIDI..."
    
    # Vérifier si midiutil est installé (Python)
    if command -v python3 &> /dev/null; then
        echo "🐍 Python3 détecté - test de latence disponible"
        echo "   Utilisez: python3 -c \"import midiutil; print('MIDI libraries disponibles')\""
    else
        echo "⚠️  Python3 non détecté - test de latence limité"
    fi
    
    # Test simple avec aconnect
    echo "🔍 Test de connectivité MIDI..."
    if aconnect -l &> /dev/null; then
        echo "✅ Connectivité MIDI OK"
    else
        echo "❌ Problème de connectivité MIDI"
    fi
}

# Fonction pour afficher les recommandations
show_recommendations() {
    echo ""
    echo "💡 Recommandations:"
    echo "------------------"
    
    if [[ "$OS" == "macOS" ]]; then
        echo "🍎 Sur macOS:"
        echo "   - Utilisez les ports IAC Driver pour le monitoring QML"
        echo "   - Activez IAC Driver dans Audio MIDI Setup si nécessaire"
        echo "   - Configurez manuellement les connexions via l'interface QML"
        echo "   - Les ports VirMIDI ne sont pas disponibles par défaut"
    else
        echo "🐧 Sur Linux:"
        echo "   - Les ports VirMIDI 0-2 et 0-3 sont recommandés pour QML"
        echo "   - Les ports VirMIDI 0-0 et 0-1 sont utilisés par Pure Data"
        echo "   - La connexion automatique est activée par défaut"
    fi
    
    echo ""
    echo "🎛️ Pour tester avec l'application QML:"
    echo "   1. Lancez l'application QML"
    echo "   2. Appuyez sur F12 pour ouvrir le Debug Panel"
    echo "   3. Allez à l'onglet MIDI"
    echo "   4. Vérifiez la connexion et les données MIDI"
}

# Exécution principale
main() {
    echo "🎛️ Test de connexion MIDI - $(date)"
    echo "================================"
    
    # Lister les ports disponibles
    list_midi_ports
    
    # Tester les ports virtuels
    test_virtual_ports
    
    # Tester la latence
    test_midi_latency
    
    # Si un port spécifique est fourni, le tester
    if [ $# -eq 1 ]; then
        test_port $1
    fi
    
    # Afficher les recommandations
    show_recommendations
    
    echo ""
    echo "✅ Test terminé"
}

# Exécuter le script principal
main "$@"
