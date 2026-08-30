#!/bin/sh
# Relie les sorties de Pure Data au puits audio par defaut.
#
# En JACK, Pd n'etablit ses liaisons qu'au lancement, et seulement si des ports
# de lecture existent deja. Constate le 2026-08-30 : le casque Bluetooth s'etant
# appaire apres le demarrage de Pd, `pw-link -l` ne montrait AUCUNE liaison sur
# pure_data -- le patch tournait, le transport avancait, et rien ne sortait.
# PipeWire ne raccorde pas de lui-meme un client deja lance.
#
# Meme forme que le cablage MIDI : un oneshot rejoue par un timer. Le rejeu est
# gratuit, pw-link refusant simplement une liaison qui existe.
set -u

sink=$(pactl get-default-sink 2>/dev/null) || exit 0
case "$sink" in
    ''|auto_null) exit 0 ;;   # le puits fictif de PipeWire n'est pas une sortie
esac

# Les ports d'entree du puits, dans l'ordre ou PipeWire les enumere : gauche
# puis droite, ou un seul s'il est mono.
pw-link -i 2>/dev/null | grep "^$sink:" | {
    n=1
    while IFS= read -r port; do
        pw-link "pure_data:output_$n" "$port" 2>/dev/null \
            && echo "audio-connect: pure_data:output_$n -> $port"
        n=$((n + 1))
    done
}
exit 0
