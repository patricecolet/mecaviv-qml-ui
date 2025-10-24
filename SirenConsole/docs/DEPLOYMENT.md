# Déploiement SirenConsole

## 🚀 Démarrage Rapide

```bash
# Build + Serveur + Chrome
./scripts/run.sh
```

## 🔧 Configuration

### 1. Vérifier les IPs
```bash
# Tester connectivité
./scripts/test-connections.sh 192.168.1
```

### 2. Configuration Pupitres
- **P1** : `192.168.1.41:10001`
- **P2** : `192.168.1.42:10001`
- **P3** : `192.168.1.43:10001`
- **P4** : `192.168.1.44:10001`
- **P5** : `192.168.1.45:10001`
- **P6** : `192.168.1.46:10001`
- **P7** : `192.168.1.47:10001`

## 📁 Structure

```
SirenConsole/
├── config.js              # Configuration réseau uniquement
├── webfiles/
│   ├── server.js          # Serveur Node.js
│   └── config.js          # Config web
├── QML/                    # Interface Qt
└── scripts/
    ├── run.sh             # Démarrage complet
    └── test-connections.sh # Test réseau
```

## ⚠️ Important

- **Ne pas dupliquer** les données de `config.json`
- **SirenConsole** = Interface de contrôle uniquement
- **Sirènes physiques** = Définies dans `config.json`