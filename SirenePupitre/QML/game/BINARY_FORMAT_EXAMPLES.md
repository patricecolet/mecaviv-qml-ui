# Format Binaire Optimisé - Exemples

## Format général
```
[0x04, note, velocity, duration_lsb, duration_msb]
```

## Calcul de la durée
```javascript
duration_ms = duration_lsb + (duration_msb << 8)
```

## Exemples pratiques

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

# Exemple
message = create_note_binary(69, 100, 800)
# bytes([0x04, 0x45, 0x64, 0x20, 0x03])
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

// Exemple
const message = createNoteBinary(69, 100, 800);
// Uint8Array([0x04, 0x45, 0x64, 0x20, 0x03])
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

-- Exemple
local message = createNoteBinary(69, 100, 800)
-- "\x04\x45\x64\x20\x03"
```

### PureData
```
[list 0x04 69 100 800 3(
|
[list trim]
|
[bytes2list]
```

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

