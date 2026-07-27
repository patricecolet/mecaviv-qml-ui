#!/bin/sh
# Déprécié. Le démarrage passe désormais par systemd --user, installé par
# deploy/pedalier-ctl.sh (units pedalier-*.service + pedalier.target), et le
# kiosque par ~/.config/autostart/pedalier-kiosk.desktop.
#
#   pedalier-ctl.sh start | stop | restart | status
#
# Ce fichier ne lance plus rien : ses chemins absolus pointaient vers une
# arborescence qui n'existe plus (patko-scratchpad/qtQmlSockets).
echo "start.pedalier.sh est déprécié — utiliser : pedalier-ctl.sh start" >&2
exit 1
