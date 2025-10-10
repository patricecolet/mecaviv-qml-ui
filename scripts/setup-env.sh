#!/bin/bash

# Script d'aide pour configurer les variables d'environnement Qt
# Usage: source scripts/setup-env.sh
# ou: ./scripts/setup-env.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "================================================"
echo "🔧 Configuration des variables Qt"
echo "================================================"
echo ""

# Détecter le système d'exploitation
OS="$(uname -s)"
case "$OS" in
    Linux*)  OS_TYPE="Linux";;
    Darwin*) OS_TYPE="macOS";;
    *)       OS_TYPE="Unknown";;
esac

echo "Système détecté: $OS_TYPE"
echo ""

# Chemins Qt par défaut selon l'OS
if [ "$OS_TYPE" = "macOS" ]; then
    DEFAULT_QT_DIR="$HOME/Qt/6.10.0/macos"
    DEFAULT_QT_WASM_DIR="$HOME/Qt/6.10.0/wasm_singlethread"
elif [ "$OS_TYPE" = "Linux" ]; then
    DEFAULT_QT_DIR="$HOME/Qt/6.10.0/gcc_64"
    DEFAULT_QT_WASM_DIR="$HOME/Qt/6.10.0/wasm_singlethread"
else
    DEFAULT_QT_DIR="$HOME/Qt/6.10.0"
    DEFAULT_QT_WASM_DIR="$HOME/Qt/6.10.0/wasm_singlethread"
fi

# Fonction pour demander un chemin
ask_path() {
    local var_name=$1
    local default_path=$2
    local description=$3
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$description"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Vérifier si le chemin par défaut existe
    if [ -d "$default_path" ]; then
        echo "✅ Chemin trouvé: $default_path"
        read -p "Utiliser ce chemin? [Y/n]: " response
        response=${response:-Y}
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo "$default_path"
            return
        fi
    else
        echo "❌ Chemin par défaut introuvable: $default_path"
    fi
    
    # Demander un chemin personnalisé
    echo ""
    echo "Entrez le chemin de votre installation Qt:"
    read -p "Chemin ($default_path): " custom_path
    custom_path=${custom_path:-$default_path}
    
    # Vérifier que le chemin existe
    if [ -d "$custom_path" ]; then
        echo "✅ Chemin valide"
        echo "$custom_path"
    else
        echo "⚠️  Attention: Ce chemin n'existe pas sur votre système"
        read -p "Utiliser quand même? [y/N]: " force
        if [[ "$force" =~ ^[Yy]$ ]]; then
            echo "$custom_path"
        else
            echo ""
            return
        fi
    fi
}

# Demander QT_DIR
echo ""
QT_DIR=$(ask_path "QT_DIR" "$DEFAULT_QT_DIR" "Qt Desktop (pour compilation native)")

if [ -z "$QT_DIR" ]; then
    echo "❌ Configuration annulée"
    exit 1
fi

# Demander QT_WASM_DIR
echo ""
QT_WASM_DIR=$(ask_path "QT_WASM_DIR" "$DEFAULT_QT_WASM_DIR" "Qt WebAssembly (pour compilation web)")

if [ -z "$QT_WASM_DIR" ]; then
    echo "❌ Configuration annulée"
    exit 1
fi

# Exporter les variables pour la session actuelle
export QT_DIR="$QT_DIR"
export QT_WASM_DIR="$QT_WASM_DIR"

echo ""
echo "================================================"
echo "✅ Variables configurées pour cette session:"
echo "================================================"
echo "QT_DIR=$QT_DIR"
echo "QT_WASM_DIR=$QT_WASM_DIR"
echo ""

# Demander si on veut sauvegarder dans le profil shell
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Voulez-vous ajouter ces variables à votre profil shell?"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Cela permettra de les avoir automatiquement à chaque nouveau terminal."
echo ""

# Détecter le shell
if [ -n "$ZSH_VERSION" ]; then
    PROFILE_FILE="$HOME/.zshrc"
    SHELL_NAME="zsh"
elif [ -n "$BASH_VERSION" ]; then
    PROFILE_FILE="$HOME/.bashrc"
    SHELL_NAME="bash"
else
    PROFILE_FILE="$HOME/.profile"
    SHELL_NAME="shell"
fi

echo "Fichier détecté: $PROFILE_FILE ($SHELL_NAME)"
echo ""
read -p "Ajouter au profil? [Y/n]: " add_to_profile
add_to_profile=${add_to_profile:-Y}

if [[ "$add_to_profile" =~ ^[Yy]$ ]]; then
    echo "" >> "$PROFILE_FILE"
    echo "# Qt Paths for mecaviv-qml-ui (added by setup-env.sh)" >> "$PROFILE_FILE"
    echo "export QT_DIR=\"$QT_DIR\"" >> "$PROFILE_FILE"
    echo "export QT_WASM_DIR=\"$QT_WASM_DIR\"" >> "$PROFILE_FILE"
    
    echo "✅ Variables ajoutées à $PROFILE_FILE"
    echo ""
    echo "Pour activer dans ce terminal:"
    echo "  source $PROFILE_FILE"
    echo ""
    echo "Les nouveaux terminaux auront ces variables automatiquement."
else
    echo "ℹ️  Configuration temporaire (session actuelle uniquement)"
    echo ""
    echo "Pour rendre permanent, ajoutez manuellement à $PROFILE_FILE:"
    echo ""
    echo "  export QT_DIR=\"$QT_DIR\""
    echo "  export QT_WASM_DIR=\"$QT_WASM_DIR\""
fi

echo ""
echo "================================================"
echo "🚀 Configuration terminée !"
echo "================================================"
echo ""
echo "Vous pouvez maintenant builder le projet:"
echo "  cmake --preset=default"
echo "  cmake --build build --parallel"
echo ""
echo "Pour plus d'infos, voir CONFIG.md"
echo ""


