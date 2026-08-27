#!/bin/sh
# Attend qu'une vraie sortie audio existe avant de lancer Pure Data.
#
# Pd ouvre son PCM ALSA au chargement du patch et ne le rouvre jamais. Au
# démarrage à froid, le casque Bluetooth est allumé mais BlueZ met quelques
# secondes à le joindre et à créer son sink PipeWire : Pd part avant, tombe sur
# un « Dummy Output », et boucle sur « alsa xrun recovery apparently failed ».
# Cette boucle le monopolise au point qu'il ne traite plus ses messages — le
# WebSocket cesse de répondre et le pédalier entier devient inutilisable, pas
# seulement muet. Constaté au premier redémarrage complet, le 2026-08-27.
#
# Même contrat que wait-network.sh : on n'échoue jamais. Sans sortie audio, Pd
# doit démarrer quand même — le MIDI et le WebSocket, eux, n'en dépendent pas.

limit=30
n=0
while [ "$n" -lt "$limit" ]; do
    # Un sink reel, c'est-a-dire autre que le « auto_null » que PipeWire fabrique
    # quand il n'a rien d'autre a proposer.
    if [ -n "$(pactl list sinks short 2>/dev/null | grep -v auto_null)" ]; then
        [ "$n" -gt 0 ] && echo "sortie audio prete apres ${n}s"
        exit 0
    fi
    sleep 1
    n=$((n + 1))
done

echo "aucune sortie audio après ${limit}s — démarrage sans son" >&2
exit 0
