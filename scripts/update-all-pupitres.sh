#!/bin/bash
# Script pour mettre à jour tous les pupitres
# Usage: ./scripts/update-all-pupitres.sh [OPTIONS]

set -e  # Arrêter en cas d'erreur

# Configuration par défaut
SSH_PASSWORD="SIRENS"
SERVER_USER="sirenateur"
CRITAPEC_REPO_URL="https://github.com/patricecolet/critapec-pd-externals.git"
REBOOT_AFTER_UPDATE=false
SELECTED_PUPITRES=""
EXCLUDED_PUPITRES=""
INTERACTIVE_MODE=false
BUILD_COMPOSESIREN=false
BUILD_ONLY=false
DEPLOY_COMPOSESIREN=false
COMPOSESIREN_DEB=""
BUILDER_IP=""

# Fonction d'aide
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --password PASSWORD       Mot de passe SSH (défaut: SIRENS)"
    echo "  --reboot                  Redémarre les pupitres après mise à jour"
    echo "  --pupitres IPS            Met à jour uniquement les IPs spécifiées (séparées par des virgules)"
    echo "                            Les IPs peuvent être hors config (ex: 10.14.14.144)"
    echo "                            Exemple: --pupitres \"192.168.1.41,10.14.14.144\""
    echo "  --exclude IPS             Exclut les IPs spécifiées"
    echo "                            Exemple: --exclude \"192.168.1.47\""
    echo "  --interactive, -i         Mode interactif pour sélectionner les pupitres"
    echo "  --build-composesiren      Compile et package ComposeSiren sur un Raspberry sélectionné"
    echo "  --build-only              Compile uniquement ComposeSiren (implique --build-composesiren)"
    echo "  --deploy-composesiren     Déploie ComposeSiren sur les pupitres sélectionnés"
    echo "  --composesiren-deb PATH   Utilise ce package .deb pour l'installation (active le déploiement)"
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
    --build-composesiren)
      BUILD_COMPOSESIREN=true
      shift
      ;;
    --build-only)
      BUILD_COMPOSESIREN=true
      BUILD_ONLY=true
      shift
      ;;
    --deploy-composesiren)
      DEPLOY_COMPOSESIREN=true
      shift
      ;;
    --composesiren-deb)
      COMPOSESIREN_DEB="$2"
      DEPLOY_COMPOSESIREN=true
      shift 2
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

# Normaliser le chemin du package ComposeSiren si fourni
if [ -n "$COMPOSESIREN_DEB" ]; then
    if [ ! -f "$COMPOSESIREN_DEB" ]; then
        print_error "Package ComposeSiren introuvable: $COMPOSESIREN_DEB"
        exit 1
    fi
    COMPOSESIREN_DEB="$(cd "$(dirname "$COMPOSESIREN_DEB")" && pwd)/$(basename "$COMPOSESIREN_DEB")"
    print_info "Package ComposeSiren : $COMPOSESIREN_DEB"
fi

# Fonction pour sélectionner un builder (utilisé avec --build-composesiren)
select_builder() {
    echo -e "${BLUE}🛠️ Sélection du Raspberry builder :${NC}"
    echo ""
    local i=1
    for ip in "${PUPITRE_IPS[@]}"; do
        echo -e "  ${CYAN}[$i]${NC} $ip"
        ((i++))
    done
    echo ""
    echo -e "${YELLOW}Choisissez le builder (1 par défaut, Entrée pour continuer) :${NC}"
    read -r selection
    if [ -z "$selection" ]; then
        selection=1
    fi
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#PUPITRE_IPS[@]} ]; then
        print_info "Sélection invalide, utilisation du premier pupitre de la liste."
        selection=1
    fi
    BUILDER_IP=${PUPITRE_IPS[$((selection-1))]}
    echo ""
    print_info "Builder sélectionné : ${BUILDER_IP}"
}

# Fonction pour lancer la compilation/package ComposeSiren sur un Raspberry dédié
build_composesiren_on() {
    local host=$1
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🛠️ Build ComposeSiren sur: ${host}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    print_status "Test de connexion à ${host}..."
    if ! test_ssh_connection ${host}; then
        print_error "Impossible de se connecter à ${host} (timeout ou refus)"
        return 1
    fi
    print_success "Connexion builder établie"
    
    print_status "Mise à jour de ~/dev/src/ComposeSiren..."
    if ! sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
        "cd ~/dev/src/ComposeSiren && \
         GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no' git pull"; then
        print_error "Échec du git pull ComposeSiren sur ${host}"
        return 1
    fi
    print_success "Repository ComposeSiren mis à jour"
    
    print_status "Compilation et packaging ComposeSiren..."
    if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
        "cd ~/dev/src/ComposeSiren && ./scripts/deploy-raspberry.sh"; then
        print_success "Build ComposeSiren terminé"
    else
        print_error "Échec du déploiement/packaging ComposeSiren sur ${host}"
        return 1
    fi
    
    return 0
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
            [ -z "$ip" ] && continue
            if [[ " ${PUPITRE_IPS[*]} " =~ " ${ip} " ]]; then
                filtered+=("$ip")
            else
                # IP non présente dans config.js : on l'accepte quand même (pupitre hors config)
                if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    print_info "IP $ip non dans la config, utilisation directe"
                    filtered+=("$ip")
                else
                    print_error "IP invalide: $ip"
                fi
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

# Étape optionnelle de build ComposeSiren
if [ "$BUILD_COMPOSESIREN" = true ]; then
    if [ ${#PUPITRE_IPS[@]} -eq 0 ]; then
        print_error "Aucun pupitre disponible pour sélectionner un builder"
        exit 1
    fi
    
    select_builder
    if ! build_composesiren_on "$BUILDER_IP"; then
        print_error "Échec de la phase build ComposeSiren"
        exit 1
    fi
    
    echo ""
    print_success "Phase build ComposeSiren terminée avec succès"
    echo ""
    
    if [ "$BUILD_ONLY" = true ]; then
        print_info "Mode build-only demandé : fin du script après la compilation."
        exit 0
    elif [ "$DEPLOY_COMPOSESIREN" != true ]; then
        print_info "Build réalisé. Ajoutez --deploy-composesiren ou --composesiren-deb pour installer ComposeSiren."
    fi
fi

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
    
    # 2. Git pull compositions (fichiers MIDI)
    print_status "Mise à jour de ~/dev/src/mecaviv/compositions..."
    if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
        "cd ~/dev/src/mecaviv/compositions && \
         GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no' git pull"; then
        print_success "compositions mis à jour"
    else
        print_error "Échec du git pull compositions sur ${host}"
        return 1
    fi
    
    if [ "$DEPLOY_COMPOSESIREN" = true ]; then
        # 3. Git pull ComposeSiren
        print_status "Mise à jour de ~/dev/src/ComposeSiren..."
        if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
            "cd ~/dev/src/ComposeSiren && \
             GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no' git pull"; then
            print_success "ComposeSiren mis à jour"
        else
            print_error "Échec du git pull ComposeSiren sur ${host}"
            return 1
        fi
        
        # 3. Installation ComposeSiren via package
        if [ -n "$COMPOSESIREN_DEB" ]; then
            local remote_deb="/tmp/$(basename "$COMPOSESIREN_DEB")"
            
            print_status "Transfert du package ComposeSiren..."
            if ! sshpass -p"${SSH_PASSWORD}" scp -o StrictHostKeyChecking=no "$COMPOSESIREN_DEB" ${SERVER_USER}@${host}:"$remote_deb"; then
                print_error "Échec du transfert du package ComposeSiren sur ${host}"
                return 1
            fi
            print_success "Package transféré"
            
            print_status "Installation de ComposeSiren depuis le package..."
            local install_cmd="sudo dpkg -i '$remote_deb' || (sudo apt-get install -f -y && sudo dpkg -i '$remote_deb')"
            if ! sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} "$install_cmd"; then
                print_error "Échec de l'installation ComposeSiren sur ${host}"
                return 1
            fi
            print_success "ComposeSiren installé via dpkg"
            
            print_status "Nettoyage du package temporaire..."
            sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} "rm -f '$remote_deb'" &>/dev/null || true
        else
            print_status "Déploiement de ComposeSiren sur ${host}..."
            if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
                "cd ~/dev/src/ComposeSiren && ./scripts/deploy-raspberry.sh"; then
                print_success "ComposeSiren déployé"
            else
                print_error "Échec du déploiement ComposeSiren sur ${host}"
                return 1
            fi
        fi
    else
        print_info "ComposeSiren non déployé (ajoutez --deploy-composesiren pour l'activer)."
    fi
    
    # 4. Git pull mecaviv-qml-ui (commenté - non utilisé)
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
    
    # 5. Préparation GPIO pour les externals critapec
    print_status "Vérification de libgpiod..."
    if ! sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
        "dpkg -s libgpiod2 >/dev/null 2>&1"; then
        print_info "libgpiod2 absent, installation en cours..."
    fi
    if ! sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
        "dpkg -s libgpiod-dev >/dev/null 2>&1"; then
        print_info "libgpiod-dev absent, installation en cours..."
    fi
    if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
        "sudo apt-get update && sudo apt-get install -y libgpiod2 libgpiod-dev"; then
        print_success "libgpiod/libgpiod-dev installés"
    else
        print_error "Impossible d'installer libgpiod/libgpiod-dev sur ${host}"
        return 1
    fi

    print_status "Ajout de ${SERVER_USER} au groupe gpio..."
    if ! sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
        "getent group gpio >/dev/null 2>&1 || sudo groupadd gpio"; then
        print_error "Impossible de créer/vérifier le groupe gpio sur ${host}"
        return 1
    fi
    if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
        "sudo usermod -aG gpio ${SERVER_USER}"; then
        print_success "${SERVER_USER} appartient au groupe gpio (reboot nécessaire pour prise en compte)"
    else
        print_error "Impossible d'ajouter ${SERVER_USER} au groupe gpio sur ${host}"
        return 1
    fi

    print_status "Configuration des pull-ups GPIO (15/22/24)..."
    if ! sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
        "command -v pinctrl >/dev/null 2>&1"; then
        print_error "pinctrl introuvable sur ${host} (Pi 5 requis)."
        return 1
    fi
    if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
        "sudo pinctrl set 15 pu && sudo pinctrl set 22 pu && sudo pinctrl set 24 pu"; then
        print_success "Pull-ups configurés sur 15 (switch), 22 (A), 24 (B)"
    else
        print_error "Échec de la configuration pinctrl sur ${host}"
        return 1
    fi

    print_status "Vérification des externals critapec..."
    
    # Vérifier si c'est un dépôt Git valide, sinon supprimer et cloner
    if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
        "[ -d ~/dev/src/critapec-pd-externals/.git ]"; then
        # C'est un dépôt Git valide, faire un pull
        print_status "Mise à jour de critapec-pd-externals..."
        if ! sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
            "cd ~/dev/src/critapec-pd-externals && \
             GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no' git pull"; then
            print_error "Échec du git pull critapec-pd-externals sur ${host}"
            return 1
        fi
        print_success "critapec-pd-externals mis à jour"
    else
        # Le répertoire existe mais n'est pas un dépôt Git valide, ou n'existe pas
        if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
            "[ -d ~/dev/src/critapec-pd-externals ]"; then
            print_status "Suppression de l'ancien répertoire critapec-pd-externals..."
            sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
                "rm -rf ~/dev/src/critapec-pd-externals"
        fi
        print_status "Clonage de critapec-pd-externals..."
        if ! sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
            "mkdir -p ~/dev/src && cd ~/dev/src && \
             GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no' git clone ${CRITAPEC_REPO_URL} critapec-pd-externals"; then
            print_error "Échec du clone critapec-pd-externals sur ${host}"
            return 1
        fi
        print_success "critapec-pd-externals cloné"
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
         elif [ ! -f ~/pd-externals/critapec/rpi_encoder_step.pd_linux ]; then \
             echo "REBUILD"; \
         else \
             echo "OK"; \
         fi')
    
    if [ "$NEEDS_BUILD" = "REBUILD" ]; then
        print_status "Compilation des externals critapec..."
        
        # Fonction pour compiler avec gestion des erreurs de dépendances
        compile_externals() {
            local max_attempts=2
            local attempt=1
            
            while [ $attempt -le $max_attempts ]; do
                if [ $attempt -gt 1 ]; then
                    print_status "Tentative $attempt/$max_attempts de compilation..."
                fi
                
                # Capturer la sortie de compilation pour analyser les erreurs
                local build_output=$(sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
            "cd ~/dev/src/critapec-pd-externals && \
             for dir in */; do \
                 if [ -f \"\${dir}Makefile\" ]; then \
                     echo \"Building \$dir...\" && \
                             cd \"\$dir\" && make clean >/dev/null 2>&1 && make 2>&1 && cd .. || (cd .. && exit 1); \
                         fi; \
                     done" 2>&1)
                
                local build_status=$?
                
                if [ $build_status -eq 0 ]; then
            print_success "Externals compilés"
                    return 0
                fi
                
                # Analyser les erreurs pour détecter les bibliothèques manquantes
                local missing_libs=""
                local missing_headers=""
                
                # Détecter les erreurs de bibliothèques manquantes (-lxxx)
                if echo "$build_output" | grep -qE "cannot find -l[a-zA-Z0-9_-]+"; then
                    missing_libs=$(echo "$build_output" | grep -oE "cannot find -l[a-zA-Z0-9_-]+" | \
                        sed 's/cannot find -l//' | sort -u | tr '\n' ' ')
                fi
                
                # Détecter les erreurs de headers manquants
                if echo "$build_output" | grep -qE "fatal error: [a-zA-Z0-9_/-]+\.h: No such file or directory"; then
                    missing_headers=$(echo "$build_output" | grep -oE "fatal error: [a-zA-Z0-9_/-]+\.h" | \
                        sed 's/fatal error: //' | sed 's/\.h$//' | sort -u | tr '\n' ' ')
                fi
                
                # Si c'est la première tentative et qu'on a détecté des dépendances manquantes
                if [ $attempt -eq 1 ] && ([ -n "$missing_libs" ] || [ -n "$missing_headers" ]); then
                    print_info "Dépendances manquantes détectées"
                    if [ -n "$missing_libs" ]; then
                        print_status "Bibliothèques manquantes: $missing_libs"
                    fi
                    if [ -n "$missing_headers" ]; then
                        print_status "Headers manquants: $missing_headers"
                    fi
                    
                    # Installer les packages de développement courants
                    print_status "Installation des dépendances de développement..."
                    local packages_to_install="build-essential pkg-config"
                    
                    # Mapper les bibliothèques courantes aux packages Debian/Ubuntu
                    for lib in $missing_libs; do
                        case $lib in
                            gpiod|gpiod2)
                                packages_to_install="$packages_to_install libgpiod-dev"
                                ;;
                            alsa)
                                packages_to_install="$packages_to_install libasound2-dev"
                                ;;
                            jack)
                                packages_to_install="$packages_to_install libjack-jackd2-dev"
                                ;;
                            *)
                                # Essayer de deviner le package (libxxx-dev)
                                packages_to_install="$packages_to_install lib${lib}-dev"
                                ;;
                        esac
                    done
                    
                    # Mapper les headers aux packages
                    for header in $missing_headers; do
                        case $header in
                            gpiod)
                                packages_to_install="$packages_to_install libgpiod-dev"
                                ;;
                            alsa|alsa/asoundlib)
                                packages_to_install="$packages_to_install libasound2-dev"
                                ;;
                            jack/jack)
                                packages_to_install="$packages_to_install libjack-jackd2-dev"
                                ;;
                        esac
                    done
                    
                    # Supprimer les doublons
                    packages_to_install=$(echo "$packages_to_install" | tr ' ' '\n' | sort -u | tr '\n' ' ')
                    
                    print_status "Installation: $packages_to_install"
                    if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
                        "sudo apt-get update && sudo apt-get install -y $packages_to_install"; then
                        print_success "Dépendances installées"
                        ((attempt++))
                        continue
                    else
                        print_error "Échec de l'installation des dépendances"
                        # Afficher l'erreur de compilation pour diagnostic
                        echo -e "${YELLOW}Sortie de compilation:${NC}"
                        echo "$build_output" | tail -20
                        return 1
                    fi
                else
                    # Deuxième tentative échouée ou erreur non liée aux dépendances
            print_error "Échec de la compilation des externals sur ${host}"
                    echo -e "${YELLOW}Sortie de compilation:${NC}"
                    echo "$build_output" | tail -30
                    return 1
                fi
            done
            
            return 1
        }
        
        if ! compile_externals; then
            return 1
        fi
        
        print_status "Installation des externals et help patches..."
        if sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
            "mkdir -p ~/pd-externals/critapec && \
             cd ~/dev/src/critapec-pd-externals && \
             find . \( -name '*.pd_linux' -o -name '*.so' \) -exec cp {} ~/pd-externals/critapec/ \; && \
             find . -name '*-help.pd' -exec cp {} ~/pd-externals/critapec/ \;"; then
            print_success "Externals et help patches installés"
            if ! sshpass -p"${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${host} \
                "[ -f ~/pd-externals/critapec/rpi_encoder_step.pd_linux ]"; then
                print_error "rpi_encoder_step.pd_linux introuvable après installation"
                return 1
            fi
        else
            print_error "Échec de l'installation des externals sur ${host}"
            return 1
        fi
    else
        print_success "Externals critapec déjà à jour"
    fi
    
    # 6. Rsync webfiles
    print_status "Rsync de SirenePupitre/webfiles..."
    if sshpass -p"${SSH_PASSWORD}" rsync -avz -e "ssh -o StrictHostKeyChecking=no" \
        SirenePupitre/webfiles/ ${SERVER_USER}@${host}:~/dev/src/mecaviv-qml-ui/SirenePupitre/webfiles/; then
        print_success "webfiles synchronisé"
    else
        print_error "Échec du rsync webfiles sur ${host}"
        return 1
    fi
    
    # 7. Rsync scripts (start-raspberry.sh, etc.)
    print_status "Rsync de SirenePupitre/scripts..."
    if sshpass -p"${SSH_PASSWORD}" rsync -avz -e "ssh -o StrictHostKeyChecking=no" \
        SirenePupitre/scripts/ ${SERVER_USER}@${host}:~/dev/src/mecaviv-qml-ui/SirenePupitre/scripts/; then
        print_success "scripts synchronisés"
    else
        print_error "Échec du rsync scripts sur ${host}"
        return 1
    fi
    
    # 8. Reboot si demandé
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

