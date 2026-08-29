#!/bin/sh
# Lance Pure Data en traduisant le NOM de la sortie audio en index, au demarrage.
#
# `-audiooutdev` veut un numero, et ce numero est une position dans une liste qui
# bouge : `-alsaadd default` ajoute le PCM de PipeWire en queue d'enumeration,
# donc son index vaut le nombre de peripheriques ALSA presents a cet instant.
# snd-virmidi et les sorties HDMI n'etant pas toutes enregistrees au demarrage a
# froid, un index fige designe alors une autre carte -- muette. Pd part en boucle
# sur `alsa xrun recovery apparently failed`, et cette boucle le monopolise : il
# cesse de repondre au WebSocket et le pedalier entier devient inutilisable.
# D'ou `-audiooutdev default` dans PD_AUDIO_OPTS, traduit ici sur l'enumeration
# du moment plutot que devine une fois pour toutes.
set -eu

PD_BIN=${PD_BIN:-/usr/local/bin/pd}
opts=${PD_AUDIO_OPTS:-}

index_de_default() {
    timeout 20 "$PD_BIN" -nogui -stderr -alsa -alsaadd default -listdev \
            -send "pd quit" 2>&1 \
        | awk '/^audio output devices:/ { d = 1; next }
               /^API number/           { d = 0 }
               d && $2 == "default"    { print substr($1, 1, length($1) - 1); exit }'
}

case " $opts " in
    *" -audiooutdev default "*)
        n=$(index_de_default) || n=""
        if [ -n "$n" ]; then
            opts=$(printf '%s' "$opts" | sed "s/-audiooutdev default/-audiooutdev $n/")
            echo "run-pd: sortie 'default' = peripherique $n" >&2
        else
            # Mieux vaut le choix de Pd qu'un index au hasard : au pire c'est muet,
            # la ou une mauvaise carte bloque tout le pedalier.
            opts=$(printf '%s' "$opts" | sed "s/-audiooutdev default//")
            echo "run-pd: 'default' absent de l'enumeration ALSA, Pd choisira seul" >&2
        fi
        ;;
esac

exec "$PD_BIN" -nogui -stderr $opts "$@"
