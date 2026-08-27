#!/usr/bin/env bash
# prepare-qml.sh — copie les sources QML/C++ dans un dossier de build dédié Qt5
# et versionne les imports QML (Qt5 refuse les imports sans version).
# La source d'origine (Qt6, imports sans version) reste intacte.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$HERE/../.." && pwd)"   # .../SirenManager
STAGE="$HERE/build/stage"                # arbre source versionné Qt5

echo "[prepare-qml] source: $PROJ_ROOT"
echo "[prepare-qml] stage : $STAGE"

rm -rf "$STAGE"
mkdir -p "$STAGE"

# Copier ce dont le build Qt5 a besoin
cp -R "$PROJ_ROOT/QML"  "$STAGE/QML"
cp -R "$PROJ_ROOT/src"  "$STAGE/src"
cp     "$PROJ_ROOT/main.cpp" "$STAGE/main.cpp"
cp     "$PROJ_ROOT/data.qrc"  "$STAGE/data.qrc"

# rcc (--list) répertorie les <file> même à l'intérieur d'un commentaire XML,
# ce qui ferait dépendre le build d'images inexistantes (bloc /resources commenté).
# On retire ces références du qrc stagé (les images n'existent pas encore).
sed -i '' '/resources\/images\/icons/d' "$STAGE/data.qrc"

# Versionner les imports dans toutes les copies QML.
# Ancrage en fin de ligne pour ne pas re-versionner un import déjà versionné,
# et pour ne pas confondre "import QtQuick" avec "import QtQuick.Controls".
find "$STAGE/QML" -name '*.qml' -print0 | while IFS= read -r -d '' f; do
  sed -E -i '' \
    -e 's/^([[:space:]]*import QtQuick)[[:space:]]*$/\1 2.15/' \
    -e 's/^([[:space:]]*import QtQuick\.Controls)[[:space:]]*$/\1 2.15/' \
    -e 's/^([[:space:]]*import QtQuick\.Layouts)[[:space:]]*$/\1 1.15/' \
    -e 's/^([[:space:]]*import SirenManager)[[:space:]]*$/\1 1.0/' \
    "$f"
done

echo "[prepare-qml] imports versionnés. Vérif (doit être vide) :"
if grep -rEn '^[[:space:]]*import (QtQuick|QtQuick\.Controls|QtQuick\.Layouts|SirenManager)[[:space:]]*$' "$STAGE/QML"; then
  echo "[prepare-qml] ERREUR: imports sans version restants" >&2
  exit 1
fi
echo "[prepare-qml] OK"
