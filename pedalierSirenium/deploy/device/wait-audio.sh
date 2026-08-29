#!/bin/sh
# Attend qu'une vraie sortie audio soit UTILISABLE avant de lancer Pure Data.
#
# Pd ouvre son PCM ALSA au chargement du patch et ne le rouvre jamais. S'il
# tombe sur une sortie absente ou pas prete, il boucle sur
# « alsa xrun recovery apparently failed », et cette boucle le monopolise : il
# cesse de repondre au WebSocket. Le socket ecoute, mais aucune connexion ne
# s'etablit et le pedalier entier devient inutilisable, pas seulement muet.
#
# Attendre qu'un sink EXISTE ne suffit pas -- constate au demarrage a froid du
# 2026-08-30, casque allume : le sink bluez est cree avant que BlueZ ait acquis
# le transport A2DP, sa carte est encore sur le profil « off », et Pd part dans
# l'intervalle. On attend donc trois choses : un sink reel, un profil de sortie
# si la carte est Bluetooth, et un dixieme de seconde de silence qui passe --
# ce dernier verifie la sortie et la reveille du meme geste.
#
# Meme contrat que wait-network.sh : on n'echoue jamais. Sans sortie audio, Pd
# doit demarrer quand meme -- le MIDI et le WebSocket n'en dependent pas.

limit=45
n=0

sortie_prete() {
    # Un sink reel, c'est-a-dire autre que le « auto_null » que PipeWire
    # fabrique quand il n'a rien d'autre a proposer.
    [ -n "$(pactl list sinks short 2>/dev/null | grep -v auto_null)" ] || return 1

    # Si une carte Bluetooth est la, elle doit avoir fini de negocier sa sortie.
    if pactl list cards 2>/dev/null | grep -q 'Name: bluez'; then
        pactl list cards 2>/dev/null \
            | sed -n '/Name: bluez/,/Active Profile/p' \
            | grep -q 'Active Profile: a2dp' || return 1
    fi

    # Le seul test qui ne se paie pas de mots : envoyer du son. pw-play et non
    # paplay -- ce dernier refuse « - » et repond « open(): No such file or
    # directory », ce qui ferait echouer le test alors que la sortie va bien.
    head -c 19200 /dev/zero \
        | timeout 5 pw-play --format=s16 --rate=48000 --channels=2 - 2>/dev/null
}

while [ "$n" -lt "$limit" ]; do
    if sortie_prete; then
        [ "$n" -gt 0 ] && echo "sortie audio prete apres ${n}s"
        exit 0
    fi
    sleep 1
    n=$((n + 1))
done

echo "aucune sortie audio utilisable apres ${limit}s — demarrage sans son" >&2
exit 0
