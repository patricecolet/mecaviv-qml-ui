#!/usr/bin/env bash
#
# Kiosque du pédalier : attend que le serveur web réponde, puis ouvre Chromium
# en plein écran, plus le clavier virtuel.
#
# Lancé par ~/.config/autostart/pedalier-kiosk.desktop, donc dans la session
# graphique — c'est de là que viennent WAYLAND_DISPLAY et XDG_RUNTIME_DIR.
# Contrairement au backend (systemd --user), le kiosque n'a aucun sens sans
# écran : s'il meurt, pd et node continuent de tourner.

set -uo pipefail

ENV_FILE="$HOME/.config/pedalier/env"
# shellcheck source=/dev/null
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

KIOSK_URL="${KIOSK_URL:-http://localhost:8010/qmlwebsocketserver.html}"
LOG="${XDG_RUNTIME_DIR:-/tmp}/pedalier-kiosk.log"

exec >>"$LOG" 2>&1
printf '\n=== %s : démarrage du kiosque ===\n' "$(date '+%F %T')"

# Rend l'environnement graphique visible aux services systemd --user (utile pour
# relancer le kiosque depuis une session SSH).
systemctl --user import-environment WAYLAND_DISPLAY XDG_RUNTIME_DIR XDG_CURRENT_DESKTOP 2>/dev/null || true

# Attente active plutôt qu'un `sleep` deviné : au démarrage à froid, node peut
# mettre plusieurs secondes, et au redémarrage à chaud il répond immédiatement.
waited=0
until curl -fsS -o /dev/null --max-time 2 "$KIOSK_URL"; do
    waited=$(( waited + 1 ))
    if [ "$waited" -gt 120 ]; then
        echo "✗ $KIOSK_URL ne répond pas après 60 s — kiosque non lancé"
        exit 1
    fi
    sleep 0.5
done
echo "✓ serveur web prêt après $(( waited / 2 )) s"

# wvkbd : clavier virtuel, un seul à la fois.
if command -v wvkbd-mobintl >/dev/null 2>&1 && ! pgrep -x wvkbd-mobintl >/dev/null; then
    wvkbd-mobintl &
fi

CHROME_FLAGS=(
    --kiosk
    # Profil persistant : dans /tmp il était effacé à chaque démarrage, donc
    # toute autorisation accordée était redemandée au redémarrage suivant.
    --user-data-dir="$HOME/.local/share/pedalier/chrome-kiosk"
    # Le cache, lui, reste dans /tmp et repart propre à chaque boot : c'est ce
    # qui évite qu'un ancien wasm soit resservi après un déploiement.
    --disk-cache-dir=/tmp/chrome-kiosk-cache
    --noerrdialogs
    --disable-infobars
    --disable-session-crashed-bubble
    --check-for-update-interval=31536000
)

# La session du Pi est Wayland (labwc) ; Xwayland reste là comme repli.
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    CHROME_FLAGS+=(--ozone-platform=wayland --enable-features=UseOzonePlatform)
else
    export DISPLAY="${DISPLAY:-:0}"
    echo "⚠ WAYLAND_DISPLAY absent — repli sur X11 ($DISPLAY)"
fi

exec chromium-browser "${CHROME_FLAGS[@]}" "$KIOSK_URL"
