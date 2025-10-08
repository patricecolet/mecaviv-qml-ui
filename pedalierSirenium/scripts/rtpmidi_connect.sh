#!/bin/bash

# Liste des noms de devices rtpmidid à connecter
RTPMIDI_NAMES=("PEDALIER_SIRENIUM" "SIRENIUM" "La_Petite_Boite" "La_Grosse_Boite" "PEDALE_BOSS")

echo "Attente de Pure Data et rtpmidid..."
while ! aconnect -l | grep -q "Pure Data"; do sleep 1; done
while ! aconnect -l | grep -q "rtpmidid"; do sleep 1; done

PD_CLIENT=$(aconnect -l | awk '/client [0-9]+: .Pure Data/ {print $2}' | tr -d ':')
PD_IN1="${PD_CLIENT}:0"
PD_IN2="${PD_CLIENT}:1"
PD_IN3="${PD_CLIENT}:2"
PD_OUT1="${PD_CLIENT}:4"  # Pure Data OUT 1

RTP_CLIENT=$(aconnect -l | awk '/client [0-9]+: '\''rtpmidid'\''/ {print $2}' | tr -d ':')

echo "Pure Data client: $PD_CLIENT"
echo "rtpmidid client: $RTP_CLIENT"

# PHASE 1: Scan et identification des ports rtpmidid
echo "=== SCAN DES PORTS RTPMIDID ==="

# Créer un fichier temporaire pour stocker les ports
TEMP_FILE=$(mktemp)

# Extraire les ports rtpmidid et les stocker dans le fichier temporaire
aconnect -l | awk -v client="$RTP_CLIENT" '
    /client '"$RTP_CLIENT"': '\''rtpmidid'\''/ {inclient=1; next}
    inclient && $0 ~ /^[[:space:]]+[0-9]+[[:space:]]+'\''/ {
        if (match($0, /[0-9]+/)) {
            port_num = substr($0, RSTART, RLENGTH)
            if (match($0, /'\''[^'\'']*'\''/)) {
                port_name = substr($0, RSTART+1, RLENGTH-2)
                # Nettoyer les espaces
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", port_name)
                print port_num ":" port_name
            }
        }
    }
    inclient && $0 ~ /^client / {inclient=0}
' > "$TEMP_FILE"

# Lire le fichier et afficher les ports trouvés
echo "Ports trouvés :"
while IFS=: read -r port_num port_name; do
    echo "  Port $port_num: '$port_name'"
done < "$TEMP_FILE"

echo "=== PORTS IDENTIFIÉS ==="
while IFS=: read -r port_num port_name; do
    echo "  '$port_name' -> port $port_num"
done < "$TEMP_FILE"
echo "========================"

# Connexion des ports VirMIDI
echo "=== CONNEXIONS VIRMIDI ==="
for VIRTNUM in 0 1; do
    VIRT_CLIENT=$(aconnect -l | awk -v n="Virtual Raw MIDI 0-$VIRTNUM" '/client [0-9]+: .Virtual Raw MIDI 0-/ {if ($0 ~ n) print $2}' | tr -d ':')
    if [ -n "$VIRT_CLIENT" ]; then
        echo "Connexion VirMIDI 0-$VIRTNUM (${VIRT_CLIENT}:0) -> Pure Data IN $((VIRTNUM+1))"
        aconnect "${VIRT_CLIENT}:0" "${PD_CLIENT}:$VIRTNUM"
    else
        echo "Port VirMIDI 0-$VIRTNUM non trouvé"
    fi
done

# PHASE 2: Connexions rtpmidid vers Pure Data IN 3
echo "=== CONNEXIONS RTPMIDID VERS PURE DATA ==="
for NAME in "${RTPMIDI_NAMES[@]}"; do
    # Chercher le port dans le fichier temporaire
    PORTNUM=$(grep ":$NAME$" "$TEMP_FILE" | cut -d: -f1)
    if [ -n "$PORTNUM" ]; then
        echo "Connexion ${RTP_CLIENT}:${PORTNUM} ($NAME) -> Pure Data IN 3"
        if aconnect "${RTP_CLIENT}:${PORTNUM}" "$PD_IN3"; then
            echo "✅ Connexion $NAME réussie"
        else
            echo "❌ Échec connexion $NAME"
        fi
    else
        echo "❌ Port '$NAME' non trouvé dans la liste des ports disponibles"
    fi
done

# PHASE 3: Connexions directes Pure Data OUT 1 vers rtpmidid
echo "=== CONNEXIONS DIRECTES PURE DATA VERS RTPMIDID ==="
for NAME in "${RTPMIDI_NAMES[@]}"; do
    # Chercher le port dans le fichier temporaire
    PORTNUM=$(grep ":$NAME$" "$TEMP_FILE" | cut -d: -f1)
    if [ -n "$PORTNUM" ]; then
        echo "Connexion directe Pure Data OUT 1 -> ${RTP_CLIENT}:${PORTNUM} ($NAME)"
        if aconnect "$PD_OUT1" "${RTP_CLIENT}:${PORTNUM}"; then
            echo "✅ Connexion directe réussie vers $NAME"
        else
            echo "❌ Échec connexion directe vers $NAME"
        fi
    else
        echo "Port '$NAME' non trouvé pour connexion directe"
    fi
done

# Nettoyer le fichier temporaire
rm "$TEMP_FILE"

echo "=== RÉSUMÉ DES CONNEXIONS ==="
echo "Connexions actives vers Pure Data IN 3:"
aconnect -l | awk -v client="$PD_CLIENT" '
    $0 ~ "client "client": .Pure Data" {inclient=1; next}
    inclient && $0 ~ "Pure Data Midi-In 3" {print "  " $0}
    inclient && $0 ~ /^client / {inclient=0}
'

echo "Toutes les connexions demandées sont faites."

# PHASE 4: Configuration du monitoring MIDI pour QML
echo "=== CONFIGURATION MONITORING MIDI QML ==="

# Détection du système d'exploitation
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🍎 macOS détecté - Configuration manuelle requise"
    echo ""
    echo "🎛️ Configuration MIDI pour QML (macOS):"
    echo "   - Utilisez les ports IAC Driver pour le monitoring QML"
    echo "   - Activez IAC Driver dans Audio MIDI Setup si nécessaire"
    echo "   - Configurez manuellement les connexions via l'interface QML"
    echo ""
    echo "📋 Instructions:"
    echo "   1. Ouvrez Audio MIDI Setup: open -a 'Audio MIDI Setup'"
    echo "   2. Menu Window > Show MIDI Studio"
    echo "   3. Double-cliquez sur 'IAC Driver'"
    echo "   4. Cochez 'Device is online'"
    echo "   5. Créez des bus IAC si nécessaire"
    echo "   6. Lancez l'application QML et utilisez l'onglet MIDI (F12)"
    echo ""
    echo "🔧 Ou utilisez le gestionnaire de ports:"
    echo "   ./midi_port_manager.sh enable-iac"
    echo "   ./midi_port_manager.sh list"
else
    echo "🐧 Linux détecté - Configuration automatique"
    echo ""
    echo "🔍 Vérification des ports virtuels pour le monitoring QML..."
    for VIRTNUM in 2 3; do  # Utiliser les ports 2 et 3 pour éviter les conflits
        VIRT_CLIENT=$(aconnect -l | awk -v n="Virtual Raw MIDI 0-$VIRTNUM" '/client [0-9]+: .Virtual Raw MIDI 0-/ {if ($0 ~ n) print $2}' | tr -d ':')
        if [ -n "$VIRT_CLIENT" ]; then
            echo "✅ Port VirMIDI 0-$VIRTNUM disponible pour le monitoring QML"
            echo "   Client: $VIRT_CLIENT, Port: 0"
            echo "   Le contrôleur MIDI QML se connectera automatiquement"
        else
            echo "⚠️  Port VirMIDI 0-$VIRTNUM non disponible pour le monitoring QML"
            echo "   Utilisez: ./midi_port_manager.sh create-virtual"
        fi
    done
    
    echo ""
    echo "🎛️ Configuration monitoring MIDI (Linux):"
    echo "   - Les ports VirMIDI 0-0 et 0-1 sont utilisés par Pure Data"
    echo "   - Les ports VirMIDI 0-2 et 0-3 sont disponibles pour QML"
    echo "   - Connexion automatique activée au premier port disponible"
    echo "   - Utilisez le Debug Panel (F12) pour voir les logs MIDI"
fi

echo ""
echo "🎛️ Outils de gestion MIDI disponibles:"
echo "   ./test_midi_connection.sh          - Test de connexion MIDI"
echo "   ./midi_port_manager.sh list        - Lister les ports MIDI"
echo "   ./midi_port_manager.sh status      - Statut des connexions"
echo "   ./midi_port_manager.sh help        - Aide complète"

echo "=== CONFIGURATION MONITORING TERMINÉE ==="