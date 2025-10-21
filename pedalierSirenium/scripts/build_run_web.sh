#!/bin/bash
set -e

# Options
NO_CLEAN=0
NO_OPEN=0
BROWSER_PREF=""
for arg in "$@"; do
  case "$arg" in
    --no-clean|--incremental)
      NO_CLEAN=1
      ;;
    --no-open)
      NO_OPEN=1
      ;;
    --browser=*)
      BROWSER_PREF="${arg#*=}"
      ;;
  esac
done

# Chemins
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
QTFILES="$ROOT_DIR/QtFiles"
BUILD_DIR="$QTFILES/build"
WEBFILES="$ROOT_DIR/webfiles"
QMAKE="$HOME/Qt/6.10.0/wasm_singlethread/bin/qt-cmake"

# 1. Nettoyage et compilation
cd "$QTFILES"
if [ "$NO_CLEAN" -eq 0 ]; then
  echo "🧹 Suppression du dossier de build..."
  rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if [ ! -f "CMakeCache.txt" ]; then
  echo "⚙️  Configuration CMake..."
  "$QMAKE" ..
else
  if [ "$NO_CLEAN" -eq 0 ]; then
    echo "⚙️  Reconfiguration CMake..."
    "$QMAKE" ..
  else
    echo "⚙️  Configuration CMake (incr.) — réutilisation du cache"
  fi
fi

echo "🔨 Compilation..."
JOBS=$( (command -v sysctl >/dev/null 2>&1 && sysctl -n hw.ncpu) || (command -v getconf >/dev/null 2>&1 && getconf _NPROCESSORS_ONLN) || echo 4 )
make -j "$JOBS"

# 2. Copie des fichiers générés dans webfiles
cd "$BUILD_DIR"
echo "📋 Copie des fichiers dans $WEBFILES..."
cp -v qmlwebsocketserver.html qmlwebsocketserver.js qmlwebsocketserver.wasm qtloader.js qtlogo.svg "$WEBFILES/"
# Copie le dossier qmlwebsocketserver (pour les modules QML)
if [ -d "qmlwebsocketserver" ]; then
  rsync -av --delete qmlwebsocketserver "$WEBFILES/"
else
  echo "⚠️  Dossier qmlwebsocketserver non trouvé dans $BUILD_DIR, rien à synchroniser."
fi
# Copie config.js pour WASM
cp -v ../qml/qmlwebsocketserver/config.js "$WEBFILES/"

# Copie des polices musicales depuis shared/
echo "📋 Copie des polices musicales depuis shared/..."
mkdir -p "$WEBFILES/fonts"
if compgen -G "$ROOT_DIR/../../shared/qml/fonts/*.ttf" > /dev/null; then
  cp -v "$ROOT_DIR/../../shared/qml/fonts/"*.ttf "$WEBFILES/fonts/" || true
  echo "✅ Polices copiées"
else
  echo "⚠️  Aucune police trouvée dans shared/qml/fonts/"
fi

# 3. Lance le serveur Node.js
cd "$WEBFILES"
echo "🚀 Lancement du serveur Node.js..."
# Tue le serveur s'il tourne déjà
pkill -f "node server.js" || true
nohup node server.js > /tmp/webfiles_server.log 2>&1 &
sleep 2

# 4. Ouvre la page dans le navigateur (Chrome prioritaire pour Web MIDI)
URL="http://localhost:8010/qmlwebsocketserver.html"
if [ "$NO_OPEN" -eq 0 ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -n "$BROWSER_PREF" ]; then
      if [ "$BROWSER_PREF" = "chrome" ]; then
        echo "🌐 Ouverture de $URL dans Google Chrome..."
        open -a "Google Chrome" "$URL" &
      elif [ "$BROWSER_PREF" = "firefox" ]; then
        FIREFOX_PATH=$(which firefox || echo "/Applications/Firefox.app/Contents/MacOS/firefox")
        echo "🌐 Ouverture de $URL dans Firefox..."
        "$FIREFOX_PATH" --new-tab "$URL" &
      else
        echo "🌐 Ouverture de $URL (open)..."
        open "$URL" &
      fi
    else
      if open -Ra "Google Chrome" >/dev/null 2>&1; then
        echo "🌐 Ouverture de $URL dans Google Chrome..."
        open -a "Google Chrome" "$URL" &
      else
        FIREFOX_PATH=$(which firefox || echo "/Applications/Firefox.app/Contents/MacOS/firefox")
        echo "🌐 Ouverture de $URL dans Firefox..."
        "$FIREFOX_PATH" --new-tab "$URL" &
      fi
    fi
  else
    BROWSER=$(command -v google-chrome || command -v chrome || command -v chromium || command -v firefox || echo "xdg-open")
    echo "🌐 Ouverture de $URL dans $BROWSER..."
    "$BROWSER" "$URL" &
  fi
fi

echo "✅ Build, déploiement et lancement terminés."