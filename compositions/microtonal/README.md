# Morceaux avec livret microtonal

Ce dossier vit sous le **dépôt MIDI** (`config.paths.midiRepository` ou `MECAVIV_COMPOSITIONS_PATH`).

La **vue microtonale** s’active automatiquement à la sélection d’un morceau **uniquement si** un fichier JSON compagnon est trouvé à côté du `.mid` :

| Fichier MIDI | JSON reconnu (premier trouvé) |
|--------------|----------------------------------|
| `piece.mid` | `piece_conductor-cues.json`, ou `piece.json`, ou `conductor-cues.json` dans le même dossier |

Sans JSON valide à cet emplacement, l’affichage reste **normal** (non microtonal), quel que soit le nom du dossier.

Voir `docs/CONDUCTOR_CUES_PROTOCOL.md` et `reaper/Mecaviv_ExportConductorCues.lua` pour le format du JSON.
