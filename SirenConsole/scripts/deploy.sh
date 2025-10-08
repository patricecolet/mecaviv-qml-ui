#!/bin/bash

# Script de déploiement pour SirenConsole
# Usage: ./scripts/deploy.sh [target] [options]

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
TARGET=${1:-"local"}
BUILD_TYPE=${2:-"desktop"}
CLEAN_BUILD=${3:-"false"}

print_status "Déploiement de SirenConsole"
print_status "Cible: $TARGET"
print_status "Type de build: $BUILD_TYPE"
echo ""

# Fonction pour déployer localement
deploy_local() {
    print_status "Déploiement local..."
    
    # Build du projet
    print_status "Build du projet..."
    ./scripts/build.sh $BUILD_TYPE $CLEAN_BUILD
    
    if [ $? -eq 0 ]; then
        print_success "Build réussi"
        
        # Créer un lien symbolique pour faciliter l'accès
        if [ -L "SirenConsole" ]; then
            rm SirenConsole
        fi
        
        if [ "$BUILD_TYPE" = "web" ]; then
            ln -s build/SirenConsole_web SirenConsole
        else
            ln -s build/SirenConsole SirenConsole
        fi
        
        print_success "Lien symbolique créé: ./SirenConsole"
        print_status "Pour lancer: ./SirenConsole"
    else
        print_error "Échec du build"
        exit 1
    fi
}

# Fonction pour déployer sur un serveur distant
deploy_remote() {
    local server=$1
    local user=${2:-"sirenateur"}
    local path=${3:-"/home/sirenateur/SirenConsole"}
    
    print_status "Déploiement sur serveur distant: $server"
    
    # Build local
    print_status "Build local..."
    ./scripts/build.sh $BUILD_TYPE $CLEAN_BUILD
    
    if [ $? -ne 0 ]; then
        print_error "Échec du build local"
        exit 1
    fi
    
    # Synchronisation des fichiers
    print_status "Synchronisation des fichiers..."
    rsync -avz --delete \
        --exclude='build/' \
        --exclude='.git/' \
        --exclude='*.log' \
        ./ $user@$server:$path/
    
    if [ $? -eq 0 ]; then
        print_success "Synchronisation réussie"
        
        # Build sur le serveur distant
        print_status "Build sur le serveur distant..."
        ssh $user@$server "cd $path && ./scripts/build.sh $BUILD_TYPE"
        
        if [ $? -eq 0 ]; then
            print_success "Déploiement distant réussi"
        else
            print_error "Échec du build distant"
            exit 1
        fi
    else
        print_error "Échec de la synchronisation"
        exit 1
    fi
}

# Fonction pour créer un package de déploiement
create_package() {
    local package_name="SirenConsole-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    print_status "Création du package: $package_name"
    
    # Build du projet
    ./scripts/build.sh $BUILD_TYPE $CLEAN_BUILD
    
    if [ $? -ne 0 ]; then
        print_error "Échec du build"
        exit 1
    fi
    
    # Créer le package
    tar -czf $package_name \
        --exclude='build/' \
        --exclude='.git/' \
        --exclude='*.log' \
        --exclude='*.tar.gz' \
        .
    
    if [ $? -eq 0 ]; then
        print_success "Package créé: $package_name"
        print_status "Pour déployer: tar -xzf $package_name && ./scripts/build.sh"
    else
        print_error "Échec de la création du package"
        exit 1
    fi
}

# Traitement selon la cible
case $TARGET in
    "local")
        deploy_local
        ;;
    "remote")
        if [ -z "$2" ]; then
            print_error "Adresse du serveur requise pour le déploiement distant"
            print_status "Usage: ./scripts/deploy.sh remote <server> [user] [path]"
            exit 1
        fi
        deploy_remote $2 $3 $4
        ;;
    "package")
        create_package
        ;;
    *)
        print_error "Cible de déploiement non supportée: $TARGET"
        print_status "Cibles supportées: local, remote, package"
        exit 1
        ;;
esac

print_success "Déploiement terminé avec succès!"
