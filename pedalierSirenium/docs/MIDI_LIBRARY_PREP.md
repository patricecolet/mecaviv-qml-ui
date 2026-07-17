# Préparer la bibliothèque MIDI existante pour le pédalier

Comment les projets déjà composés dans `~/repo/mecaviv/compositions` deviennent une source de
matériau pour le pédalier — réinterprétation live et extraction en clip
([`SCENES_SPEC.md` §11](SCENES_SPEC.md)).

**Tout ce qui suit est vérifié sur de vrais fichiers**, pas supposé — plusieurs `.midi` lus
directement (parseur SMF minimal, sans dépendance) dans `louette/`, `patwave/`, `stage/`, `covers/`.

---

## 1. Ce qui existe déjà

`~/repo/mecaviv/compositions` est une vraie bibliothèque, organisée par « artiste »/projet
(`louette`, `patwave`, `stage`, `Rimbert`, `covers`, `gyrophones`) :

- `<artiste>/Midi/*.midi` — export MIDI plat, un fichier par morceau.
- `<artiste>/reaper/<Morceau>/<Morceau>.rpp` — le projet Reaper source, souvent avec des
  variantes/versions dans des sous-dossiers.
- `compos.v2.json` — un **manifeste existant** qui indexe déjà les morceaux et leurs versions par
  artiste (`{name, versions: [{name}]}`). À **étendre**, pas à dupliquer, si on doit y ajouter des
  champs pédalier (points d'extraction, etc.) — pas besoin d'un nouvel index séparé.
- `scripts/` contient déjà des scripts d'analyse F# (`composition.stats.fsx`,
  `parsereaper.fsx`) et leurs sorties (`notes.min.maxes.per.channel.tsv`). `parsereaper.fsx` est
  exploratoire (impression d'arbre) et à chemins Windows codés en dur — pas directement réutilisable
  tel quel.

## 2. Convention déjà en place — bonne nouvelle, pas de remapping nécessaire

Vérifié sur `louette/Midi/timbales-court.midi`, `stage/Midi/padhelbel.midi`,
`covers/Midi/LaPasserellaD'Addio.midi` :

- Format SMF 1, **480 ticks par noire**.
- **Piste 0** : nommée d'après le morceau — tempo et méta-événements (convention SMF standard).
- **Une piste par sirène, nommée `S1`…`S7`**, sur les **canaux MIDI 0 à 6** — exactement la
  convention de `sirenSpec.js`. Aucune conversion de canal à prévoir.
- **Ordre des pistes déjà en hauteur** dans deux des trois fichiers : `S3 S4 S1 S2 S5 S6 S7` —
  exactement l'ordre grave→aigu déjà posé dans le modèle (`voicing`, mémoire `siren-pitch-order`).
  Pas une convention que ce document invente : c'est déjà comme ça que ces morceaux sont écrits.
- Piste optionnelle **`Clic`** (canal 9 dans le fichier `louette`/`patwave` vu) — **résolu** : les
  canaux au-delà de 8 sont réservés à **d'autres machines** du système, pas aux sirènes. Règle à
  appliquer partout : l'extraction pédalier ne regarde **que les canaux 0-6** (S1-S7) ; tout canal
  ≥ 8 est hors périmètre par construction, à ignorer sans exception, quel que soit son nom de piste.

**Non vérifié à ce stade** : est-ce que cette convention (S1-S7, canaux 0-6) tient sur les ~58
morceaux de la bibliothèque entière, ou seulement sur les quatre fichiers échantillonnés ? À
confirmer avant d'automatiser quoi que ce soit dessus.

## 3. Deux modes d'extraction distincts — à ne pas confondre

Ta précision (« extraire à la volée des parties spécifiques, telle piste à tel endroit ») pointe
vers un mode plus simple que ce qui était envisagé en `SCENES_SPEC.md §11` :

### a) Extraction directe d'une piste — le cas courant pour cette bibliothèque

Les pistes sont **déjà assignées à une sirène** (S1…S7). Extraire « S4 à tel endroit », c'est
prendre ce matériau **tel quel** et en faire un clip pour S4 — **sans repasser par l'harmoniseur**.
Ça correspond au modèle `source: "clip"` déjà en place, pas au chemin harmonique.

Puisque la piste est déjà nommée sans ambiguïté, le problème de désambiguïsation soulevé en
`SCENES_SPEC.md §11/§14` (« un marker SMF est global, pas attaché à une piste ») **ne se pose pas
ici** : il suffit d'un marker de **position** (début, fin/bouclage) + de choisir la piste déjà
nommée au moment de l'extraction. Pas besoin d'encoder le nom de piste dans le marker.

### b) Réinterprétation via l'harmoniseur — cas différent, toujours valable

Une ligne (portée par une des pistes S1-S7, ou une piste dédiée si le morceau en a une) traverse
l'harmoniseur en direct, comme si le Sirénium la jouait — c'est le cas déjà spécifié en §11, qui
reste pertinent pour réharmoniser un matériau existant plutôt que le rejouer tel quel.

**Les deux modes coexistent** : selon le geste au pédalier, une piste s'extrait directement (a) ou
se réinterprète (b). À toi de dire si les deux doivent être accessibles, ou si l'un des deux suffit
pour l'usage réel.

## 4. Où vivent les markers — fichier exporté ou projet Reaper ?

Reaper a son propre système de régions/markers, natif au `.rpp`. Deux options, pas encore
tranchées :

- **Marquer dans le `.rpp`** (source), puis réexporter en `.midi` avec les markers Reaper
  convertis en meta-events *Marker* SMF (à vérifier : les réglages d'export Reaper préservent-ils
  les régions comme markers SMF ? à confirmer dans Reaper directement).
- **Marquer directement le `.midi` exporté**, via `midifile` (`meta <type> <data>`,
  `PATCH_REBUILD.md §2`) — plus proche du pipeline pédalier, mais désynchronisé du projet Reaper
  source si celui-ci est réédité.

## 5. Questions ouvertes

- La convention S1-S7/canaux 0-6/ordre de hauteur tient-elle sur toute la bibliothèque (~58
  morceaux), ou varie-t-elle par artiste/époque ?
- Les deux modes d'extraction (§3a direct, §3b harmonisé) sont-ils tous les deux nécessaires côté
  pédalier, ou un seul suffit pour l'usage réel ?
- Marquer le `.rpp` source ou le `.midi` exporté (§4) — lequel reste la source de vérité ?
- `compos.v2.json` : bon endroit pour indexer les points d'extraction une fois définis, ou un index
  séparé est préférable ?
