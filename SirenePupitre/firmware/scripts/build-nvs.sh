#!/usr/bin/env bash
# Genere l'image de partition NVS du pupitre depuis nvs/pupitre-test.csv.
#
# Sortie : bin/pupitre-test.nvs.bin (20 Ko = taille de la partition nvs de NiDMI).
# Le binaire est versionne dans git ; ce script sert a le regenerer apres une
# modification du CSV ou des JSON de pins.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CSV="${1:-$HERE/nvs/pupitre-test.csv}"
OUT="$HERE/bin/$(basename "${CSV%.csv}").nvs.bin"
SIZE=0x5000   # doit correspondre a la partition nvs de NiDMI (voir README)

# L'outil vient de l'ESP-IDF (paquet python esp_idf_nvs_partition_gen).
# On cherche un interpreteur capable de l'importer : d'abord le python courant,
# puis les environnements installes par l'ESP-IDF sous ~/.espressif.
find_python() {
    local candidates=(python3)
    [ -n "${IDF_PYTHON_ENV_PATH:-}" ] && candidates+=("$IDF_PYTHON_ENV_PATH/bin/python3")
    local p
    while IFS= read -r p; do candidates+=("$p"); done < <(ls -d "$HOME"/.espressif/python_env/*/bin/python3 2>/dev/null | sort -r)
    for p in "${candidates[@]}"; do
        if [ -x "$(command -v "$p" 2>/dev/null || echo "$p")" ] \
           && "$p" -c "import esp_idf_nvs_partition_gen" >/dev/null 2>&1; then
            echo "$p"; return 0
        fi
    done
    return 1
}

PY="$(find_python)" || {
    echo "❌ Le paquet python 'esp_idf_nvs_partition_gen' est introuvable." >&2
    echo "   Il est fourni par l'ESP-IDF : installe l'IDF, ou 'pip install esp-idf-nvs-partition-gen'." >&2
    exit 1
}

# Les chemins 'file' du CSV sont relatifs au CSV lui-meme -> se placer a cote.
cd "$(dirname "$CSV")"
"$PY" -m esp_idf_nvs_partition_gen.nvs_partition_gen generate "$(basename "$CSV")" "$OUT" "$SIZE"

printf '✅ %s (%s octets)\n' "$OUT" "$(wc -c < "$OUT" | tr -d ' ')"
