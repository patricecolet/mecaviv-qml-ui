# Changelog - Protocole Binaire pour Contrôleurs

## Date : 19 octobre 2025

### Changements majeurs

#### 🎯 Séparation des contrôleurs et séquences MIDI

**Problème** : Les contrôleurs physiques et les notes de séquence MIDI étaient mélangés dans le même flux JSON, causant :
- Surcharge réseau importante (~600 bytes par message)
- Parsing JSON coûteux en CPU
- Confusion entre données temps réel et séquence

**Solution** : Protocole binaire avec types distincts

### Nouveaux formats binaires

#### Type 0x01 - MIDI_NOTE (5 bytes)
- **Usage** : Position du volant convertie en note MIDI
- **Source** : Contrôleur physique (volant)
- **Destination** : Curseur sur la portée musicale
- **Fréquence** : ~100 Hz

#### Type 0x02 - CONTROLLERS (16 bytes) ⭐ NOUVEAU
- **Usage** : État de tous les contrôleurs physiques
- **Contenu** :
  - Volant (position en degrés 0-360)
  - Pad 1 (velocity + aftertouch)
  - Pad 2 (velocity + aftertouch) - NOUVEAU
  - Joystick (X, Y, Z, bouton)
  - Sélecteur 5 vitesses (0-4) - ÉTENDU de 4 à 5 positions
  - Fader (0-127)
  - Pédale (0-127)
  - Bouton 1 - NOUVEAU
  - Bouton 2 - NOUVEAU
- **Fréquence** : ~60 Hz
- **Performance** : 40x plus compact que JSON (16 bytes vs 600 bytes)

#### Type 0x04 - MIDI_NOTE_DURATION (5 bytes)
- **Usage** : Notes de séquence MIDI avec durée
- **Source** : Fichier MIDI
- **Destination** : Mode jeu uniquement

#### Type 0x05 - CONTROL_CHANGE (3 bytes)
- **Usage** : CC MIDI de séquence
- **Source** : Fichier MIDI
- **Destination** : Modulations (vibrato, tremolo, enveloppe)

### Modifications du code

#### WebSocketController.qml
- ✅ Ajout du décodage du format 0x02 (16 bytes)
- ✅ Mapping des 5 positions du sélecteur
- ✅ Support des 2 pads distincts
- ✅ Support des 2 boutons supplémentaires
- ✅ Distinction claire entre contrôleurs physiques et séquence

#### Main.qml
- ✅ Ajout du flag `isControllersOnly` pour les messages 0x02
- ✅ Séparation des flux : contrôleurs physiques vs séquence MIDI
- ✅ Rétrocompatibilité JSON maintenue

#### ControllersPanel.qml
- ✅ Ajout des propriétés pour pad2 (velocity, aftertouch, active)
- ✅ Ajout des propriétés pour button1 et button2
- ✅ Modification de `updateControllers()` pour gérer les nouveaux champs
- ✅ Ajout d'un second PadIndicator pour pad2
- ✅ Ajout des indicateurs visuels pour les 2 boutons
- ✅ Labels "PAD 1" / "PAD 2" en overlay 2D
- ✅ Mise à jour de l'indicateur de connexion (pad1 || pad2)

#### GearShiftIndicator.qml
- ✅ Déjà compatible avec 5 positions (pas de modification nécessaire)

### Documentation

#### README.md
- ✅ Section complète sur le protocole binaire
- ✅ Tableau détaillé du format 0x02 (16 bytes)
- ✅ Exemples avec représentation hexadécimale
- ✅ Mapping des 5 positions du sélecteur
- ✅ Distinction contrôleurs physiques vs séquence MIDI
- ✅ Ancien format JSON marqué comme OBSOLÈTE
- ✅ Mise à jour des formats des contrôleurs
- ✅ Mise à jour du flux de données

### Avantages

#### Performance
- **40x plus compact** : 16 bytes vs ~600 bytes JSON
- **Parsing ultra-rapide** : Accès direct par index au lieu de JSON.parse()
- **Fréquence élevée** : 60-100 Hz sans surcharge réseau
- **CPU libéré** : Pas de parsing JSON coûteux

#### Architecture
- **Séparation claire** : Contrôleurs physiques ≠ Séquence MIDI
- **Types distincts** : 0x01 (volant), 0x02 (contrôleurs), 0x04 (séquence), 0x05 (CC)
- **Extensibilité** : Facile d'ajouter de nouveaux types

#### Maintenance
- **Code plus clair** : Chaque type a son traitement dédié
- **Débogage facilité** : Distinction immédiate par le premier byte
- **Rétrocompatibilité** : Format JSON maintenu pour anciens systèmes

### Rétrocompatibilité

Le format JSON reste supporté pour la rétrocompatibilité, mais est déprécié.  
L'application détecte automatiquement le format (binaire ou JSON) et s'adapte.

### Migration PureData

Pour profiter des optimisations, PureData doit envoyer :
1. **Type 0x01** : Position volant → note MIDI (déjà fait)
2. **Type 0x02** : Paquet de 16 bytes avec tous les contrôleurs (à implémenter)
3. **Type 0x04** : Notes de séquence (déjà fait)
4. **Type 0x05** : CC de séquence (déjà fait)

### Tests requis

- [ ] Vérifier la réception du format 0x02 depuis PureData
- [ ] Tester les 2 pads simultanément
- [ ] Tester les 5 positions du sélecteur
- [ ] Tester les 2 boutons supplémentaires
- [ ] Valider la fréquence de mise à jour (60-100 Hz)
- [ ] Vérifier la performance CPU avec format binaire vs JSON
- [ ] Tester la rétrocompatibilité JSON

### Notes techniques

#### Conversion volant
- PureData fait la conversion modulo 360 (degrés)
- Plus besoin de diviser par 480 côté QML

#### Pads
- 2 pads physiques distincts (pad1 et pad2)
- Chaque pad : velocity + aftertouch
- `active` calculé automatiquement (velocity > 0)

#### Sélecteur
- 5 positions au lieu de 4
- Position 4 = DOUBLE_OCTAVE

#### Boutons
- 3 boutons au total : joystick + button1 + button2
- Affichés en overlay 2D en bas de l'écran

---

**Auteur** : Assistant IA  
**Validé par** : Patrice Colet  
**Statut** : Implémenté, en attente de tests

