# Plan d'implémentation SirenManager

## Statut actuel
- ✅ Structure de base (CMakeLists.txt, main.cpp, Main.qml)
- ✅ 10 vues créées (stubs seulement)
- ✅ Configuration (SirenConfig, MachineType)
- ✅ UdpController (structure de base)
- ✅ Backend Node.js (server.js, ssh-proxy.js)

## À implémenter

### 1. Composants réutilisables
- [ ] SirenButton.qml - Bouton personnalisé pour sirènes
- [ ] PlaylistSlot.qml - Slot de playlist (48 slots)
- [ ] ClockDisplay.qml - Affichage de l'heure
- [ ] MachineSelector.qml - Sélecteur de machine
- [ ] MidiController.qml - Contrôleur MIDI

### 2. PlayerView (FirstViewController)
- [ ] Séquenceur MIDI (viewSeq)
- [ ] Contrôles play/stop/reset/boucle
- [ ] Index et mesure
- [ ] Synchronisation
- [ ] Slider de temps
- [ ] Support MIDI

### 3. MixerView (SecondViewController)
- [ ] Contrôleurs de volume S1-S8
- [ ] Sourdines S1-S7
- [ ] Timbre S5-S7
- [ ] LED S1-S8
- [ ] Volumes GN (haut/bas) S1-S7
- [ ] Presets LED
- [ ] Boutons Mute

### 4. MaintenanceView
- [ ] Sliders moteurs S1-S7
- [ ] Sliders clapets S1-S7
- [ ] Switches KEB S1-S7
- [ ] Switch ST et Trompe
- [ ] Transposition globale
- [ ] Table de listes

### 5. SystemMaintenanceView
- [ ] Sélection machine
- [ ] Affichage RAM/disque
- [ ] Logs dmesg avec filtres
- [ ] Gestion playlists (upload/download)

### 6. PlaylistComposerView
- [ ] 48 slots de playlist
- [ ] Liste fichiers MIDI disponibles
- [ ] Drag & drop
- [ ] Upload/download via SSH

### 7. Autres vues
- [ ] SireniumView
- [ ] ControleurView (contrôleurs MIDI)
- [ ] PianoView
- [ ] VoitureView
- [ ] PavillonView

### 8. Finalisation
- [ ] Toutes les commandes UDP
- [ ] Parsing complet playlists
- [ ] Intégration WebSocket
- [ ] Tests complets

