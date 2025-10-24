# API SirenConsole

## 📡 Communication WebSocket

SirenConsole → SirenePupitre (port 10001)

### Messages Sortants (Console → Pupitre)

#### REQUEST_CONFIG
```json
{
  "type": "REQUEST_CONFIG",
  "data": {}
}
```

#### PARAM_UPDATE
```json
{
  "type": "PARAM_UPDATE",
  "data": {
    "path": ["sirenConfig", "currentSiren"],
    "value": "2"
  }
}
```

### Messages Entrants (Pupitre → Console)

#### CONFIG_FULL
```json
{
  "type": "CONFIG_FULL",
  "data": {
    "sirenConfig": {
      "currentSiren": "1",
      "sirens": [...]
    }
  }
}
```

#### STATUS_UPDATE
```json
{
  "type": "STATUS_UPDATE",
  "data": {
    "currentNote": 60,
    "sirenId": "1",
    "frettedMode": false
  }
}
```

#### VOLANT_DATA (P3 → Console)
```json
{
  "type": "VOLANT_DATA",
  "pupitreId": 3,
  "note": 60,
  "velocity": 127,
  "pitchbend": 8192,
  "frequency": 261.63,
  "rpm": 1308.15,
  "timestamp": 1703123456789
}
```

### Protocole Binaire Volant (7 bytes)
```
[0-1] : Magic bytes (0x5353 = "SS")
[2]   : Message type (0x01 = VOLANT_STATE)
[3]   : Note MIDI (0-127)
[4]   : Velocity (0-127)
[5-6] : Pitchbend (uint16, 0-16383, centre = 8192)
```

**Note :** Le pupitre ID n'est pas inclus car le serveur identifie automatiquement le pupitre via la connexion WebSocket.

## 🎛️ Contrôles

```javascript
// Changer sirène assignée
consoleController.changeSiren("P1", "2")

// Mettre à jour paramètre
consoleController.updateParam("P1", ["sirenConfig", "currentSiren"], "2")
```

## 🔧 Configuration Réseau

- **Pupitre 1** : `192.168.1.41:10002`
- **Pupitre 2** : `192.168.1.42:10002`
- **Pupitre 3** : `192.168.1.43:10002`
- **Pupitre 4** : `192.168.1.44:10002`
- **Pupitre 5** : `192.168.1.45:10002`
- **Pupitre 6** : `192.168.1.46:10002`
- **Pupitre 7** : `192.168.1.47:10002`