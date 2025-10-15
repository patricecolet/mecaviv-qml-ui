# Format Binaire Optimisé - Exemples

## Formats supportés

### Format Note (5 bytes)
```
[0x04, note, velocity, duration_lsb, duration_msb]
```

### Format Control Change (3 bytes)
```
[0x05, cc_number, cc_value]
```

## Calcul de la durée
```javascript
duration_ms = duration_lsb + (duration_msb << 8)
```

## Exemples pratiques - Notes

### Note La4 (69), vélocité 100, durée 800ms
```
[0x04, 0x45, 0x64, 0x20, 0x03]
```
- Note: 69 (0x45)
- Vélocité: 100 (0x64)
- Durée: 0x20 + (0x03 << 8) = 32 + 768 = 800ms

### Note Do4 (60), vélocité 80, durée 1500ms
```
[0x04, 0x3C, 0x50, 0xDC, 0x05]
```
- Note: 60 (0x3C)
- Vélocité: 80 (0x50)
- Durée: 0xDC + (0x05 << 8) = 220 + 1280 = 1500ms

### Note Mi5 (76), vélocité 127, durée 2000ms
```
[0x04, 0x4C, 0x7F, 0xD0, 0x07]
```
- Note: 76 (0x4C)
- Vélocité: 127 (0x7F)
- Durée: 0xD0 + (0x07 << 8) = 208 + 1792 = 2000ms

### Note Sol3 (55), vélocité 64, durée 500ms
```
[0x04, 0x37, 0x40, 0xF4, 0x01]
```
- Note: 55 (0x37)
- Vélocité: 64 (0x40)
- Durée: 0xF4 + (0x01 << 8) = 244 + 256 = 500ms

## Exemples pratiques - Control Change (CC)

### CC1 (Vibrato Amount) - valeur 64 (50%)
```
[0x05, 0x01, 0x40]
```
- CC: 1 (0x01) - Vibrato Amount
- Valeur: 64 (0x40) → normalisée à 0.5 → vibratoAmount = 1.0

### CC9 (Vibrato Rate) - valeur 80 (63%)
```
[0x05, 0x09, 0x50]
```
- CC: 9 (0x09) - Vibrato Rate
- Valeur: 80 (0x50) → normalisée à 0.63 → vibratoRate = 6.67 Hz

### CC92 (Tremolo Amount) - valeur 32 (25%)
```
[0x05, 0x5C, 0x20]
```
- CC: 92 (0x5C) - Tremolo Amount
- Valeur: 32 (0x20) → normalisée à 0.25 → tremoloAmount = 0.075

### CC15 (Tremolo Rate) - valeur 100 (79%)
```
[0x05, 0x0F, 0x64]
```
- CC: 15 (0x0F) - Tremolo Rate
- Valeur: 100 (0x64) → normalisée à 0.79 → tremoloRate = 8.11 Hz

### CC73 (Attack Time) - valeur 64 (50%)
```
[0x05, 0x49, 0x40]
```
- CC: 73 (0x49) - Attack Time
- Valeur: 64 (0x40) → normalisée à 0.5 → attackTime = 250ms

### CC72 (Release Time) - valeur 96 (76%)
```
[0x05, 0x48, 0x60]
```
- CC: 72 (0x48) - Release Time
- Valeur: 96 (0x60) → normalisée à 0.76 → releaseTime = 1520ms

## Conversion rapide

### Python
```python
def create_note_binary(note, velocity, duration_ms):
    """Crée un message binaire pour une note"""
    return bytes([
        0x04,  # Type
        note & 0xFF,
        velocity & 0xFF,
        duration_ms & 0xFF,
        (duration_ms >> 8) & 0xFF
    ])

def create_cc_binary(cc_number, cc_value):
    """Crée un message binaire pour un Control Change"""
    return bytes([
        0x05,  # Type CC
        cc_number & 0xFF,
        cc_value & 0xFF
    ])

# Exemples
note_msg = create_note_binary(69, 100, 800)
# bytes([0x04, 0x45, 0x64, 0x20, 0x03])

cc_msg = create_cc_binary(1, 64)  # CC1 (Vibrato Amount) = 64
# bytes([0x05, 0x01, 0x40])
```

### JavaScript
```javascript
function createNoteBinary(note, velocity, durationMs) {
    return new Uint8Array([
        0x04,  // Type
        note & 0xFF,
        velocity & 0xFF,
        durationMs & 0xFF,
        (durationMs >> 8) & 0xFF
    ]);
}

function createCCBinary(ccNumber, ccValue) {
    return new Uint8Array([
        0x05,  // Type CC
        ccNumber & 0xFF,
        ccValue & 0xFF
    ]);
}

// Exemples
const noteMsg = createNoteBinary(69, 100, 800);
// Uint8Array([0x04, 0x45, 0x64, 0x20, 0x03])

const ccMsg = createCCBinary(1, 64);  // CC1 = 64
// Uint8Array([0x05, 0x01, 0x40])
```

### Lua (Reaper)
```lua
function createNoteBinary(note, velocity, durationMs)
    return string.char(
        0x04,
        note & 0xFF,
        velocity & 0xFF,
        durationMs & 0xFF,
        (durationMs >> 8) & 0xFF
    )
end

function createCCBinary(ccNumber, ccValue)
    return string.char(
        0x05,
        ccNumber & 0xFF,
        ccValue & 0xFF
    )
end

-- Exemples
local noteMsg = createNoteBinary(69, 100, 800)
-- "\x04\x45\x64\x20\x03"

local ccMsg = createCCBinary(1, 64)  -- CC1 = 64
-- "\x05\x01\x40"
```

### PureData
```
# Note
[list 0x04 69 100 800 3(
|
[list trim]
|
[bytes2list]

# Control Change
[list 0x05 1 64(  # CC1 = 64
|
[list trim]
|
[bytes2list]
```

## Mapping MIDI CC

| CC# | Nom | Plage sortie | Description |
|-----|-----|--------------|-------------|
| 1 | Vibrato Amount | 0.0 - 2.0 | Amplitude de l'ondulation latérale |
| 9 | Vibrato Rate | 1.0 - 10.0 Hz | Fréquence du vibrato |
| 15 | Tremolo Rate | 1.0 - 10.0 Hz | Fréquence du tremolo |
| 72 | Release Time | 0 - 2000 ms | Durée du release (queue) |
| 73 | Attack Time | 0 - 500 ms | Durée de l'attack (max 95% de duration) |
| 92 | Tremolo Amount | 0.0 - 0.3 | Amplitude de la pulsation de largeur |

## Durées courantes

| Durée (ms) | LSB | MSB | Hex |
|------------|-----|-----|-----|
| 100 | 100 | 0 | 0x64 0x00 |
| 250 | 250 | 0 | 0xFA 0x00 |
| 500 | 244 | 1 | 0xF4 0x01 |
| 750 | 238 | 2 | 0xEE 0x02 |
| 800 | 32 | 3 | 0x20 0x03 |
| 1000 | 232 | 3 | 0xE8 0x03 |
| 1500 | 220 | 5 | 0xDC 0x05 |
| 2000 | 208 | 7 | 0xD0 0x07 |
| 3000 | 184 | 11 | 0xB8 0x0B |
| 5000 | 136 | 19 | 0x88 0x13 |

## Notes MIDI courantes

| Note | Nom | Hex |
|------|-----|-----|
| 48 | Do3 | 0x30 |
| 55 | Sol3 | 0x37 |
| 60 | Do4 | 0x3C |
| 64 | Mi4 | 0x40 |
| 69 | La4 | 0x45 |
| 72 | Do5 | 0x48 |
| 76 | Mi5 | 0x4C |
| 84 | Do6 | 0x54 |

## Vélocités courantes

| Vélocité | Hex | Description |
|----------|-----|-------------|
| 0 | 0x00 | Silence |
| 32 | 0x20 | Pianissimo |
| 64 | 0x40 | Mezzo |
| 96 | 0x60 | Forte |
| 100 | 0x64 | Fortissimo |
| 127 | 0x7F | Max |

