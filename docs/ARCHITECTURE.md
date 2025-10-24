# Architecture Mecaviv

## 🏗️ Composants

### 1. **config.json** (Source Unique)
- **Sirènes physiques** : S1, S2, S3, S4, S5, S6, S7
- **Caractéristiques** : ambitus, clef, transposition, outputs
- **Serveurs** : WebSocket (10002), API (8001)

### 2. **SirenConsole** (Interface de Contrôle)
- **Rôle** : Interface de contrôle centralisée
- **Données** : Adresses réseau des pupitres uniquement
- **Communication** : WebSocket vers pupitres (port 10001)

### 3. **SirenePupitre** (Pupitres Physiques)
- **Rôle** : Application sur chaque pupitre
- **Données** : Chargées depuis `config.json`
- **Communication** : WebSocket vers SirenConsole

### 4. **PureData** (Exécution)
- **Rôle** : Routage MIDI et communication sirènes
- **Port** : 10002 (WebSocket)

## 🔄 Flux de Données

```
config.json → Serveur API → SirenConsole → SirenePupitre → PureData → Sirènes
```

## ⚠️ Règles

1. **Pas de duplication** : Données sirènes uniquement dans `config.json`
2. **SirenConsole** : Uniquement adresses réseau + interface
3. **SirenePupitre** : Charge config depuis `config.json`
4. **Source unique** : `config.json` = vérité absolue