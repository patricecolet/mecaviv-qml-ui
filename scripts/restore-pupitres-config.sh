#!/bin/bash
# Script pour restaurer config.json sur les pupitres corrompus
# Usage: ./scripts/restore-pupitres-config.sh [--all] [--pupitres "IP1,IP2"]

set -e

# Configuration par défaut
SSH_PASSWORD="SIRENS"
SERVER_USER="sirenateur"
RESTORE_ALL=false
SELECTED_PUPITRES=""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Gestion des arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --all)
      RESTORE_ALL=true
      shift
      ;;
    --pupitres)
      SELECTED_PUPITRES="$2"
      shift 2
      ;;
    --password)
      SSH_PASSWORD="$2"
      shift 2
      ;;
    *)
      echo "Option inconnue: $1"
      echo "Usage: $0 [--all] [--pupitres \"IP1,IP2\"] [--password PASSWORD]"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}🔧 Restauration de config.json sur les pupitres${NC}"
echo ""

# Vérifier que sshpass est installé
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}❌ Erreur: sshpass n'est pas installé.${NC}"
    exit 1
fi

# Déterminer les IPs à traiter
if [ "$RESTORE_ALL" = true ]; then
    PUPITRE_IPS=("192.168.1.41" "192.168.1.42" "192.168.1.43" "192.168.1.44" "192.168.1.45" "192.168.1.46" "192.168.1.47")
elif [ -n "$SELECTED_PUPITRES" ]; then
    IFS=',' read -ra PUPITRE_IPS <<< "$SELECTED_PUPITRES"
else
    echo -e "${RED}❌ Erreur: Spécifiez --all ou --pupitres \"IP1,IP2\"${NC}"
    echo "Usage: $0 [--all] [--pupitres \"IP1,IP2\"]"
    exit 1
fi

echo -e "${CYAN}Pupitres à restaurer: ${#PUPITRE_IPS[@]}${NC}"
for ip in "${PUPITRE_IPS[@]}"; do
    echo "   • $ip"
done
echo ""

# Compteurs
success=0
failed=0

# Restaurer chaque pupitre
for ip in "${PUPITRE_IPS[@]}"; do
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🔄 Restauration sur: ${ip}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Restaurer depuis Git
    if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${ip} \
        "cd ~/dev/src/mecaviv-qml-ui && git checkout config.json"; then
        echo -e "${GREEN}✅ config.json restauré depuis Git${NC}"
        ((success++))
    else
        echo -e "${RED}❌ Échec de la restauration sur ${ip}${NC}"
        ((failed++))
    fi
    echo ""
done

# Résumé
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 Résumé de la restauration${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Total: ${#PUPITRE_IPS[@]} pupitres"
echo -e "${GREEN}Réussis: ${success}${NC}"
if [ ${failed} -gt 0 ]; then
    echo -e "${RED}Échoués: ${failed}${NC}"
fi
echo ""

if [ ${failed} -eq 0 ]; then
    echo -e "${GREEN}🎉 Tous les pupitres ont été restaurés !${NC}"
    echo -e "${YELLOW}💡 Vous pouvez maintenant relancer update-all-pupitres.sh avec le script corrigé${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Certains pupitres n'ont pas pu être restaurés.${NC}"
    exit 1
fi

