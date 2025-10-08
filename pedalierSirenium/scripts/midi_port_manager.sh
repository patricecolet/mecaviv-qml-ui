#!/bin/bash

# Gestionnaire de ports MIDI pour configuration manuelle
# Usage: ./midi_port_manager.sh [action] [options]

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Détection du système d'exploitation
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="Linux"
else
    echo -e "${RED}⚠️  Système non reconnu: $OSTYPE${NC}"
    exit 1
fi

# Fonction d'aide
show_help() {
    echo "🎛️ Gestionnaire de ports MIDI"
    echo "============================"
    echo ""
    echo "Usage: $0 [action] [options]"
    echo ""
    echo "Actions disponibles:"
    echo "  list                    - Lister tous les ports MIDI"
    echo "  status                  - Afficher le statut des connexions"
    echo "  connect <from> <to>     - Connecter deux ports MIDI"
    echo "  disconnect <from> <to>  - Déconnecter deux ports MIDI"
    echo "  create-virtual          - Créer des ports virtuels (Linux)"
    echo "  enable-iac              - Activer IAC Driver (macOS)"
    echo "  test <port>             - Tester un port spécifique"
    echo "  clean                   - Nettoyer toutes les connexions"
    echo "  help                    - Afficher cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0 list"
    echo "  $0 connect 'IAC Driver Bus 1' 'Pure Data Midi-In 1'"
    echo "  $0 connect 'Virtual Raw MIDI 0-2' 'Pure Data Midi-In 3'"
    echo "  $0 test 0"
    echo ""
}

# Fonction pour lister les ports MIDI
list_ports() {
    echo -e "${BLUE}📋 Ports MIDI disponibles:${NC}"
    echo "================================"
    
    if [[ "$OS" == "macOS" ]]; then
        echo -e "${YELLOW}🍎 macOS - Utilisation d'IAC Driver${NC}"
        aconnect -l | grep -E "(client|port)" | while read line; do
            if [[ $line =~ client[[:space:]]+([0-9]+):[[:space:]]+(.+) ]]; then
                client_num="${BASH_REMATCH[1]}"
                client_name="${BASH_REMATCH[2]}"
                echo -e "${GREEN}Client $client_num: $client_name${NC}"
            elif [[ $line =~ port[[:space:]]+([0-9]+):[[:space:]]+(.+) ]]; then
                port_num="${BASH_REMATCH[1]}"
                port_name="${BASH_REMATCH[2]}"
                echo "  Port $port_num: $port_name"
            fi
        done
    else
        echo -e "${YELLOW}🐧 Linux - Utilisation de VirMIDI${NC}"
        aconnect -l
    fi
}

# Fonction pour afficher le statut des connexions
show_status() {
    echo -e "${BLUE}🔗 Statut des connexions MIDI:${NC}"
    echo "=================================="
    
    # Afficher les connexions actives
    echo -e "${GREEN}Connexions actives:${NC}"
    aconnect -l | grep -A 5 "connected" || echo "Aucune connexion active"
    
    echo ""
    echo -e "${YELLOW}Ports recommandés pour QML:${NC}"
    if [[ "$OS" == "macOS" ]]; then
        echo "  - IAC Driver Bus 1, 2, 3, etc."
        echo "  - Configuration manuelle requise"
    else
        echo "  - VirMIDI 0-2 (recommandé pour QML)"
        echo "  - VirMIDI 0-3 (recommandé pour QML)"
        echo "  - Connexion automatique activée"
    fi
    
    echo ""
    echo -e "${YELLOW}Ports utilisés par Pure Data:${NC}"
    if [[ "$OS" == "macOS" ]]; then
        echo "  - IAC Driver Bus 1 (si configuré)"
    else
        echo "  - VirMIDI 0-0 (Pure Data IN 1)"
        echo "  - VirMIDI 0-1 (Pure Data IN 2)"
    fi
}

# Fonction pour connecter deux ports
connect_ports() {
    local from="$1"
    local to="$2"
    
    if [ -z "$from" ] || [ -z "$to" ]; then
        echo -e "${RED}❌ Usage: $0 connect <from> <to>${NC}"
        echo "Exemple: $0 connect 'IAC Driver Bus 1' 'Pure Data Midi-In 1'"
        exit 1
    fi
    
    echo -e "${BLUE}🔗 Connexion: $from → $to${NC}"
    
    # Trouver les numéros de client et port
    local from_client=$(aconnect -l | grep -A 10 "$from" | grep "client" | head -1 | awk '{print $2}' | tr -d ':')
    local from_port=$(aconnect -l | grep -A 10 "$from" | grep "port" | head -1 | awk '{print $2}' | tr -d ':')
    local to_client=$(aconnect -l | grep -A 10 "$to" | grep "client" | head -1 | awk '{print $2}' | tr -d ':')
    local to_port=$(aconnect -l | grep -A 10 "$to" | grep "port" | head -1 | awk '{print $2}' | tr -d ':')
    
    if [ -n "$from_client" ] && [ -n "$from_port" ] && [ -n "$to_client" ] && [ -n "$to_port" ]; then
        echo "Connexion: ${from_client}:${from_port} → ${to_client}:${to_port}"
        if aconnect "${from_client}:${from_port}" "${to_client}:${to_port}"; then
            echo -e "${GREEN}✅ Connexion réussie${NC}"
        else
            echo -e "${RED}❌ Échec de la connexion${NC}"
        fi
    else
        echo -e "${RED}❌ Impossible de trouver les ports spécifiés${NC}"
        echo "Ports disponibles:"
        aconnect -l | grep -E "(client|port)"
    fi
}

# Fonction pour déconnecter deux ports
disconnect_ports() {
    local from="$1"
    local to="$2"
    
    if [ -z "$from" ] || [ -z "$to" ]; then
        echo -e "${RED}❌ Usage: $0 disconnect <from> <to>${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔌 Déconnexion: $from → $to${NC}"
    
    # Trouver les numéros de client et port
    local from_client=$(aconnect -l | grep -A 10 "$from" | grep "client" | head -1 | awk '{print $2}' | tr -d ':')
    local from_port=$(aconnect -l | grep -A 10 "$from" | grep "port" | head -1 | awk '{print $2}' | tr -d ':')
    local to_client=$(aconnect -l | grep -A 10 "$to" | grep "client" | head -1 | awk '{print $2}' | tr -d ':')
    local to_port=$(aconnect -l | grep -A 10 "$to" | grep "port" | head -1 | awk '{print $2}' | tr -d ':')
    
    if [ -n "$from_client" ] && [ -n "$from_port" ] && [ -n "$to_client" ] && [ -n "$to_port" ]; then
        echo "Déconnexion: ${from_client}:${from_port} → ${to_client}:${to_port}"
        if aconnect -d "${from_client}:${from_port}" "${to_client}:${to_port}"; then
            echo -e "${GREEN}✅ Déconnexion réussie${NC}"
        else
            echo -e "${RED}❌ Échec de la déconnexion${NC}"
        fi
    else
        echo -e "${RED}❌ Impossible de trouver les ports spécifiés${NC}"
    fi
}

# Fonction pour créer des ports virtuels (Linux)
create_virtual_ports() {
    if [[ "$OS" != "Linux" ]]; then
        echo -e "${YELLOW}⚠️  Cette fonction n'est disponible que sur Linux${NC}"
        echo "Sur macOS, utilisez IAC Driver via Audio MIDI Setup"
        exit 1
    fi
    
    echo -e "${BLUE}🔧 Création de ports virtuels VirMIDI...${NC}"
    
    # Vérifier si le module est chargé
    if ! lsmod | grep -q snd_virmidi; then
        echo "Chargement du module snd_virmidi..."
        sudo modprobe snd_virmidi
    fi
    
    # Vérifier si les ports sont créés
    for i in {0..3}; do
        if aconnect -l | grep -q "Virtual Raw MIDI 0-$i"; then
            echo -e "${GREEN}✅ VirMIDI 0-$i déjà disponible${NC}"
        else
            echo -e "${YELLOW}⚠️  VirMIDI 0-$i non disponible${NC}"
        fi
    done
    
    echo ""
    echo -e "${GREEN}🎛️ Ports virtuels configurés pour QML:${NC}"
    echo "  - VirMIDI 0-0, 0-1 : Utilisés par Pure Data"
    echo "  - VirMIDI 0-2, 0-3 : Disponibles pour QML"
}

# Fonction pour activer IAC Driver (macOS)
enable_iac() {
    if [[ "$OS" != "macOS" ]]; then
        echo -e "${YELLOW}⚠️  Cette fonction n'est disponible que sur macOS${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🍎 Configuration IAC Driver...${NC}"
    echo ""
    echo "Pour activer IAC Driver sur macOS:"
    echo "1. Ouvrez 'Audio MIDI Setup' (Applications > Utilitaires)"
    echo "2. Menu Window > Show MIDI Studio"
    echo "3. Double-cliquez sur 'IAC Driver'"
    echo "4. Cochez 'Device is online'"
    echo "5. Créez des bus IAC si nécessaire"
    echo ""
    echo "Ou utilisez la commande:"
    echo "open -a 'Audio MIDI Setup'"
    
    # Ouvrir Audio MIDI Setup
    read -p "Voulez-vous ouvrir Audio MIDI Setup maintenant? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open -a "Audio MIDI Setup"
    fi
}

# Fonction pour tester un port
test_port() {
    local port="$1"
    
    if [ -z "$port" ]; then
        echo -e "${RED}❌ Usage: $0 test <port>${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🧪 Test du port: $port${NC}"
    
    # Vérifier si le port existe
    if aconnect -l | grep -q "$port"; then
        echo -e "${GREEN}✅ Port trouvé${NC}"
        
        # Vérifier les connexions
        echo "Connexions actives:"
        aconnect -l | grep -A 5 "$port" | grep "connected" || echo "Aucune connexion active"
    else
        echo -e "${RED}❌ Port non trouvé${NC}"
    fi
}

# Fonction pour nettoyer toutes les connexions
clean_connections() {
    echo -e "${BLUE}🧹 Nettoyage de toutes les connexions MIDI...${NC}"
    
    read -p "Êtes-vous sûr de vouloir déconnecter toutes les connexions MIDI? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Lister toutes les connexions actives
        local connections=$(aconnect -l | grep "connected" | awk '{print $1, $3}')
        
        if [ -n "$connections" ]; then
            echo "$connections" | while read from to; do
                echo "Déconnexion: $from → $to"
                aconnect -d "$from" "$to" 2>/dev/null || true
            done
            echo -e "${GREEN}✅ Nettoyage terminé${NC}"
        else
            echo "Aucune connexion à nettoyer"
        fi
    else
        echo "Nettoyage annulé"
    fi
}

# Fonction principale
main() {
    case "${1:-help}" in
        "list")
            list_ports
            ;;
        "status")
            show_status
            ;;
        "connect")
            connect_ports "$2" "$3"
            ;;
        "disconnect")
            disconnect_ports "$2" "$3"
            ;;
        "create-virtual")
            create_virtual_ports
            ;;
        "enable-iac")
            enable_iac
            ;;
        "test")
            test_port "$2"
            ;;
        "clean")
            clean_connections
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Exécuter le script principal
main "$@"
