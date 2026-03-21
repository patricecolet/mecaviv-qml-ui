# Structure Binaire 0x06 - Navigation Encodeur

## Format (3 bytes)

```
┌────┬──────────────┬──────────────┐
│0x06│ Encoder Value│Encoder Pressed│
│Type│    (0-127)   │   (0 ou 1)   │
└────┴──────────────┴──────────────┘
  0         1             2
```

## Détails des champs

| Byte | Nom | Type | Plage | Description |
|------|-----|------|-------|-------------|
| 0 | **Type** | uint8 | 0x06 | Identifiant du message ENCODER_NAVIGATION |
| 1 | **Encoder Value** | uint8 | 0-127 | Valeur de rotation de l'encodeur |
| 2 | **Encoder Pressed** | uint8 | 0 ou 1 | État du poussoir de l'encodeur (>0 = appuyé) |

## Usage

Ce message est **uniquement** utilisé pour la **navigation dans l'interface** (changement de sirène, ouverture/fermeture de panneaux, etc.).

**Important** : Ce message est **séparé** du message `0x02` (CONTROLLERS) qui est utilisé pour l'affichage visuel des contrôleurs dans le panneau "Contrôleurs".

## Exemple de paquet

### Scénario
- Encodeur à la valeur 63 (mi-course)
- Bouton relâché

### Paquet hexadécimal
```
0x06 0x3F 0x00
```

### Décodage
```
Byte  0: 0x06 = Type ENCODER_NAVIGATION
Byte  1: 0x3F = 63 (encoder value)
Byte  2: 0x00 = 0 (encoder pressed = relâché)
```

### Exemple avec bouton appuyé
```
0x06 0x3F 0x01
```
```
Byte  0: 0x06 = Type ENCODER_NAVIGATION
Byte  1: 0x3F = 63 (encoder value)
Byte  2: 0x01 = 1 (encoder pressed = appuyé)
```

## Génération du paquet (PureData)

### Exemple de code pour PureData
```
# Préparer les bytes pour la navigation
[pack 0x06 f f]
│
├─ 0x06 (type)
├─ $encoder_value    # 0-127 pour la rotation
└─ $encoder_pressed # 0 ou 1 pour le bouton
```

## Séparation des messages

### Message 0x02 (18 bytes) - Tests visuels
- **Usage** : Affichage visuel de **tous** les contrôleurs dans le panneau "Contrôleurs"
- **Contenu** : Volant, pads, joystick, fader, pédale, boutons, **encodeur** (bytes 16-17)
- **Destination** : `ControllersPanel.updateControllers()` uniquement
- **Fréquence** : ~60 Hz pour les tests visuels

### Message 0x06 (3 bytes) - Navigation
- **Usage** : Navigation dans l'interface (changement sirène, ouverture panneaux, etc.)
- **Contenu** : **Uniquement** l'encodeur (value + pressed)
- **Destination** : `EncoderController.updateFromControllers()` uniquement
- **Fréquence** : À chaque changement de l'encodeur (rotation ou appui)

## Avantages de la séparation

✅ **Séparation claire** : Tests visuels ≠ Navigation  
✅ **Performance** : Message léger (3 bytes) pour la navigation fréquente  
✅ **Flexibilité** : Possibilité d'envoyer la navigation indépendamment des tests visuels  
✅ **Simplicité** : Format minimal pour un usage dédié  

---

**Version** : 1.0  
**Date** : 4 février 2026  
**Statut** : Implémenté côté QML
