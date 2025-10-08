#!/bin/bash
# scripts/start-raspberry.sh

# Variables d'environnement pour crontab
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/home/sirenateur
export USER=sirenateur
export DISPLAY=:0

# Aller dans le répertoire du projet
cd /home/sirenateur/dev/src/mecaviv/patko-scratchpad/qtQmlSockets/SirenePupitre

# Logs
LOG_FILE="/home/sirenateur/sirene-boot.log"
exec 1>>$LOG_FILE 2>&1

echo "$(date): 🚀 Démarrage automatique SirenePupitre"

# Fichier de configuration IP
IP_CONFIG_FILE="/home/sirenateur/sirene-ip.txt"

# Configuration par défaut
DEFAULT_IP="192.168.1.100"
GATEWAY_IP="192.168.1.1"
DNS_SERVERS="8.8.8.8 8.8.4.4"

# Fonction pour lire l'IP depuis le fichier
get_configured_ip() {
    if [ -f "$IP_CONFIG_FILE" ]; then
        cat "$IP_CONFIG_FILE"
    else
        echo "$DEFAULT_IP"
    fi
}

# Fonction pour vérifier l'IP actuelle
check_current_ip() {
    local current_ip=$(ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    echo "$current_ip"
}

# Fonction pour configurer l'IP
configure_ip() {
    local desired_ip=$(get_configured_ip)
    local current_ip=$(check_current_ip)
    
    echo "$(date): 🔍 IP actuelle: $current_ip"
    echo "$(date): IP souhaitée: $desired_ip"
    
    if [ "$current_ip" = "$desired_ip" ]; then
        echo "$(date): ✅ IP correcte: $current_ip"
        return 0
    fi
    
    echo "$(date): 🔧 Configuration IP fixe..."
    
    # Attendre que les services réseau soient prêts
    sleep 10
    
    # Détecter le gestionnaire de réseau
    if systemctl is-active --quiet NetworkManager; then
        echo "$(date): 📡 Utilisation de NetworkManager"
        
        # Supprimer la connexion existante
        sudo nmcli con delete "SirenePupitre-Static" 2>/dev/null || true
        
        # Créer une connexion statique
        sudo nmcli con add type ethernet con-name "SirenePupitre-Static" ifname eth0 \
            ipv4.addresses $desired_ip/24 \
            ipv4.gateway $GATEWAY_IP \
            ipv4.dns "$DNS_SERVERS" \
            ipv4.method manual
        
        # Activer la connexion
        sudo nmcli con up "SirenePupitre-Static"
        echo "$(date): ✅ Configuration NetworkManager appliquée"
        
    elif systemctl is-active --quiet systemd-networkd; then
        echo "$(date): 📡 Utilisation de systemd-networkd"
        
        # Créer le fichier de configuration
        sudo tee /etc/systemd/network/10-static-eth0.network > /dev/null << EOF
[Match]
Name=eth0

[Network]
Address=$desired_ip/24
Gateway=$GATEWAY_IP
DNS=$DNS_SERVERS
EOF
        
        # Activer et redémarrer le service
        sudo systemctl enable systemd-networkd
        sudo systemctl restart systemd-networkd
        echo "$(date): ✅ Configuration systemd-networkd appliquée"
        
    else
        echo "$(date): ⚠️ Gestionnaire de réseau non reconnu"
        return 1
    fi
    
    # Attendre que la configuration soit appliquée
    sleep 10
    
    # Vérifier si l'IP est correcte
    local new_ip=$(check_current_ip)
    if [ "$new_ip" = "$desired_ip" ]; then
        echo "$(date): ✅ IP configurée avec succès: $new_ip"
        return 0
    else
        echo "$(date): 🔄 Redémarrage pour appliquer la configuration IP"
        sudo reboot
        exit 0
    fi
}

# Fonction pour arrêter les processus
stop_processes() {
    echo "$(date): Arrêt des processus..."
    
    pkill -f "node server.js" 2>/dev/null || true
    pkill -f "pd -nogui" 2>/dev/null || true
    pkill -f "chromium-browser" 2>/dev/null || true
    
    sleep 2
    echo "$(date): Tous les processus arrêtés"
}

# Fonction pour démarrer le serveur
start_server() {
    echo "$(date): Démarrage du serveur Node.js..."
    
    if [ ! -d "webfiles/" ]; then
        echo "$(date): ❌ Dossier webfiles/ non trouvé"
        return
    fi
    
    cd webfiles/
    node server.js &
    cd ..
    
    sleep 5
    
    # Vérifier si le serveur fonctionne
    local attempts=0
    while [ $attempts -lt 10 ]; do
        if curl -s http://localhost:8000 > /dev/null 2>&1; then
            echo "$(date): ✅ Serveur démarré sur le port 8000"
            return
        fi
        sleep 1
        attempts=$((attempts + 1))
    done
    
    echo "$(date): ❌ Le serveur n'a pas démarré"
}

# Fonction pour démarrer PureData
start_puredata() {
    echo "$(date): Démarrage de PureData..."
    
    PURE_DATA_DIR="/home/sirenateur/dev/src/mecaviv/patko-scratchpad/volant"
    PURE_DATA_PATCH="M645.pd"
    
    if [ -d "$PURE_DATA_DIR" ] && [ -f "$PURE_DATA_DIR/$PURE_DATA_PATCH" ]; then
        cd "$PURE_DATA_DIR"
        pd -nogui "$PURE_DATA_PATCH" &
        cd - > /dev/null
        echo "$(date): ✅ PureData démarré"
    else
        echo "$(date): ❌ PureData non trouvé"
    fi
}

# Fonction pour démarrer le navigateur
start_browser() {
    echo "$(date): Démarrage du navigateur..."
    
    # Attendre que le serveur soit prêt
    sleep 5
    
    if [ -n "$DISPLAY" ] && command -v chromium-browser >/dev/null 2>&1; then
        export DISPLAY=:0
        chromium-browser --kiosk --disable-web-security \
            "http://localhost:8000/appSirenePupitre.html" &
        echo "$(date): ✅ Navigateur démarré"
    else
        echo "$(date): ⚠️ Navigateur non démarré (X11 non disponible)"
    fi
}

# Fonction principale
main() {
    echo "$(date): === Démarrage SirenePupitre ==="
    
    # 1. Configurer l'IP
    configure_ip
    
    # 2. Arrêter les processus existants
    stop_processes
    
    # 3. Démarrer les services
    start_server
    start_puredata
    
    # 4. Démarrer le navigateur
    start_browser
    
    # 5. Afficher les informations
    local ip=$(get_configured_ip)
    echo "$(date): ✅ Application démarrée!"
    echo "$(date): 🌐 IP: $ip"
    echo "$(date): 🌐 Serveur: http://$ip:8000"
    
    # 6. Garder le script en vie
    while true; do
        sleep 60
    done
}

# Exécuter
main
