# Cahier des charges — nouveaux patches PD (harmoniseur v2 + patch principal v2)

Spécification des deux nouveaux patches PureData décidés le 2026-07-18 : une nouvelle version de
`harmonizer.pd` **sans le séquenceur**, et un nouveau patch principal (successeur de
`MidiToSiren.pd`) **composé par cherry-picking** — réutilisation ciblée de sous-patches existants,
pas une réécriture intégrale. Les deux sont construits **à côté** de l'existant, qui reste intact
tant que le nouveau n'a pas fait ses preuves — aucune suppression dans les patches en production
avant validation.

Ce doc couvre l'articulation entre les deux patches. Pour le détail déjà tranché ailleurs, voir :
[`SCENES_SPEC.md`](SCENES_SPEC.md) (modèle scène/clip/harmonie), [`PD_WORK.md`](PD_WORK.md)
(contrat WebSocket écran ↔ PD), [`PATCH_REBUILD.md`](PATCH_REBUILD.md) (briques bas niveau —
`pdjson`, `midifile`, `clip-io.pd` — déjà construites et testées), [`PEDALIER_MAPPING.md`](PEDALIER_MAPPING.md)
(contrôleurs physiques).

---

## 1. Harmoniseur v2 — sans séquenceur

### Ce qui reste (cœur harmonique)

Le rôle ne change pas : dispatcher l'harmonie sur les sirènes actives, intervalle fixe par sirène
(réglage existant, pas de proximité de hauteur dynamique — cf. mémoire `pd-engine-architecture`,
c'est une piste évoquée mais **non décidée**). L'harmonie vit dans la **scène**, pas dans le clip
(`SCENES_SPEC.md §1/§6/§10`).

### Ce qui part (le séquenceur/looper embarqué)

`harmonizer.pd` contient aujourd'hui un looper/recorder complet, mêlé au code harmonique — c'est
justement ce que `clip-io.pd` (`PATCH_REBUILD.md §4bis`, déjà testé) est censé remplacer. Le
séquenceur devient **hors périmètre de l'harmoniseur** ; sa fonction (enregistrer/rejouer un clip)
est prise en charge par le patch principal via `clip-io.pd`, en amont de l'harmoniseur, pas dedans
(`SCENES_SPEC.md §9` — le recorder doit être en amont pour que l'harmonie reste modifiable après
coup).

### Entrées multiples à gérer

L'harmoniseur doit désormais recevoir **plusieurs sources** possibles au lieu d'une seule ligne
Sirénium :
- la ligne Sirénium **live** (jeu direct) ;
- une ligne **rejouée** depuis un clip (`clip-io.pd` en lecture, dump des notes).

**Priorité d'arbitrage entre les deux, à l'entrée : pas encore tranchée** (`PD_WORK.md`, section
« Décisions à trancher », point 1 ; `SCENES_SPEC.md §14`). Piste proposée mais non actée : « le
dernier joué prime » (même principe que la divergence réservé/réel du modèle scènes).

### Sortie

Broadcast vers les sirènes actives selon la scène — le champ `source` par sirène
(`clip`/`voice`/`lead`/`rec`/`free`/`out`, `PD_WORK.md §3`) détermine qui est éligible/actif, mais
cette logique-là vit dans le **patch principal** (elle pilote quelle scène/quel clip est chargé),
pas dans l'harmoniseur — l'harmoniseur reçoit une ligne déjà sélectionnée et l'harmonise.

### Inventaire statique de `harmonizer.pd` (2026-07-18, base de discussion)

103 sous-patches nommés (`#X restore`) dans les 3834 lignes du fichier actuel. Catégorisation par
**nommage seul** (pas de lecture fonctionnelle complète) — à corriger/valider, pas une vérité
arrêtée :

**Cœur harmonique (a priori à garder)** : `updateVoice`, `voices.siren.preselection`,
`siren.reset`, `disable.all.voices`, `led.siren.selected`, `sirenVoices`, `set scaleBuffer`,
`getVoices`, `transposeQuarterTune` (×2), `currentVoiceNote`, `getCurrentVoiceScale`,
`nextCurrentScale`, `nextVoiceNote`, `voiceInterval`, `getCurrentScaleNote`, `harmonize`,
`sirenChannel`, `tune`, `scale` (×2), `voiceToMIDI`, `siren.transpo`, `octavePerSiren`,
`voiceVolume`, `voiceToChannel` (×2), `voiceToScore`, `keep.last.note`, `get.voice.channel`.

**Séquenceur/looper embarqué (candidat retrait — remplacé par `clip-io.pd`)** : `gate-sequencer`,
`countSequence`, `setSequenceIndexing`, `pedalStopTimer` (×2), `loop.stop.all` (×2),
`loop.clear.all`, `pedal.play.rec.selected`, `pedal.stop.selected`, `checkPlaying`,
`led.recording`, `is.loop.playing`, `waitBar`, `pedal.rec.play`, `pedal`, `mainLoopInit`,
`loopInit`, `update.recording.loop.bar`, `rec.loop.define`, `setLoopOffset`, `setLoopSizeBuffer`,
`loopIsLongerThanMainLoop`, `setLoopSizeDefinition`, `setLoopSize`, `setFirstLoop`,
`checkLoopSize`, `update.playing.loop.bar`, `play.loop.define`, `clear.loop.define`,
`loop.tempo.define`, `loop.select.define`, `loop.define.recall`, `loop.index.define`,
`loop.stop.define`, `loopDefine`, `recorder`, `loop.define`, `loop.clear`,
`set.loop.clear.buffer`, `get.loop.clear.buffer`, `transport` (×2), `set.selected.voice`.

**Sortie sirène / protocole (a priori à garder, périmètre « instrument live »)** : `sirenium`,
`sirenium.reset`, `sysexID`, `sysexin`, `sysexout`, `sysexSend`, `virtualSirenium`,
`sirenium.monitoring`, `processVoice`, `getExpressionBuffer`, `expression` (×2), `letters` (×2),
`tohexa`, `voice`, `sirenPing`.

**État/JSON pour le WebSocket (candidat remplacement par `pdjson`)** : `voices2json`, `clock2json`,
`jsonStructure`.

**Horloge / divers** : `internal.clock`, `source`, `bar.div`, `midiclock`, `pedal.behavior.loop`,
`selectNextEnabled`, `loop.voice.select`, `states`.

**Non catégorisé / à examiner** : le reste (variantes `sysex*Param` externes au fichier, buffers
`\$1.sequence.*`/`\$1.loop.*` visibles par `text sequence`/`text search` — objets `text` PD natifs,
probablement liés au séquenceur retiré).

---

## 2. Patch principal v2 — composé par cherry-picking

### Objectif

Successeur de `MidiToSiren.pd`, périmètre resserré à l'instrument live (`SCENES_SPEC.md §13`) —
pas un routeur MIDI généraliste, ComposeSiren s'en charge désormais côté UDP.

### Briques déjà prêtes (construites et testées cette session, réutilisables telles quelles)

- **`pdjson`** (`~/repo/pd-externals/critapec/pdjson/`) — lecture/écriture JSON + constructeur
  incrémental (`add`/`array`/`push`/`pop`/`clearBuilder`/`build`/`writeBuilder`). Attention :
  `~/Documents/Pd/externals/pdjson/` est une copie séparée, à resynchroniser à chaque modif
  (mémoire `pd-externals-shadowing`).
- **`midifile`** (`~/repo/pd-externals/critapec/midifile/`) — I/O SMF bas niveau, protocole
  d'écriture vérifié (`write <path> 480`, `float <delta>` avant chaque événement, `flush` auto
  End-of-Track).
- **`clip-io.pd`** (`mecaviv/puredata-abstractions/application.layer/`) — I/O d'un clip
  (`record`/`stop`/`read`/`dump`), cycle complet vérifié octet par octet dans Pd réel
  (`PATCH_REBUILD.md §4bis`). Pas encore testé : plusieurs clips dans la même session, chemins
  d'erreur, intégration réelle dans un patch qui tourne.

### Cherry-picking depuis l'existant — à trier (grille de lecture, pas une liste arrêtée)

Sous-patches déjà présents dans `application.layer/` en dehors de `harmonizer.pd`, candidats à
réutiliser tels quels, adapter, ou laisser de côté : `voiceRecorder.pd`, `looper.pd`,
`scaleManager.pd`, `sirenVoice.pd`, `sirenColor.pd`, `sirenChannelToVoiceNumber.pd`,
`composeSiren~.pd`, `getMidiDevice.pd`, `websocket-server.pd`, `axis-map.pd`, `curve-map.pd`,
`microtune.pd`/`microtuneDisplay.pd`, `voiceGate.pd`, `voiceToMIDI.pd`, `sysexExpressionParam-0.1.pd`,
`sysexScaleParam-0.1.pd`, `sysexVoiceParam-0.1.pd`, `pchit-udp.pd`, `enableV2radio.pd`,
`display.pd`, `debug.pd`. **`voiceRecorder.pd`/`looper.pd` vérifiés plus tôt cette session** :
n'utilisent ni JSON ni `midifile` (stockage `text`/`sequence` natif Pd) — donc probablement à
**remplacer** par `clip-io.pd`, pas à cherry-picker tels quels, sauf si une partie de leur logique
(ex. déclenchement pédale) est encore pertinente séparément du stockage.

### Enregistreur et lecteur — les deux pièces qui manquent encore autour de `clip-io.pd`

Trouvé en testant `clip-io-help.pd` (2026-07-18) : `clip-io.pd` est une brique d'I/O pure — il
**reçoit** `deltaTicks` déjà calculé pour chaque événement, il ne le calcule pas ; et `dump`/
`dump_notes` sort toute la liste d'un coup, sans respecter le timing à la lecture. Ni écrire une
vraie séquence en direct, ni la rejouer en rythme n'est possible sans ces deux pièces. Ni l'une ni
l'autre n'existent encore — à construire, chacune comme un composant séparé de `clip-io.pd`
lui-même (qui reste juste l'I/O SMF+JSON).

#### Enregistreur — MIDI live → `deltaTicks` calculé → `clip-io.pd`

**Rôle** : convertir le flux MIDI brut du Sirénium (temps réel, sans notion de tick) en messages
`[status data1 data2 deltaTicks]`, le format que `clip-io.pd` attend (`PATCH_REBUILD.md §4bis` —
ticks en dernier, exprès, pour l'ordre de déclenchement `unpack`).

**Mécanisme proposé** (à valider) : un `[timer]` (ou `[realtime]`) mesurant les millisecondes
écoulées depuis le dernier événement sur la sirène en cours d'enregistrement. Conversion en ticks
via la même convention BPM-ancré-sur-la-noire déjà posée (`PD_WORK.md §7`, 480 ticks/noire, cf.
`midifile` déjà câblé sur cette base dans `clip-io.pd`) :

```
ticks = ms_écoulées × bpm × 8 / 1000
```

(`480 ticks/noire ÷ (60000/bpm) ms/noire = bpm × 8 / 1000` ticks par ms.)

**Messages** :
- Démarrage : `record <clipId> <sirenId>` envoyé à `clip-io.pd`, timer remis à zéro. Déclenché par
  pédale (`PEDALIER_MAPPING.md`, logique `pedal.rec.play` à récupérer du séquenceur retiré —
  inventaire §1 ci-dessus).
- Par événement MIDI reçu sur la sirène enregistrée : lire le timer, convertir en ticks, envoyer
  `[status data1 data2 <ticks_calculés>]` à `clip-io.pd`.
- Arrêt : `stop <lengthTicks> <lengthBars> <isReference>` — `lengthTicks` = position courante,
  `lengthBars` dépend du groupage de mesure courant (`clock.groups`, `PD_WORK.md §7`), à calculer.
  Déclenché par pédale (`pedal.stop.selected`).

**Non tranché** : la source du tempo pour ce calcul — le tempo courant à l'instant de
l'enregistrement (variable si le tempo change en cours d'enregistrement) ou figé au démarrage ?
Cohérent avec le principe déjà posé que le tempo reste modifiable en direct (`PD_WORK.md §7`), donc
tempo courant proposé par défaut, mais à confirmer.

#### Lecteur — `dump`/`dump_notes` + `metro` → MIDI temporisé

**Rôle** : prendre la liste de notes sortie par `clip-io.pd` (position + durée en ticks pour
chaque note, format `dump_notes` déjà vérifié — ex. `0 60 64 240 0`) et la rejouer avec le bon
timing, au lieu de tout émettre d'un coup.

**Mécanisme proposé** (à valider — confirmé « avec un metro », détail de résolution ouvert) : un
`[metro]` qui avance un curseur de position en ticks à intervalle régulier (résolution à définir —
candidat : 10 ms, un compromis entre précision perçue et charge). À chaque tick du metro, comparer
le curseur à la liste des notes en attente (triée par position de départ) et déclencher celles dont
le tour est venu — modèle classique de scheduler à liste triée. Le metro s'arrête une fois la
dernière note jouée.

**Messages** :
- Entrée : `read <clipId>` puis `dump_notes` vers `clip-io.pd`, résultat bufferisé (liste triée par
  position de départ).
- Sortie : événements MIDI bruts, au fil du temps, vers l'harmoniseur (comme ligne « rejouée »,
  `SCENES_SPEC.md §9-10`) ou directement vers les sirènes selon le `source` de la sirène concernée
  (`PD_WORK.md §3`).

**Non tranché** : la vitesse de lecture suit-elle le tempo courant (rejoué plus vite/lentement si le
tempo a changé depuis l'enregistrement) ou le tempo figé au moment de l'enregistrement ? Symétrique
de la question côté enregistreur — à trancher ensemble, probablement de la même façon (tempo
courant par cohérence).

**Piste de réutilisation** : le séquenceur retiré de `harmonizer.pd` (inventaire §1) faisait
forcément déjà ce genre de lecture temporisée — `checkPlaying`, `is.loop.playing`, `waitBar`,
`update.playing.loop.bar`, `play.loop.define` sont des candidats à examiner avant d'écrire un
scheduler from scratch, même si leur stockage sous-jacent (buffers `text`/`sequence`) est remplacé
par `clip-io.pd`.

### Contrat à honorer côté WebSocket

Voir `PD_WORK.md` intégralement — c'est le patch principal qui doit émettre `clock`,
`loops.states[]` (+ `source`), `scenesList` (+ `harmony` + `sirens[]`), `sceneLoaded`,
`composition`, et recevoir `clock.bpm`/`clock.signature` depuis l'écran.

---

## 3. Points de contact entre les deux patches

```
Sirénium (live) ──┬────────────────────────────────────────┐
                   │                                        ├──→ Harmoniseur v2 ──→ sirens (UDP)
                   └──→ Enregistreur (deltaTicks) ──→ clip-io.pd (record) ┐
                                                                          │
clip-io.pd (read) ──→ dump_notes ──→ Lecteur (metro) ────────────────────┴──→ (ligne rejouée, même entrée que le live ci-dessus)
```

- **Le patch principal pilote `clip-io.pd`** : quel `clipId` charger (`read`) selon la scène
  active, quand démarrer/arrêter un enregistrement (`record`/`stop`) selon les pédales
  (`PEDALIER_MAPPING.md`, `pedal.rec.play`/`pedal.stop.selected` — logique à récupérer du
  séquenceur retiré si elle est encore pertinente, juste déplacée).
- **Le tap d'enregistrement se fait en amont de l'harmoniseur** (`SCENES_SPEC.md §9`) — la ligne
  brute Sirénium part à la fois vers l'harmoniseur (pour jouer) et vers `clip-io.pd` (pour
  enregistrer), **pas** la sortie déjà harmonisée.
- **L'harmoniseur ne connaît pas `clip-io.pd` directement** dans le sens écriture — il reçoit soit
  la ligne live, soit une ligne rejouée (peu importe qu'elle vienne d'un clip ou d'ailleurs), et
  arbitre entre les deux selon la priorité (encore à trancher, voir §1).
- **Le patch principal sérialise l'état vers le WebSocket** (via `pdjson`, probablement en
  remplacement de `voices2json`/`clock2json`/`jsonStructure` identifiés dans l'inventaire §1) —
  l'harmoniseur ne parle pas au WebSocket directement.

---

## 4. Ce qui reste à trancher avant de patcher

Reprises de `PD_WORK.md` et `SCENES_SPEC.md §14`, elles bloquent une partie du travail :

1. Priorité d'arbitrage à l'entrée de l'harmoniseur (live vs rejoué) — §1 ci-dessus.
2. Moteur de `stop`/`mute` (coupé ou rotation à vide ?).
3. Rôle de `clip write` (CC 19) si l'inscription en scène est déjà automatique.
4. Système de couleur des notes (cartouche neutre en attendant).
5. Où vivent les markers d'extraction (`.rpp` source ou `.midi` exporté) — `MIDI_LIBRARY_PREP.md §4`.
6. Quel contrôle physique sélectionne une 8ème sirène éventuelle — `SCENES_SPEC.md §15`, reporté.
7. Tempo courant ou tempo figé à l'enregistrement, pour le calcul des `deltaTicks` (enregistreur) et
   la vitesse de lecture (lecteur) — probablement la même réponse pour les deux, §2 ci-dessus.
8. Résolution du `metro` du lecteur — proposition 10 ms, pas encore validée.

## 5. Ce que ce doc ne tranche pas encore

- Le détail fonctionnel de chaque sous-patch de l'inventaire §1 (catégorisation par nom seul, pas
  vérifiée un par un) — à affiner au fur et à mesure du portage.
- La liste exacte du cherry-picking pour le patch principal (§2) — une grille de candidats, pas une
  décision.
- Le format exact des messages entre le patch principal et `clip-io.pd`/l'harmoniseur (noms de
  `send`/`receive` Pd, ou connexions directes si tout vit dans le même patch) — dépend de la
  structure retenue (un seul gros patch vs plusieurs fichiers `.pd` qui s'incluent).
