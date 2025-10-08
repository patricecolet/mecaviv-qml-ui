# Guide de Déploiement SirenConsole

## 🚀 Déploiement Local

### Prérequis
- Qt6 (version 6.5 ou supérieure)
- CMake (version 3.20 ou supérieure)
- Compilateur C++17
- Node.js (version 16 ou supérieure) - Pour l'API REST des presets
- npm (pour installer les dépendances)

### Installation des dépendances

#### macOS
```bash
# Installer Qt6 via Homebrew
brew install qt6

# Installer Node.js
brew install node

# Ou télécharger depuis qt.io
# https://www.qt.io/download-qt-installer
```

#### Linux (Ubuntu/Debian)
```bash
# Installer Qt6
sudo apt update
sudo apt install qt6-base-dev qt6-declarative-dev qt6-websockets-dev

# Installer CMake
sudo apt install cmake build-essential

# Installer Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

#### Windows
1. Installer Qt6 depuis [qt.io](https://www.qt.io/download-qt-installer)
2. Installer CMake depuis [cmake.org](https://cmake.org/download/)
3. Installer Visual Studio ou MinGW
4. Installer Node.js depuis [nodejs.org](https://nodejs.org/)

### Build et déploiement
```bash
# Cloner le projet
git clone <repository-url>
cd SirenConsole

# Installer les dépendances Node.js
cd webfiles
npm install
cd ..

# Build
./scripts/build.sh

# Lancer
./build/SirenConsole
```

## 🌐 Déploiement Web

### Build pour le web
```bash
# Installer les dépendances Node.js
cd webfiles
npm install
cd ..

# Build web
./scripts/build.sh web

# Lancer le serveur avec API REST
cd webfiles
node server.js

# Ouvrir http://localhost:8001
```

### API REST des Presets
Le serveur web inclut une API REST pour la gestion des presets :

```bash
# Test de l'API
curl http://localhost:8001/api/presets

# Créer un preset
curl -X POST http://localhost:8001/api/presets \
  -H "Content-Type: application/json" \
  -d '{"name": "Test", "description": "Preset de test", "pupitres": []}'

# Récupérer un preset
curl http://localhost:8001/api/presets/preset_001

# Supprimer un preset
curl -X DELETE http://localhost:8001/api/presets/preset_001
```

**Endpoints disponibles :**
- `GET /api/presets` - Liste tous les presets
- `GET /api/presets/:id` - Récupère un preset spécifique
- `POST /api/presets` - Crée un nouveau preset
- `PUT /api/presets/:id` - Met à jour un preset
- `DELETE /api/presets/:id` - Supprime un preset

### Déploiement sur serveur web
```bash
# Créer un package
./scripts/deploy.sh package

# Transférer sur le serveur
scp SirenConsole-*.tar.gz user@server:/var/www/html/

# Décompresser sur le serveur
ssh user@server "cd /var/www/html && tar -xzf SirenConsole-*.tar.gz"
```

## 🖥️ Déploiement sur Raspberry Pi

### Préparation du Raspberry Pi
```bash
# Mettre à jour le système
sudo apt update && sudo apt upgrade -y

# Installer Qt6
sudo apt install qt6-base-dev qt6-declarative-dev qt6-websockets-dev

# Installer les dépendances de build
sudo apt install cmake build-essential git
```

### Déploiement automatique
```bash
# Depuis la machine de développement
./scripts/deploy.sh remote pi@192.168.1.100

# Ou créer un package
./scripts/deploy.sh package
scp SirenConsole-*.tar.gz pi@192.168.1.100:~/
```

### Configuration sur le Raspberry Pi
```bash
# Sur le Raspberry Pi
cd ~/SirenConsole
./scripts/build.sh
./build/SirenConsole
```

## 🐳 Déploiement Docker

### Dockerfile
```dockerfile
FROM ubuntu:22.04

# Installer les dépendances
RUN apt-get update && apt-get install -y \
    qt6-base-dev \
    qt6-declarative-dev \
    qt6-websockets-dev \
    cmake \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copier le code source
COPY . /app
WORKDIR /app

# Build
RUN ./scripts/build.sh

# Exposer le port
EXPOSE 8080

# Lancer l'application
CMD ["./build/SirenConsole"]
```

### Build et déploiement Docker
```bash
# Build l'image
docker build -t sirenconsole .

# Lancer le conteneur
docker run -p 8080:8080 sirenconsole
```

## ⚙️ Configuration

### Variables d'environnement
```bash
# Configuration réseau
export SIRENCONSOLE_BASE_IP=192.168.1
export SIRENCONSOLE_PORT=10001

# Configuration de l'interface
export SIRENCONSOLE_THEME=dark
export SIRENCONSOLE_LAYOUT=grid

# Configuration des logs
export SIRENCONSOLE_LOG_LEVEL=info
export SIRENCONSOLE_LOG_FILE=/var/log/sirenconsole.log
```

### Fichier de configuration
Modifier `config.js` pour adapter les paramètres :

```javascript
var configData = {
  "pupitres": [
    {
      "id": "1",
      "name": "Pupitre 1",
      "host": "192.168.1.101", // Adapter selon votre réseau
      "port": 10001,
      "enabled": true
    }
    // ... autres pupitres
  ]
}
```

## 🔧 Maintenance

### Mise à jour
```bash
# Sauvegarder la configuration
cp config.js config.js.backup

# Mettre à jour le code
git pull origin main

# Rebuild
./scripts/build.sh

# Restaurer la configuration si nécessaire
cp config.js.backup config.js
```

### Logs
```bash
# Voir les logs en temps réel
tail -f /var/log/sirenconsole.log

# Nettoyer les anciens logs
find /var/log -name "sirenconsole*.log" -mtime +30 -delete
```

### Monitoring
```bash
# Vérifier le statut
ps aux | grep SirenConsole

# Vérifier les connexions réseau
netstat -an | grep 10001

# Test de connectivité
./scripts/test-connections.sh
```

## 🚨 Dépannage

### Problèmes courants

#### Connexion WebSocket échouée
```bash
# Vérifier la connectivité réseau
ping 192.168.1.101

# Vérifier le port
telnet 192.168.1.101 10001

# Vérifier les logs
grep "WebSocket" /var/log/sirenconsole.log
```

#### Interface ne se charge pas
```bash
# Vérifier les permissions
ls -la build/SirenConsole

# Vérifier les dépendances
ldd build/SirenConsole

# Lancer en mode debug
QT_LOGGING_RULES="*=true" ./build/SirenConsole
```

#### Performance dégradée
```bash
# Vérifier l'utilisation CPU/mémoire
top -p $(pgrep SirenConsole)

# Vérifier les connexions réseau
ss -tuln | grep 10001

# Optimiser la configuration
# Réduire reconnectInterval dans config.js
```

### Support
- Logs détaillés : `QT_LOGGING_RULES="*=true"`
- Mode debug : `--debug` (si implémenté)
- Documentation : `docs/` directory
- Issues : GitHub Issues
