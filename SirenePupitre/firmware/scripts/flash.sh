#!/usr/bin/env bash
# Flashe un XIAO ESP32-S3 avec le firmware NiDMI du pupitre + sa configuration NVS.
#
#   ./scripts/flash.sh                 firmware + NVS (mise en service d'une carte neuve)
#   ./scripts/flash.sh --fw-only       firmware seul   (conserve la config presente sur la carte)
#   ./scripts/flash.sh --nvs-only      config seule    (conserve le firmware present)
#   ./scripts/flash.sh --port /dev/... force le port serie
#
# ⚠️  Sans --fw-only, la NVS est ECRASEE : toute config faite dans l'interface web est perdue.
#     Pour mettre a jour le firmware d'une carte deja reglee, utiliser --fw-only (ou l'OTA).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$HERE/bin"

# Offsets de la table de partitions NiDMI (tools/nidmi_s3_ota_dual_littlefs.csv).
# Ils doivent rester synchronises avec elle — voir README.md.
OFF_BOOTLOADER=0x0        # l'ESP32-S3 demarre a 0x0 (et non 0x1000 comme l'ESP32 classique)
OFF_PARTITIONS=0x8000
OFF_NVS=0x9000            # taille 0x5000 = 20 Ko
OFF_APP=0x10000           # slot app0

FW_BOOTLOADER="$BIN/nidmi-s3-usbnet.bootloader.bin"
FW_PARTITIONS="$BIN/nidmi-s3-usbnet.partitions.bin"
FW_APP="$BIN/nidmi-s3-usbnet.app.bin"
NVS_IMAGE="$BIN/pupitre-test.nvs.bin"

DO_FW=true
DO_NVS=true
PORT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --fw-only)  DO_NVS=false; shift ;;
        --nvs-only) DO_FW=false;  shift ;;
        --port)     PORT="${2:?--port attend un peripherique}"; shift 2 ;;
        -h|--help)  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)          echo "❌ Option inconnue: $1 (voir --help)" >&2; exit 1 ;;
    esac
done

# --- esptool -------------------------------------------------------------
find_esptool() {
    command -v esptool >/dev/null 2>&1 && { command -v esptool; return 0; }
    command -v esptool.py >/dev/null 2>&1 && { command -v esptool.py; return 0; }
    # Fourni avec le paquet ESP32 d'arduino-cli / IDE Arduino.
    local p
    p="$(ls -d "$HOME"/Library/Arduino15/packages/esp32/tools/esptool_py/*/esptool 2>/dev/null | sort -V | tail -1)"
    [ -n "$p" ] && [ -x "$p" ] && { echo "$p"; return 0; }
    p="$(ls -d "$HOME"/.arduino15/packages/esp32/tools/esptool_py/*/esptool 2>/dev/null | sort -V | tail -1)"
    [ -n "$p" ] && [ -x "$p" ] && { echo "$p"; return 0; }
    return 1
}

ESPTOOL="$(find_esptool)" || {
    echo "❌ esptool introuvable." >&2
    echo "   Installe-le ('pip install esptool') ou installe le paquet ESP32 dans l'IDE Arduino." >&2
    exit 1
}

# --- port serie ----------------------------------------------------------
if [ -z "$PORT" ]; then
    PORT="$(ls /dev/cu.usbmodem* /dev/ttyACM* /dev/ttyUSB* 2>/dev/null | head -1 || true)"
fi
if [ -z "$PORT" ]; then
    cat >&2 <<'MSG'
❌ Aucun port serie trouve.

   Une carte qui tourne deja en variante USB-MIDI ON n'expose PAS de port serie :
   son USB est pris par le MIDI et le reseau. Il faut la passer en mode telechargement,
   a la main : maintenir BOOT, appuyer/relacher RESET, relacher BOOT — puis relancer.

   Une carte neuve (sortie d'usine) est reconnue directement.
MSG
    exit 1
fi

# esptool 5.x a renomme les sous-commandes en tirets (write-flash) ;
# les 4.x n'acceptent que l'ancien nom (write_flash).
if "$ESPTOOL" --help 2>&1 | grep -q -- 'write-flash'; then
    WRITE_CMD=write-flash
else
    WRITE_CMD=write_flash
fi

echo "📡 Port      : $PORT"
echo "🔧 esptool   : $ESPTOOL ($WRITE_CMD)"

ARGS=()
if [ "$DO_FW" = true ]; then
    for f in "$FW_BOOTLOADER" "$FW_PARTITIONS" "$FW_APP"; do
        [ -f "$f" ] || { echo "❌ Binaire manquant: $f" >&2; exit 1; }
    done
    ARGS+=("$OFF_BOOTLOADER" "$FW_BOOTLOADER" "$OFF_PARTITIONS" "$FW_PARTITIONS" "$OFF_APP" "$FW_APP")
    echo "📦 Firmware  : $(basename "$FW_APP")"
fi
if [ "$DO_NVS" = true ]; then
    [ -f "$NVS_IMAGE" ] || { echo "❌ Image NVS manquante: $NVS_IMAGE (lancer scripts/build-nvs.sh)" >&2; exit 1; }
    # Ecrite en dernier : si le firmware est flashe dans la meme passe, la NVS
    # doit gagner sur la region correspondante.
    ARGS+=("$OFF_NVS" "$NVS_IMAGE")
    echo "🗄️  NVS       : $(basename "$NVS_IMAGE")  (⚠️ ecrase la config de la carte)"
fi
[ ${#ARGS[@]} -eq 0 ] && { echo "Rien a faire (--fw-only et --nvs-only sont exclusifs)."; exit 1; }

"$ESPTOOL" --chip esp32s3 --port "$PORT" --baud 921600 "$WRITE_CMD" "${ARGS[@]}"

cat <<'MSG'

✅ Flash termine. La carte redemarre en variante usbmidi-on + usb-net :
   - elle apparait comme peripherique reseau USB ("nidmi") et comme port MIDI USB ;
   - interface web par le cable : http://192.168.7.1  (ou http://pupitre.local)
   - il n'y a plus de port serie tant que ce firmware tourne.
MSG
