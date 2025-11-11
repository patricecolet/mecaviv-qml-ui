#!/bin/bash
# Script pour mettre à jour tous les pupitres
# Usage: ./scripts/update-all-pupitres.sh [OPTIONS]

set -e  # Arrêter en cas d'erreur

# Configuration par défaut
SSH_PASSWORD="SIRENS"
SERVER_USER="sirenateur"
REBOOT_AFTER_UPDATE=false
SELECTED_PUPITRES=""
EXCLUDED_PUPITRES=""
INTERACTIVE_MODE=false

# Fonction d'aide
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --password PASSWORD       Mot de passe SSH (défaut: SIRENS)"
    echo "  --reboot                  Redémarre les pupitres après mise à jour"
    echo "  --pupitres IPS            Met à jour uniquement les IPs spécifiées (séparées par des virgules)"
    echo "                            Exemple: --pupitres \"192.168.1.41,192.168.1.42\""
    echo "  --exclude IPS             Exclut les IPs spécifiées"
    echo "                            Exemple: --exclude \"192.168.1.47\""
    echo "  --interactive, -i         Mode interactif pour sélectionner les pupitres"
    echo "  --help, -h                Affiche cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0                                    # Tous les pupitres"
    echo "  $0 --pupitres \"192.168.1.41,192.168.1.42\"  # Pupitres spécifiques"
    echo "  $0 --exclude \"192.168.1.47\"                # Tous sauf un"
    echo "  $0 --interactive --reboot             # Mode interactif avec reboot"
}

# Gestion des arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --password)
      SSH_PASSWORD="$2"
      shift 2
      ;;
    --reboot)
      REBOOT_AFTER_UPDATE=true
      shift
      ;;
    --pupitres)
      SELECTED_PUPITRES="$2"
      shift 2
      ;;
    --exclude)
      EXCLUDED_PUPITRES="$2"
      shift 2
      ;;
    --interactive|-i)
      INTERACTIVE_MODE=true
      shift
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      echo "Option inconnue: $1"
      echo ""
      show_help
      exit 1
      ;;
  esac
done

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Gestion de l'interruption (Ctrl-C)
trap "echo; echo -e \"${RED}⛔ Opération interrompue par l'utilisateur.${NC}\"; exit 130" INT

# Fonction pour afficher le statut
print_status() {
    echo -e "${YELLOW}📤 $1${NC}"
}

# Fonction pour afficher le succès
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Fonction pour afficher l'erreur
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Fonction pour afficher l'info
print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Charger les IPs depuis SirenConsole/config.js
load_pupitre_ips() {
    local config_file="SirenConsole/config.js"
    
    if [ ! -f "$config_file" ]; then
        print_error "Fichier $config_file non trouvé"
        return 1
    fi
    
    # Extraire les IPs avec sed (compatible macOS)
    # On cherche les lignes "host:" dans la section pupitres (entre "pupitres: [" et le prochain "]")
    # Puis on supprime les doublons avec sort -u
    PUPITRE_IPS=($(sed -n '/pupitres:/,/^[[:space:]]*\]/p' "$config_file" | \
                   sed -n 's/.*host:[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p' | \
                   sort -u))
    
    if [ ${#PUPITRE_IPS[@]} -eq 0 ]; then
        print_error "Aucune IP trouvée dans $config_file"
        return 1
    fi
    
    return 0
}

# Fonction pour le mode interactif
interactive_select_pupitres() {
    echo -e "${BLUE}📋 Pupitres disponibles :${NC}"
    echo ""
    
    local i=1
    for ip in "${PUPITRE_IPS[@]}"; do
        echo -e "  ${CYAN}[$i]${NC} $ip"
        ((i++))
    done
    
    echo ""
    echo -e "${YELLOW}Sélectionnez les pupitres (exemples: 1,2,5 ou 1-3 ou 'all' pour tous):${NC}"
    read -r selection
    
    if [ "$selection" = "all" ] || [ "$selection" = "" ]; then
        return 0
    fi
    
    # Convertir la sélection en liste d'IPs
    local selected_ips=()
    IFS=',' read -ra SELECTIONS <<< "$selection"
    
    for sel in "${SELECTIONS[@]}"; do
        # Gérer les plages (ex: 1-3)
        if [[ $sel =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local start=${BASH_REMATCH[1]}
            local end=${BASH_REMATCH[2]}
            for ((j=start; j<=end; j++)); do
                if [ $j -le ${#PUPITRE_IPS[@]} ]; then
                    selected_ips+=("${PUPITRE_IPS[$((j-1))]}")
                fi
            done
        else
            # Sélection simple
            sel=$(echo "$sel" | xargs)  # Trim whitespace
            if [ $sel -le ${#PUPITRE_IPS[@]} ] && [ $sel -gt 0 ]; then
                selected_ips+=("${PUPITRE_IPS[$((sel-1))]}")
            fi
        fi
    done
    
    PUPITRE_IPS=("${selected_ips[@]}")
    
    if [ ${#PUPITRE_IPS[@]} -eq 0 ]; then
        print_error "Aucun pupitre sélectionné"
        exit 1
    fi
}

# Fonction pour filtrer les pupitres selon les options
filter_pupitres() {
    # Si des pupitres spécifiques sont demandés
    if [ -n "$SELECTED_PUPITRES" ]; then
        IFS=',' read -ra SELECTED_IPS <<< "$SELECTED_PUPITRES"
        local filtered=()
        for ip in "${SELECTED_IPS[@]}"; do
            ip=$(echo "$ip" | xargs)  # Trim whitespace
            if [[ " ${PUPITRE_IPS[*]} " =~ " ${ip} " ]]; then
                filtered+=("$ip")
            else
                print_error "IP $ip non trouvée dans la configuration"
            fi
        done
        PUPITRE_IPS=("${filtered[@]}")
    fi
    
    # Si des pupitres sont exclus
    if [ -n "$EXCLUDED_PUPITRES" ]; then
        IFS=',' read -ra EXCLUDED_IPS <<< "$EXCLUDED_PUPITRES"
        local filtered=()
        for ip in "${PUPITRE_IPS[@]}"; do
            local exclude=false
            for excluded_ip in "${EXCLUDED_IPS[@]}"; do
                excluded_ip=$(echo "$excluded_ip" | xargs)  # Trim whitespace
                if [ "$ip" = "$excluded_ip" ]; then
                    exclude=true
                    break
                fi
            done
            if [ "$exclude" = false ]; then
                filtered+=("$ip")
            fi
        done
        PUPITRE_IPS=("${filtered[@]}")
    fi
    
    if [ ${#PUPITRE_IPS[@]} -eq 0 ]; then
        print_error "Aucun pupitre à traiter après filtrage"
        exit 1
    fi
}

echo -e "${BLUE}🚀 Mise à jour de tous les pupitres${NC}"
echo ""

# Vérifier que nous sommes dans le bon répertoire
if [ ! -d "SirenePupitre/webfiles" ]; then
    echo -e "${RED}❌ Erreur: SirenePupitre/webfiles non trouvé. Exécutez ce script depuis la racine du projet mecaviv-qml-ui.${NC}"
    exit 1
fi

# Vérifier que sshpass est installé
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}❌ Erreur: sshpass n'est pas installé.${NC}"
    echo -e "${YELLOW}💡 Installation: brew install hudochenkov/sshpass/sshpass (macOS)${NC}"
    exit 1
fi

# Charger les IPs des pupitres depuis config.js
print_status "Chargement des IPs depuis SirenConsole/config.js..."
if ! load_pupitre_ips; then
    echo -e "${RED}❌ Erreur lors du chargement des IPs${NC}"
    exit 1
fi

# Appliquer les filtres (--pupitres ou --exclude)
filter_pupitres

# Mode interactif si demandé
if [ "$INTERACTIVE_MODE" = true ]; then
    interactive_select_pupitres
fi

echo -e "${GREEN}✅ ${#PUPITRE_IPS[@]} pupitre(s) sélectionné(s):${NC}"
for ip in "${PUPITRE_IPS[@]}"; do
    echo "   • $ip"
done
echo ""

# Fonction pour tester la connexion SSH
test_ssh_connection() {
    local host=$1
    sshpass -p"${SSH_PASSWORD}" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
        ${SERVER_USER}@${host} "echo 'OK'" &>/dev/null
    return $?
}

# Fonction pour mettre à jour un pupitre
update_pupitre() {
    local host=$1
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🎹 Mise à jour du pupitre: ${host}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Test de connexion
    print_status "Test de connexion à ${host}..."
    if ! test_ssh_connection ${host}; then
        print_error "Impossible de se connecter à ${host} (timeout ou refus)"
        return 1
    fi
    print_success "Connexion établie"
    
    # 1. Git pull puredata-abstractions
    print_status "Mise à jour de ~/dev/src/mecaviv/puredata-abstractions..."
    if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
        "cd ~/dev/src/mecaviv/puredata-abstractions && \
         GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no' git pull"; then
        print_success "puredata-abstractions mis à jour"
    else
        print_error "Échec du git pull puredata-abstractions sur ${host}"
        return 1
    fi
    
    # 2. Git pull mecaviv-qml-ui (commenté - non utilisé)
#    print_status "Mise à jour de ~/dev/src/mecaviv-qml-ui..."
#    if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
#        "cd ~/dev/src/mecaviv-qml-ui && \
#         GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no' git pull || \
#         (git checkout -- SirenePupitre/webfiles/* && git pull)"; then
#        print_success "mecaviv-qml-ui mis à jour"
#    else
#        print_error "Échec du git pull mecaviv-qml-ui sur ${host}"
#        return 1
#    fi
    
    # 3. Mise à jour et compilation des externals critapec si nécessaire
    print_status "Vérification des externals critapec..."
    
    # Git pull critapec-pd-externals
    if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
        "cd ~/dev/src/critapec-pd-externals && \
         GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no' git pull"; then
        print_success "critapec-pd-externals mis à jour"
    else
        print_error "Échec du git pull critapec-pd-externals sur ${host}"
        return 1
    fi
    
    # Vérifier si une recompilation est nécessaire
    print_status "Vérification de la synchronisation des externals..."
    NEEDS_BUILD=$(sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
        'cd ~/dev/src/critapec-pd-externals && \
         src_time=$(find . -name "*.c" -o -name "*.cpp" 2>/dev/null | xargs -r stat -c "%Y" 2>/dev/null | sort -n | tail -1) && \
         if [ -d ~/pd-externals/critapec ]; then \
             bin_time=$(find ~/pd-externals/critapec -name "*.pd_linux" -o -name "*.so" 2>/dev/null | xargs -r stat -c "%Y" 2>/dev/null | sort -n | tail -1); \
         else \
             bin_time=0; \
         fi && \
         if [ -z "$src_time" ]; then src_time=0; fi && \
         if [ -z "$bin_time" ]; then bin_time=0; fi && \
         if [ "$src_time" -gt "$bin_time" ]; then \
             echo "REBUILD"; \
         else \
             echo "OK"; \
         fi')
    
    if [ "$NEEDS_BUILD" = "REBUILD" ]; then
        print_status "Compilation des externals critapec..."
        if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
            "cd ~/dev/src/critapec-pd-externals && \
             for dir in */; do \
                 if [ -f \"\${dir}Makefile\" ]; then \
                     echo \"Building \$dir...\" && \
                     cd \"\$dir\" && make && cd .. || exit 1; \
                 fi; \
             done"; then
            print_success "Externals compilés"
        else
            print_error "Échec de la compilation des externals sur ${host}"
            return 1
        fi
        
        print_status "Installation des externals et help patches..."
        if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
            "mkdir -p ~/pd-externals/critapec && \
             cd ~/dev/src/critapec-pd-externals && \
             find . \( -name '*.pd_linux' -o -name '*.so' \) -exec cp {} ~/pd-externals/critapec/ \; && \
             find . -name '*-help.pd' -exec cp {} ~/pd-externals/critapec/ \;"; then
            print_success "Externals et help patches installés"
        else
            print_error "Échec de l'installation des externals sur ${host}"
            return 1
        fi
    else
        print_success "Externals critapec déjà à jour"
    fi
    
    # 4. Rsync webfiles
    print_status "Rsync de SirenePupitre/webfiles..."
    if sshpass -p"${SSH_PASSWORD}" rsync -avz -e "ssh -o StrictHostKeyChecking=no" \
        SirenePupitre/webfiles/ ${SERVER_USER}@${host}:~/dev/src/mecaviv-qml-ui/SirenePupitre/webfiles/; then
        print_success "webfiles synchronisé"
    else
        print_error "Échec du rsync webfiles sur ${host}"
        return 1
    fi
    
    # 5. Reboot si demandé
    if [ "$REBOOT_AFTER_UPDATE" = true ]; then
        print_status "Redémarrage du pupitre ${host}..."
        if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
            "sudo reboot" &>/dev/null; then
            print_success "Pupitre ${host} redémarré (il sera de nouveau opérationnel dans 1-2 minutes)"
        else
            print_error "Échec du redémarrage sur ${host}"
            return 1
        fi
    fi
    
    print_success "Pupitre ${host} mis à jour avec succès !"
    return 0
}

# Compteurs
total=${#PUPITRE_IPS[@]}
success=0
failed=0
failed_ips=()

# Mettre à jour chaque pupitre
for ip in "${PUPITRE_IPS[@]}"; do
    if update_pupitre ${ip}; then
        ((success++))
    else
        ((failed++))
        failed_ips+=("${ip}")
    fi
done

# Résumé final
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 Résumé de la mise à jour${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Total: ${total} pupitres"
echo -e "${GREEN}Réussis: ${success}${NC}"
if [ ${failed} -gt 0 ]; then
    echo -e "${RED}Échoués: ${failed}${NC}"
    echo -e "${RED}IPs en échec:${NC}"
    for ip in "${failed_ips[@]}"; do
        echo -e "  • ${ip}"
    done
else
    echo -e "${GREEN}Aucun échec ✨${NC}"
fi

if [ "$REBOOT_AFTER_UPDATE" = true ]; then
    echo -e "${YELLOW}🔄 Les pupitres ont été redémarrés (délai de 1-2 minutes)${NC}"
fi
echo ""

if [ ${failed} -eq 0 ]; then
    if [ "$REBOOT_AFTER_UPDATE" = true ]; then
        echo -e "${GREEN}🎉 Tous les pupitres ont été mis à jour et redémarrés avec succès !${NC}"
    else
        echo -e "${GREEN}🎉 Tous les pupitres ont été mis à jour avec succès !${NC}"
    fi
    exit 0
else
    echo -e "${YELLOW}⚠️  Certains pupitres n'ont pas pu être mis à jour.${NC}"
    exit 1
fi

