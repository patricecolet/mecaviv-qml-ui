#!/bin/bash

# Script de test des connexions pour SirenConsole
# Usage: ./scripts/test-connections.sh [IP_BASE]

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonctions utilitaires
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
BASE_IP=${1:-"192.168.1"}
PORT=10001
TIMEOUT=3

print_status "Test des connexions WebSocket vers les pupitres"
print_status "Base IP: $BASE_IP"
print_status "Port: $PORT"
print_status "Timeout: ${TIMEOUT}s"
echo ""

# Fonction pour tester une connexion
test_connection() {
    local ip=$1
    local port=$2
    local pupitre_id=$3
    
    print_status "Test connexion Pupitre $pupitre_id ($ip:$port)..."
    
    # Test de connectivité réseau
    if ping -c 1 -W $TIMEOUT $ip > /dev/null 2>&1; then
        print_success "Pupitre $pupitre_id: Ping OK"
        
        # Test du port WebSocket
        if timeout $TIMEOUT bash -c "</dev/tcp/$ip/$port" 2>/dev/null; then
            print_success "Pupitre $pupitre_id: Port $port ouvert"
            return 0
        else
            print_warning "Pupitre $pupitre_id: Port $port fermé ou inaccessible"
            return 1
        fi
    else
        print_error "Pupitre $pupitre_id: Ping échoué"
        return 2
    fi
}

# Tester les 7 pupitres
total_tests=0
successful_tests=0
failed_tests=0

for i in {1..7}; do
    ip="$BASE_IP.10$i"
    total_tests=$((total_tests + 1))
    
    if test_connection $ip $PORT $i; then
        successful_tests=$((successful_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    echo ""
done

# Résumé
echo "=================================="
print_status "Résumé des tests:"
print_success "Connexions réussies: $successful_tests/$total_tests"
if [ $failed_tests -gt 0 ]; then
    print_error "Connexions échouées: $failed_tests/$total_tests"
fi

# Suggestions
if [ $failed_tests -gt 0 ]; then
    echo ""
    print_warning "Suggestions pour les connexions échouées:"
    print_warning "1. Vérifier que les pupitres sont allumés"
    print_warning "2. Vérifier la configuration réseau"
    print_warning "3. Vérifier que les serveurs WebSocket sont démarrés"
    print_warning "4. Vérifier les pare-feu"
fi

# Code de sortie
if [ $failed_tests -eq 0 ]; then
    print_success "Tous les tests sont passés avec succès!"
    exit 0
else
    print_warning "Certains tests ont échoué"
    exit 1
fi
