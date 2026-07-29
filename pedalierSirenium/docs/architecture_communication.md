# Architecture de Communication (JSON + MIDI binaire)

Ce document décrit le flux de données entre PureData et l’application Qt/QML (WASM), en séparant:

- JSON (texte) pour le monitoring/état (boucles, scènes, voix, presets, horloge agrégée)
- Frames binaires (1–3 octets) pour les événements MIDI temps réel (clock, Note/CC/Pitch Bend)

## Diagramme

```mermaid
flowchart TD
  A["PureData"] -->|"JSON (état)"| B["WebSocket (texte)"]
  A -->|"MIDI binaire 1–3 octets"| C["WebSocket (binaire)"]
  B --> D["WebSocketController"]
  C --> D
  D -->|"état"| E["batchReceived → LiveState"]
  E --> H["vues 2D"]
  D -->|"octets MIDI"| F["MidiMonitorController"]
  F -.->|"midiDataChanged — aucun auditeur"| G["(rien)"]
```

> **État réel (2026-07)** : le canal JSON est le seul qui aboutisse. `MidiMonitorController` décode
> toujours les octets et émet `midiDataChanged`, mais plus aucun composant vivant n'y est abonné ;
> `MessageRouter` existe encore comme fichier mais n'est instancié nulle part. Le dispatch se fait
> dans `WebSocketController` sur `json.device`, puis dans le `switch` de `main.qml` vers
> `LiveState.applyX()`.
>
> Les messages sortants PD → QML sont par ailleurs **lissés à un par 40 ms** : `websocket-server.pd`
> jette tout message arrivant à moins de 30 ms du précédent, et `pd webserver.spacer` (dans
> `pedalier.pd`) sérialise la file. Ne pas supposer que deux champs liés arrivent ensemble.

## Encodage MIDI binaire

- Note On: `[0x90|n, note, velocity>0]`
- Note Off: `[0x80|n, note, 0]` (ou `[0x90|n, note, 0]`)
- Control Change: `[0xB0|n, cc, value]`
- Pitch Bend: `[0xE0|n, lsb, msb]` avec `bend14 = (msb<<7) | lsb`
- Clock (24 ppq): `0xF8` (1 octet). Start `0xFA`, Continue `0xFB`, Stop `0xFC`.

où `n ∈ [0..15]` est le canal MIDI.

## URL de connexion

```
ws://localhost:10000
```

## Notes d’implémentation

- 1 événement MIDI par frame WebSocket binaire (aucun JSON ni séparateur).
- Pas de logs par message dans le hot‑path côté QML pour préserver la latence.
- L’UI est mise à jour via le signal `midiDataChanged` du `MidiMonitorController`.


