#!/bin/bash

# Version non-bloquante du script de connexion MIDI
# Liste des noms de devices rtpmidid à connecter
# Devices RTP écoutés par Pure Data (leur MIDI entre sur IN 1), branchés en
# direct : ALSA mélange sans rien demander plusieurs sources sur une même entrée.
#
# Ne pas essayer de les faire passer par un port VirMIDI en guise de mélangeur :
# VirMIDI est un pont séquenceur ↔ rawmidi, pas un mélangeur séquenceur. Ce qu'un
# client écrit dans 16:0 part vers le device hw:0,0 et ne ressort JAMAIS vers les
# abonnés en lecture de 16:0 — Pure Data n'y voit rien. Mesuré le 2026-08-02 :
# `aconnect 17:0 16:0` puis une injection dans hw:0,1 ne produit rien du tout sur
# `aseqdump -p 16:0`. Seul l'autre sens fonctionne, ce qui donne l'illusion que
# le port relaie quand on le teste avec `amidi`.
RTPMIDI_IN=("PEDALIER_SIRENIUM" "SIRENIUM" "La_Petite_Boite" "La_Grosse_Boite" "PEDALE_BOSS")
# Le port virtuel reste relié à Pure Data IN 1 : c'est par lui qu'on injecte du
# MIDI à la main pour tester sans le pédalier (`amidi -p hw:0,0 -S "B8 1A 7F"`).
HUB_NAME="Virtual Raw MIDI 0-0"
# Devices qui reçoivent le MIDI de Pure Data (OUT 1). CB4Tech Studio2 est une
# sortie seule : Pure Data lui envoie, il ne lui renvoie rien.
# SIRENIUM est absent de cette liste : c'est une source, on n'a rien à lui
# transmettre — et le retour Pure Data → SIRENIUM refermait une boucle inutile.
RTPMIDI_OUT=("PEDALIER_SIRENIUM" "La_Petite_Boite" "La_Grosse_Boite" "PEDALE_BOSS" "CB4Tech Studio2")

# Fonction pour attendre avec timeout
wait_for_service() {
    local service_name="$1"
    local timeout=10
    local count=0
    
    echo "Attente de $service_name (timeout: ${timeout}s)..."
    while [ $count -lt $timeout ]; do
        if aconnect -l | grep -q "$service_name"; then
            echo "$service_name détecté !"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    echo "Timeout: $service_name non détecté après ${timeout}s"
    return 1
}

# Attendre Pure Data et rtpmidid avec timeout
if ! wait_for_service "Pure Data"; then
    echo "❌ Pure Data non disponible, abandon"
    exit 1
fi

if ! wait_for_service "rtpmidid"; then
    echo "❌ rtpmidid non disponible, abandon"
    exit 1
fi

# Le reste du script reste identique...
PD_CLIENT=$(aconnect -l | awk '/client [0-9]+: .Pure Data/ {print $2}' | tr -d ':')
PD_IN1="${PD_CLIENT}:0"
PD_IN2="${PD_CLIENT}:1"
PD_IN3="${PD_CLIENT}:2"
PD_OUT1="${PD_CLIENT}:4"

RTP_CLIENT=$(aconnect -l | awk '/client [0-9]+: '\''rtpmidid'\''/ {print $2}' | tr -d ':')

echo "Pure Data client: $PD_CLIENT"
echo "rtpmidid client: $RTP_CLIENT"

# PHASE 1: Scan et identification des ports rtpmidid
echo "=== SCAN DES PORTS RTPMIDID ==="

TEMP_FILE=$(mktemp)

aconnect -l | awk -v client="$RTP_CLIENT" '
    /client '"$RTP_CLIENT"': '\''rtpmidid'\''/ {inclient=1; next}
    inclient && $0 ~ /^[[:space:]]+[0-9]+[[:space:]]+'\''/ {
        if (match($0, /[0-9]+/)) {
            port_num = substr($0, RSTART, RLENGTH)
            if (match($0, /'\''[^'\'']*'\''/)) {
                port_name = substr($0, RSTART+1, RLENGTH-2)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", port_name)
                print port_num ":" port_name
            }
        }
    }
    inclient && $0 ~ /^client / {inclient=0}
' > "$TEMP_FILE"

echo "Ports trouvés :"
while IFS=: read -r port_num port_name; do
    echo "  Port $port_num: '$port_name'"
done < "$TEMP_FILE"

# Connexion des ports VirMIDI
echo "=== CONNEXIONS VIRMIDI ==="
for VIRTNUM in 0 1; do
    VIRT_CLIENT=$(aconnect -l | awk -v n="Virtual Raw MIDI 0-$VIRTNUM" '/client [0-9]+: .Virtual Raw MIDI 0-/ {if ($0 ~ n) print $2}' | tr -d ':')
    if [ -n "$VIRT_CLIENT" ]; then
        echo "Connexion VirMIDI 0-$VIRTNUM (${VIRT_CLIENT}:0) -> Pure Data IN $((VIRTNUM+1))"
        aconnect "${VIRT_CLIENT}:0" "${PD_CLIENT}:$VIRTNUM" 2>/dev/null || echo "⚠️  Connexion VirMIDI déjà existante"
    else
        echo "Port VirMIDI 0-$VIRTNUM non trouvé"
    fi
done

# Le hub d'entrée, c'est le premier de ces ports virtuels : il vient donc d'être
# relié à Pure Data IN 1 par la boucle ci-dessus.
HUB_CLIENT=$(aconnect -l | awk -v n="$HUB_NAME" '/client [0-9]+: ./ {if (index($0, n)) print $2}' | tr -d ':')
HUB="${HUB_CLIENT}:0"

# PHASE 2: Connexions rtpmidid vers Pure Data IN 1
# Tous les devices RTP arrivent sur la même entrée, celle que lit le patch.
echo "=== CONNEXIONS RTPMIDID VERS PURE DATA ==="
for NAME in "${RTPMIDI_IN[@]}"; do
    PORTNUM=$(grep ":$NAME$" "$TEMP_FILE" | cut -d: -f1)
    if [ -n "$PORTNUM" ]; then
        # Le detour par le port virtuel a existe un moment : il avale le MIDI
        # sans le rendre, donc on le defait s'il traine encore.
        if [ -n "$HUB_CLIENT" ] && aconnect -d "${RTP_CLIENT}:${PORTNUM}" "$HUB" 2>/dev/null; then
            echo "🔌 détour par $HUB_NAME retiré pour $NAME"
        fi
        echo "Connexion ${RTP_CLIENT}:${PORTNUM} ($NAME) -> Pure Data IN 1"
        if aconnect "${RTP_CLIENT}:${PORTNUM}" "$PD_IN1" 2>/dev/null; then
            echo "✅ Connexion $NAME réussie"
        else
            echo "⚠️  Connexion $NAME (peut-être déjà existante)"
        fi
    else
        echo "❌ Port '$NAME' non trouvé"
    fi
done

# PHASE 3: Connexions directes Pure Data OUT 1 vers rtpmidid
echo "=== CONNEXIONS DIRECTES PURE DATA VERS RTPMIDID ==="
for NAME in "${RTPMIDI_OUT[@]}"; do
    PORTNUM=$(grep ":$NAME$" "$TEMP_FILE" | cut -d: -f1)
    if [ -n "$PORTNUM" ]; then
        echo "Connexion directe Pure Data OUT 1 -> ${RTP_CLIENT}:${PORTNUM} ($NAME)"
        if aconnect "$PD_OUT1" "${RTP_CLIENT}:${PORTNUM}" 2>/dev/null; then
            echo "✅ Connexion directe réussie vers $NAME"
        else
            echo "⚠️  Connexion directe vers $NAME (peut-être déjà existante)"
        fi
    else
        echo "Port '$NAME' non trouvé pour connexion directe"
    fi
done

rm "$TEMP_FILE"
echo "=== CONNEXIONS MIDI TERMINÉES ==="