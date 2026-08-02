#!/bin/sh
# Attend que la machine ait une adresse IPv4 routable avant de lancer Pure Data.
#
# Au démarrage à froid, systemd --user part avant que eth0 ait son adresse. Les
# neuf objets qui ouvrent une socket UDP vers les sirènes (192.168.1.11-17, les
# pavillons et les pchit) font leur `connect` au chargement du patch, une seule
# fois : s'il échoue — neuf « send: Network is unreachable » dans le journal —
# rien ne repart tout seul, et le pédalier tourne toute la session sans jamais
# atteindre une sirène.
#
# On n'échoue jamais : sans réseau, Pure Data doit démarrer quand même. Le
# WebSocket et le MIDI, eux, fonctionnent sans les sirènes.

# `hostname -I` plutôt que `ip addr` : il vit dans /usr/bin, présent dans le PATH
# d'un service --user, là où `ip` est dans /usr/sbin et peut manquer.
limit=30
n=0
while [ "$n" -lt "$limit" ]; do
    if [ -n "$(hostname -I 2>/dev/null | tr -d ' ')" ]; then
        [ "$n" -gt 0 ] && echo "réseau prêt après ${n}s"
        exit 0
    fi
    sleep 1
    n=$((n + 1))
done

echo "aucune adresse IPv4 après ${limit}s — démarrage sans réseau" >&2
exit 0
