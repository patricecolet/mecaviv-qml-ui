#!/usr/bin/env bash
# build-app.sh — produit un SirenManager.app autonome pour macOS 10.13 (Intel),
# embarquant l'app Qt5 + le backend Node (exécutable autonome), démarrés ensemble.
#
# Prérequis (machine de build) :
#   - Qt 5.15.2 macOS dans ./Qt  (installé via prepare : voir README)
#   - npx / node disponibles (pour générer le backend via pkg, base node16)
#
# Usage : bash packaging/macos1013/build-app.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$HERE/../.." && pwd)"          # .../SirenManager
QT_DIR="${QT_DIR:-$HERE/Qt/5.15.2/clang_64}"    # surchargeable
BUILD="$HERE/build"
APP="$BUILD/appSirenManager.app"

[ -x "$QT_DIR/bin/qmake" ] || { echo "Qt5 introuvable dans $QT_DIR (set QT_DIR=...)" >&2; exit 1; }

echo "==> [1/6] Préparation des sources QML versionnées (Qt5)"
bash "$HERE/prepare-qml.sh"

echo "==> [2/6] Configuration + build de l'app Qt5 (x86_64, deploy 10.13)"
cmake -S "$HERE" -B "$BUILD" \
    -DCMAKE_PREFIX_PATH="$QT_DIR" \
    -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD" --parallel
[ -d "$APP" ] || { echo "Bundle non produit : $APP" >&2; exit 1; }

echo "==> [3/6] Build du backend autonome (pkg, node16-macos-x64)"
BACKEND_BIN="$BUILD/sirenmanager-backend"
( cd "$PROJ_ROOT/backend" && npx --yes pkg server.js \
    --targets node16-macos-x64 \
    --output "$BACKEND_BIN" )
[ -x "$BACKEND_BIN" ] || { echo "Backend non produit : $BACKEND_BIN" >&2; exit 1; }

echo "==> [4/6] Déploiement des frameworks/plugins Qt dans le bundle"
# -qmldir : laisse macdeployqt scanner les imports QML pour embarquer
# QtQuick / Controls.2 / QtWebSockets etc.
"$QT_DIR/bin/macdeployqt" "$APP" -qmldir="$BUILD/stage/QML"

echo "==> [5/6] Intégration du backend + config.json dans le bundle"
cp "$BACKEND_BIN" "$APP/Contents/MacOS/sirenmanager-backend"
chmod +x "$APP/Contents/MacOS/sirenmanager-backend"
# config.json éditable, à côté de l'exécutable backend (cf. server.js : process.pkg)
cp "$PROJ_ROOT/backend/config.json" "$APP/Contents/MacOS/config.json"

echo "==> [6/6] Signature ad-hoc (Gatekeeper 10.13 : 1er lancement = clic droit > Ouvrir)"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --verbose=2 "$APP" || true

echo
echo "OK -> $APP"
echo "Pour livrer : zipper le .app (ditto -c -k --keepParent \"$APP\" SirenManager.zip)"
