# 🎛️ Configuration MIDI - PedalierSirenium

> ## ⚠️ Document périmé — conservé à titre historique
>
> Ce document décrit une époque où le QML ouvrait ses propres ports MIDI virtuels. **Ce n'est plus le
> cas :**
>
> - `qmlmidi` a été abandonné pour la compatibilité WebAssembly ; l'application **n'ouvre aucun port
>   MIDI**. Tout le MIDI arrive de PureData par le WebSocket.
> - L'onglet « MIDI » du Debug Panel (sélection de ports IAC/VirMIDI) a été retiré comme obsolète —
>   et le panneau lui-même n'est plus atteignable (`DebugPanel` n'est instancié nulle part, le
>   raccourci `F12` n'ouvre rien).
> - Le canal binaire MIDI entrant est décodé par `MidiMonitorController` puis abandonné : aucun
>   composant vivant n'écoute `midiDataChanged`.
> - `webfiles/server.js` note seulement si l'API Web MIDI **existe** dans le navigateur, sans jamais
>   appeler `requestMIDIAccess()` — l'autorisation à chaque chargement était intenable en kiosque.
>
> Rien de ce qui suit n'est nécessaire pour faire tourner le pédalier aujourd'hui. Voir
> `architecture_communication.md` et le `README.md` pour l'état réel.

## 📋 Vue d'ensemble

Le système MIDI de PedalierSirenium utilise des **ports virtuels** pour permettre au monitoring QML de recevoir les données MIDI sans interférer avec PureData. La configuration varie selon le système d'exploitation.

## 🖥️ Configuration par système d'exploitation

### 🍎 macOS - Configuration manuelle

Sur macOS, le système utilise **IAC Driver** (Inter-Application Communication) pour les ports virtuels MIDI.

#### Prérequis
1. **Audio MIDI Setup** doit être configuré
2. **IAC Driver** doit être activé
3. **Bus IAC** doivent être créés

#### Configuration étape par étape

1. **Ouvrir Audio MIDI Setup**
   ```bash
   open -a "Audio MIDI Setup"
   ```

2. **Activer IAC Driver**
   - Menu `Window` > `Show MIDI Studio`
   - Double-cliquer sur `IAC Driver`
   - Cocher `Device is online`

3. **Créer des bus IAC** (optionnel)
   - Dans IAC Driver, cliquer sur `+` pour ajouter des bus
   - Nommer les bus (ex: "QML Monitoring", "PureData")

4. **Utiliser le gestionnaire de ports**
   ```bash
   ./scripts/midi_port_manager.sh enable-iac
   ./scripts/midi_port_manager.sh list
   ```

#### Utilisation dans QML
- Ouvrir l'application QML
- Appuyer sur `F12` pour le Debug Panel
- Aller à l'onglet **MIDI**
- Sélectionner manuellement le port IAC Driver
- Cliquer sur **Démarrer**

### 🐧 Linux - Configuration automatique

Sur Linux, le système utilise **VirMIDI** (Virtual Raw MIDI) pour les ports virtuels.

#### Prérequis
1. **Module snd_virmidi** doit être chargé
2. **Ports VirMIDI** doivent être disponibles

#### Configuration automatique

1. **Charger le module VirMIDI**
   ```bash
   sudo modprobe snd_virmidi
   ```

2. **Vérifier les ports disponibles**
   ```bash
   ./scripts/midi_port_manager.sh create-virtual
   ./scripts/midi_port_manager.sh list
   ```

3. **Lancer l'application QML**
   - La connexion se fait automatiquement au premier port disponible
   - Les ports VirMIDI 0-2 et 0-3 sont réservés pour QML
   - Les ports VirMIDI 0-0 et 0-1 sont utilisés par PureData

## 🛠️ Scripts de gestion

### `test_midi_connection.sh`
Script de test pour vérifier la connectivité MIDI.

```bash
# Test général
./scripts/test_midi_connection.sh

# Test d'un port spécifique
./scripts/test_midi_connection.sh 0
```

**Fonctionnalités :**
- Détection automatique du système d'exploitation
- Liste des ports MIDI disponibles
- Test des ports virtuels
- Vérification de la latence
- Recommandations spécifiques au système

### `midi_port_manager.sh`
Gestionnaire complet des ports MIDI.

```bash
# Afficher l'aide
./scripts/midi_port_manager.sh help

# Lister les ports
./scripts/midi_port_manager.sh list

# Afficher le statut
./scripts/midi_port_manager.sh status

# Connecter deux ports
./scripts/midi_port_manager.sh connect "IAC Driver Bus 1" "Pure Data Midi-In 1"

# Tester un port
./scripts/midi_port_manager.sh test 0

# Nettoyer toutes les connexions
./scripts/midi_port_manager.sh clean
```

**Actions disponibles :**
- `list` - Lister tous les ports MIDI
- `status` - Afficher le statut des connexions
- `connect <from> <to>` - Connecter deux ports MIDI
- `disconnect <from> <to>` - Déconnecter deux ports MIDI
- `create-virtual` - Créer des ports virtuels (Linux)
- `enable-iac` - Activer IAC Driver (macOS)
- `test <port>` - Tester un port spécifique
- `clean` - Nettoyer toutes les connexions

## 🔧 Configuration avancée

### Ports recommandés

#### macOS
- **IAC Driver Bus 1** : Monitoring QML principal
- **IAC Driver Bus 2** : Monitoring QML secondaire
- **IAC Driver Bus 3** : Tests et développement

#### Linux
- **VirMIDI 0-0** : PureData IN 1
- **VirMIDI 0-1** : PureData IN 2
- **VirMIDI 0-2** : QML Monitoring (recommandé)
- **VirMIDI 0-3** : QML Monitoring secondaire

### Flux de données MIDI

```
Contrôleurs MIDI USB
        ↓
   Ports virtuels
        ↓
      qmlmidi
        ↓
MidiMonitorController
        ↓
   SireniumMonitor
        ↓
    Partition 3D
```

### Messages MIDI supportés

- **Note On/Off** : Notes musicales avec vélocité
- **Pitch Bend** : Contrôle de hauteur (14-bit)
- **Control Change** : Contrôles continus
- **Program Change** : Changement de programme

## 🐛 Dépannage

### Problèmes courants

#### macOS
1. **IAC Driver non détecté**
   ```bash
   ./scripts/midi_port_manager.sh enable-iac
   ```

2. **Ports non visibles**
   - Vérifier qu'Audio MIDI Setup est ouvert
   - Redémarrer Audio MIDI Setup
   - Vérifier les permissions

#### Linux
1. **VirMIDI non disponible**
   ```bash
   sudo modprobe snd_virmidi
   ./scripts/midi_port_manager.sh create-virtual
   ```

2. **Permissions insuffisantes**
   ```bash
   sudo usermod -a -G audio $USER
   # Redémarrer la session
   ```

### Tests de diagnostic

```bash
# Test complet
./scripts/test_midi_connection.sh

# Vérifier les ports
./scripts/midi_port_manager.sh list

# Tester la connectivité
aconnect -l

# Vérifier les modules (Linux)
lsmod | grep snd_virmidi
```

## 📚 Ressources

- [Documentation ALSA](https://alsa-project.org/wiki/Main_Page)
- [CoreMIDI Documentation](https://developer.apple.com/documentation/coremidi)
- [qmlmidi Project](https://github.com/jarnoh/qmlmidi)
- [RtMidi Documentation](https://www.music.mcgill.ca/~gary/rtmidi/)

## 🔄 Mise à jour

Cette documentation est mise à jour avec chaque version du projet. Pour les dernières informations, consultez le README principal et les scripts de configuration.
