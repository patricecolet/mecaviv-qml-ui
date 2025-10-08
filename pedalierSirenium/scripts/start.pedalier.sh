#!/bin/sh
export DISPLAY=:0
sleep 10
/usr/local/bin/reaper &
sleep 3
cd /home/sirenateur/dev/src/mecaviv/puredata-abstractions/examples
pd -nogui MidiToSiren.pd &
sleep 3

# Lancer rtpmidid avant le serveur web et Firefox, avec log
/usr/local/bin/rtpmidid > /tmp/rtpmidid.log 2>&1 &
sleep 3

# Lancer le script de connexion MIDI non-bloquant
/home/sirenateur/dev/src/mecaviv/patko-scratchpad/qtQmlSockets/pedalierSirenium/scripts/rtpmidi_connect_async.sh &
sleep 2

cd /home/sirenateur/dev/src/mecaviv/patko-scratchpad/qtQmlSockets/pedalierSirenium/webfiles/
node server.js &
sleep 3
#firefox -kiosk -url http://localhost:8010/qmlwebsocketserver.html &
chromium-browser --kiosk --disable-web-security --user-data-dir=/tmp/chrome-kiosk http://localhost:8010/qmlwebsocketserver.html &
sleep 5
# clavier virtuel
wvkbd-mobintl &






