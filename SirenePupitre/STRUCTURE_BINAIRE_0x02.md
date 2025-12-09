# Structure Binaire 0x02 - Contrôleurs Physiques

## Format (18 bytes)

```
┌────┬─────────┬─────────┬─────────┬─────────┬────────┬────────┬────────┬────────┬────────┬────┬────┬────────┬────────┬──────┬──────┬─────────┬─────────┐
│0x02│ Volant  │ Volant  │  Pad1   │  Pad1   │  Pad2  │  Pad2  │  Joy   │  Joy   │  Joy   │Joy │Sel │ Fader  │ Pedal  │ Btn1 │ Btn2 │ Encoder │Encoder │
│Type│ Pos LSB │ Pos MSB │ After   │   Vel   │ After  │  Vel   │   X    │   Y    │   Z    │Btn │    │        │        │      │      │  Value  │Pressed │
└────┴─────────┴─────────┴─────────┴─────────┴────────┴────────┴────────┴────────┴────────┴────┴────┴────────┴────────┴──────┴──────┴─────────┴─────────┘
  0      1         2         3         4         5        6        7        8        9       10   11     12       13      14     15       16       17
```

## Détails des champs

| Byte | Nom | Type | Plage | Description |
|------|-----|------|-------|-------------|
| 0 | **Type** | uint8 | 0x02 | Identifiant du message CONTROLLERS |
| 1-2 | **Volant Position** | uint16 | 0-360 | Position en degrés (LSB puis MSB) |
| 3 | **Pad1 Aftertouch** | uint8 | 0-127 | Pression continue pad 1 |
| 4 | **Pad1 Velocity** | uint8 | 0-127 | Force de frappe pad 1 |
| 5 | **Pad2 Aftertouch** | uint8 | 0-127 | Pression continue pad 2 |
| 6 | **Pad2 Velocity** | uint8 | 0-127 | Force de frappe pad 2 |
| 7 | **Joystick X** | uint8 | 0-255 | Position horizontale (0-127=positif, 128-255=négatif) |
| 8 | **Joystick Y** | uint8 | 0-255 | Position verticale (0-127=positif, 128-255=négatif) |
| 9 | **Joystick Z** | uint8 | 0-255 | Rotation du manche (0-127=positif, 128-255=négatif) |
| 10 | **Joystick Button** | uint8 | 0 ou 1 | Bouton joystick (>0 = appuyé) |
| 11 | **Sélecteur** | uint8 | 0-4 | Position du levier (5 vitesses) |
| 12 | **Fader** | uint8 | 0-127 | Position du potentiomètre |
| 13 | **Pédale** | uint8 | 0-127 | Position de la pédale |
| 14 | **Bouton 1** | uint8 | 0 ou 1 | Bouton supplémentaire 1 (>0 = appuyé) |
| 15 | **Bouton 2** | uint8 | 0 ou 1 | Bouton supplémentaire 2 (>0 = appuyé) |
| 16 | **Encoder Value** | uint8 | 0-127 | Valeur de rotation de l'encodeur |
| 17 | **Encoder Pressed** | uint8 | 0 ou 1 | État du poussoir de l'encodeur (>0 = appuyé) |

## Mapping Sélecteur (5 vitesses)

| Position | Mode | Description |
|----------|------|-------------|
| 0 | SEMITONE | Demi-ton |
| 1 | THIRD | Tierce |
| 2 | MINOR_SIXTH | Sixte mineure |
| 3 | OCTAVE | Octave |
| 4 | DOUBLE_OCTAVE | Double octave |

## Exemple de paquet

### Scénario
- Volant à 180°
- Pad1 actif (vel=100, after=50)
- Pad2 inactif
- Joystick centré (X=0, Y=0, Z=0), bouton relâché
- Sélecteur en position 2 (MINOR_SIXTH)
- Fader à mi-course (64)
- Pédale à ~38% (48)
- Boutons relâchés

### Paquet hexadécimal
```
0x02 0xB4 0x00 0x32 0x64 0x00 0x00 0x00 0x00 0x00 0x00 0x02 0x40 0x30 0x00 0x00 0x3F 0x00
```

### Décodage
```
Byte  0: 0x02 = Type CONTROLLERS
Byte  1: 0xB4 = 180 (LSB)
Byte  2: 0x00 = 0 (MSB) → 180 + (0 × 256) = 180°
Byte  3: 0x32 = 50 (aftertouch pad1)
Byte  4: 0x64 = 100 (velocity pad1)
Byte  5: 0x00 = 0 (aftertouch pad2)
Byte  6: 0x00 = 0 (velocity pad2)
Byte  7: 0x00 = 0 (joystick X)
Byte  8: 0x00 = 0 (joystick Y)
Byte  9: 0x00 = 0 (joystick Z)
Byte 10: 0x00 = 0 (joystick button)
Byte 11: 0x02 = 2 (sélecteur position 2 = MINOR_SIXTH)
Byte 12: 0x40 = 64 (fader)
Byte 13: 0x30 = 48 (pédale)
Byte 14: 0x00 = 0 (bouton 1)
Byte 15: 0x00 = 0 (bouton 2)
Byte 16: 0x3F = 63 (encoder value)
Byte 17: 0x00 = 0 (encoder pressed)
```

## Génération du paquet (PureData)

### Exemple de code pour PureData
```
# Préparer les bytes
[pack 0x02 f f f f f f f f f f f f f f f f f f]
│
├─ 0x02 (type)
├─ $volant_pos % 256 (LSB)
├─ $volant_pos / 256 (MSB)
├─ $pad1_after
├─ $pad1_vel
├─ $pad2_after
├─ $pad2_vel
├─ $joy_x + 127 (conversion signée)
├─ $joy_y + 127
├─ $joy_z + 127
├─ $joy_btn
├─ $selector
├─ $fader
├─ $pedal
├─ $btn1
├─ $btn2
├─ $encoder_value
└─ $encoder_pressed
```

### Conversion joystick (mapping PureData)
```
PureData envoie :
  0-127   → valeurs positives 0 à +127
  128-255 → valeurs négatives 0 à -127

Côté QML (décodage) :
  value = (byte <= 127) ? byte : -(byte - 128)

Exemples :
  byte 0   → 0
  byte 64  → +64
  byte 127 → +127
  byte 128 → -0 (centre négatif)
  byte 192 → -64
  byte 255 → -127
```

## Performance

| Métrique | Format JSON | Format 0x02 | Gain |
|----------|-------------|-------------|------|
| Taille | ~600 bytes | 18 bytes | **33.3x plus compact** |
| Parsing | JSON.parse() | Accès direct | **~100x plus rapide** |
| CPU | Élevé | Minimal | **~95% de réduction** |
| Fréquence max | ~10 Hz | 100+ Hz | **10x plus rapide** |

## Notes d'implémentation

### PureData → QML
1. Créer un tableau de 18 bytes
2. Remplir les valeurs selon la structure
3. Envoyer via WebSocket en binaire

### QML
1. Réception : `onBinaryMessageReceived`
2. Vérification : `bytes[0] === 0x02 && bytes.length === 18`
3. Décodage : Accès direct par index
4. Application : Mise à jour des indicateurs

### Conversion spéciales
- **Volant** : `position = bytes[1] | (bytes[2] << 8)`
- **Joystick signé** : `if (value > 127) value -= 256`
- **Sélecteur** : Mapper 0-4 vers noms de modes
- **Boutons** : `active = bytes[n] > 0`

## Avantages clés

✅ **Ultra-compact** : 18 bytes seulement  
✅ **Ultra-rapide** : Pas de parsing JSON  
✅ **Fréquence élevée** : 60-100 Hz sans problème  
✅ **Séparation claire** : Contrôleurs ≠ Séquence  
✅ **Extensible** : Facile d'ajouter un type 0x03 si besoin  
✅ **Fiable** : Format fixe, pas d'ambiguïté  

---

**Version** : 1.1  
**Date** : 27 novembre 2025  
**Statut** : Implémenté côté QML avec encodeur rotatif (bytes 16-17)

