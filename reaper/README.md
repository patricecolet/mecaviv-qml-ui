# Reaper — export `conductor-cues.json`

## Rôle

- La **sirène** est identifiée par le **canal MIDI** de la note (**1–16**) : c’est ce qui est exporté dans **`sirenTrackIndex`** (pas l’index de piste Reaper). Le nom de **piste** Reaper est dans **`sirenTrackName`** (lisibilité).
- Le **pupitre** joue une sirène assignée : routage **canal / sirène → pupitre** via `metadata.sirenToPupitre` ou config console.
- Le script parcourt **toutes les pistes** : tout item MIDI est analysé ; le fichier JSON contient les consignes de **toutes** les pistes, triées par **temps projet** (tick global).

## Script

- **`Mecaviv_ExportConductorCues.lua`** : aucune sélection requise — export global du projet.
- **Fréquence** : note + pitch bend au début de la note → `midiAnchor`, `targetCents`, `targetFrequencyHz`.
- **Glissando** : pente du pitch bend → `glissSpeed` 0–4.
- **Volet** : **vélocité** de la note → `voletOpen` (0–127 → 0.0–1.0).
- Chaque consigne : **`sirenTrackIndex`** = **canal MIDI** de la note (1–16), **`sirenTrackName`** = nom de piste Reaper. **`targets`** souvent `[]` ; compléter **`sirenToPupitre`** (clés = numéro de canal en chaîne, ex. `"4"`) ou config console.

## Installation dans Reaper

1. `Actions` → `Show action list` → `ReaScript` → `Load` → choisir `Mecaviv_ExportConductorCues.lua`.
2. Optionnel : raccourci clavier.

## Utilisation

1. Projet avec une ou plusieurs **pistes MIDI** (items MIDI). Nommez les pistes pour identifier les sirènes (ex. `S1`, `Alto`, …).
2. Dessiner le **pitch bend** / **vélocités** comme souhaité.
3. Lancer l’action du script (sans sélection obligatoire).
4. Une boîte **Enregistrer sous** s’ouvre (extension **reaper_js** / API `JS_Dialog_BrowseForSaveFile`, ou `GetUserFileNameForSave` selon la version de Reaper). Sinon, saisie manuelle du chemin complet.

Le nom par défaut proposé reprend le projet : **`<nom_projet>_conductor-cues.json`** à côté du `.rpp` (modifiable avant enregistrement).

## Ticks

- `tick` = position sur la **timeline projet** : `floor(QN × ppq)` (`metadata.tickOrigin`: `project_timeline_qn`), pour aligner toutes les pistes sur une seule échelle temporelle.
- À synchroniser avec le même `.mid` / le même tempo que le lecteur côté pupitre ou console.

## Réglages (en tête du `.lua`)

- `pitch_bend_range_semitones` (souvent **2**).
- `gliss.*` : seuils **cents par noire** pour `glissSpeed` (0 = instantané ; 1–4 = vitesses ; **3 vs 4** séparés par `slow_at`, pas par `med_at`). Une note **après** la fin d’un gliss ne doit pas réutiliser l’ancienne transition (corrigé en 2.6) ; `flat_*` et `fallback_max_quarters` affinent l’instantané vs pente locale.
