#!/bin/bash
# atim-diagnostic.sh — Diagnostic carte ATIM ARM-Nano sur Raspberry Pi
# À exécuter sur le Raspberry Pi (directement ou via SSH)

set -e

echo "=============================================="
echo "  Diagnostic carte ATIM ARM-Nano"
echo "=============================================="
echo ""

# 1. Architecture et modèle
echo "--- 1. Architecture ---"
echo "  uname -m: $(uname -m)"
if [ -f /proc/device-tree/model ]; then
    echo "  Modèle: $(cat /proc/device-tree/model 2>/dev/null | tr -d '\0')"
fi
echo ""

# 2. Ports série disponibles
echo "--- 2. Ports série (UART) ---"
for dev in /dev/ttyAMA0 /dev/ttyS0 /dev/serial0 /dev/serial1 /dev/ttyUSB0; do
    if [ -e "$dev" ]; then
        perms=$(ls -l "$dev" 2>/dev/null | awk '{print $1, $3, $4}')
        echo "  ✓ $dev existe — $perms"
    else
        echo "  ✗ $dev n'existe pas"
    fi
done
echo ""

# 3. Liens symboliques serial0/serial1
echo "--- 3. Liens serial0/serial1 ---"
if [ -L /dev/serial0 ]; then
    echo "  /dev/serial0 -> $(readlink /dev/serial0)"
fi
if [ -L /dev/serial1 ]; then
    echo "  /dev/serial1 -> $(readlink /dev/serial1)"
fi
echo ""

# 4. Utilisateur actuel et groupe dialout
echo "--- 4. Permissions ---"
echo "  Utilisateur: $(whoami)"
echo "  Groupes: $(groups)"
if groups | grep -q dialout; then
    echo "  ✓ Utilisateur dans le groupe dialout"
else
    echo "  ✗ Utilisateur PAS dans dialout — exécuter: sudo usermod -aG dialout $USER"
fi
echo ""

# 5. UART dans la config du boot
echo "--- 5. Configuration UART (boot) ---"
CONFIG_FILES="/boot/firmware/config.txt /boot/config.txt"
for f in $CONFIG_FILES; do
    if [ -f "$f" ]; then
        echo "  Fichier: $f"
        if grep -q "^enable_uart=1" "$f" 2>/dev/null; then
            echo "    ✓ enable_uart=1 présent"
        else
            echo "    ✗ enable_uart=1 absent ou commenté"
            echo "      Ajouter 'enable_uart=1' dans $f"
        fi
        grep -E "uart|serial|tty" "$f" 2>/dev/null | sed 's/^/    /' || true
        echo ""
    fi
done
echo ""

# 6. Console série (doit être désactivée pour libérer l'UART)
echo "--- 6. Console série (getty) ---"
for svc in serial-getty@ttyS0 serial-getty@ttyAMA0; do
    if systemctl list-unit-files 2>/dev/null | grep -q "$svc"; then
        if systemctl is-enabled "$svc" 2>/dev/null | grep -q enabled; then
            echo "  ⚠ $svc activé — peut bloquer l'UART"
        else
            echo "  ✓ $svc désactivé ou absent"
        fi
    fi
done
echo ""

# 7. Bibliothèque rpi-nano
echo "--- 7. Bibliothèque rpi-nano ---"
RPI_NANO_FOUND=0
for d in /home/sirenateur/rpi-nano /home/pi/rpi-nano "$HOME/rpi-nano"; do
    if [ -d "$d" ]; then
        echo "  ✓ Dossier trouvé: $d"
        [ -f "$d/api/rpi_nano.h" ] && echo "    - api/rpi_nano.h OK" || echo "    - api/rpi_nano.h manquant"
        [ -f "$d/api/rpi_nano.c" ] && echo "    - api/rpi_nano.c OK" || echo "    - api/rpi_nano.c manquant"
        [ -f "$d/makefile" ] && echo "    - makefile OK" || echo "    - makefile manquant"
        RPI_NANO_FOUND=1
        break
    fi
done
if [ "$RPI_NANO_FOUND" -eq 0 ]; then
    echo "  ✗ rpi-nano non trouvé"
    echo "    Cloner: git clone https://github.com/atim-radiocommunications/rpi-nano.git"
fi
echo ""

# 8. Test d'accès au port
echo "--- 8. Test accès lecture port série ---"
UART_DEV=""
for d in /dev/ttyAMA0 /dev/ttyS0 /dev/serial0; do
    if [ -e "$d" ] && [ -r "$d" ]; then
        UART_DEV="$d"
        break
    fi
done
if [ -n "$UART_DEV" ]; then
    echo "  Port à tester: $UART_DEV"
    echo "  Pour un test complet, compiler et lancer un exemple rpi-nano."
else
    echo "  ✗ Aucun port UART accessible en lecture"
fi
echo ""

echo "=============================================="
echo "  Fin du diagnostic"
echo "=============================================="
