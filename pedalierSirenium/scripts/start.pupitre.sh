#!/bin/sh
export DISPLAY=:0
cd /home/sirenateur/dev/src/mecaviv/patko-scratchpad/qtQmlSockets/SirenePupitre/webfiles/
node server.js &
sleep 5
firefox -kiosk -url http://localhost:8000/appSirenePupitre.html &
sleep 5
cd ../../../volant
pd -nogui M645.pd &


