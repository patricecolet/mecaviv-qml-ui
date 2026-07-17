# Travail PureData — ce que PD doit produire

Checklist du côté **PureData** (patché par Patrice) pour alimenter l'afficheur 2D. Le QML est
construit contre ce contrat, avec des données simulées, en parallèle. Tant que les messages
ci-dessous sont émis dans ce format, les deux moitiés avancent séparément.

Références : [`SCENES_SPEC.md`](SCENES_SPEC.md) (modèle scènes/clips/harmonie),
[`PEDALIER_MAPPING.md`](PEDALIER_MAPPING.md) (contrôleurs physiques).

Transport : WebSocket `ws://localhost:10000`. JSON (texte) pour l'état ; binaire 1–3 octets pour le
MIDI temps réel. Le QML **envoie** aussi en binaire (`sendBinaryMessage`) — ne pas casser ça.

---

## Ce qui existe déjà — à garder

- `SIREN_LOOPER.loops` : `main_loop`, `states[]` avec `transport`, `current_bar`, `loopSize`,
  `revolutions`. **Déjà bon.** `main_loop` alimente le marquage de la boucle de référence ;
  le dernier champ de `loopSize` (le rapport en puissance de 2) alimente l'échelle des paliers.
- `SIREN_LOOPER.clock` : `bpm`, `beat`, `bar`. **Déjà bon** — l'horloge et le battement en vivent.
- `LOOPER_SCENES` `scenesList` / `sceneLoaded` / `sceneSaved` : structure de base présente.
- MIDI binaire (note/vélocité/bend) : conservé pour la **sonde de diagnostic** uniquement (le
  pupitre porte la portée, pas le pédalier).

---

## À faire

### 1. Restructurer scènes et clips — le mode sort du clip

Voir `SCENES_SPEC.md §1–2`. Aujourd'hui `loop.definition.txt` mêle matériel et état de lecture.
Cible :

- **Clip = matériel nu** : `loop.N.txt` + propriétés intrinsèques (taille, rapport, statut de
  référence). Plus de mode dedans.
- **Scène = couche** : 7 cellules `(clipRef, mode)` + bloc `harmony`. Pool de clips partagé (déjà en
  place sous forme de dossiers `clip_XXX/`).

### 2. Enrichir `scenesList` — l'état des 7 sirènes par scène

Voir `SCENES_SPEC.md §6`. Ajouter, par scène : le bloc `harmony` et le tableau `sirens[]` (mode +
clipRef par sirène). Aujourd'hui `saveScene` ne route que `globalSceneId sceneId page sceneName`.

### 3. NOUVEAU — flux « source par sirène » en temps réel

C'est **l'ajout le plus important**, et il n'existe pas encore. L'écran doit montrer, à chaque
instant, ce que **chaque sirène fait vraiment** — parce que le direct (harmoniseur) peut voler une
sirène à sa scène (« le dernier joué prime »). La carte des scènes dit le *réservé* ; ce flux dit le
*réel*.

Étendre chaque entrée de `loops.states[]` avec un champ **`source`** :

```json
{
  "device": "SIREN_LOOPER",
  "loops": {
    "main_loop": 3,
    "states": [
      { "siren_id": 1, "source": "clip",  "transport": "playing", "loopSize": 8, "ratio": 2, "revolutions": 3 },
      { "siren_id": 2, "source": "voice", "degree": 4 },
      { "siren_id": 3, "source": "lead" },
      { "siren_id": 4, "source": "rec",   "loopSize": 4, "ratio": 1 },
      { "siren_id": 5, "source": "free" },
      { "siren_id": 6, "source": "out" }
    ]
  }
}
```

`source` ∈ :
- `clip` — rejoue un clip de la scène (looper) ; garde `transport`/`loopSize`/`ratio`/`revolutions`.
- `voice` — porte une voix de l'harmoniseur ; ajoute `degree` (intervalle en degrés de gamme).
- `lead` — tient la ligne du Sirénium.
- `rec` — sa voix live s'enregistre dans une boucle.
- `free` — éligible, disponible, ne joue rien.
- `out` — écartée de l'accord (non éligible).

C'est ce champ qui distingue **éligibilité** (`out` vs le reste) et **activité** (les autres
valeurs). Il n'a pas besoin d'être rapide comme le MIDI — un rafraîchissement à ~10 Hz suffit.

### 4. Signal « morceau modifié / non enregistré »

Le clip entre dans la scène immédiatement, mais la permanence demande de sauver le morceau
(`SCENES_SPEC.md §5`). Émettre un état `dirty` pour que l'écran le signale :

```json
{ "device": "LOOPER_SCENES", "composition": { "id": 12, "dirty": true } }
```

### 5. Poser le voicing au pied → écrire `scene.harmony.voicing`

Quand le poussoir est maintenu et qu'un accord est joué (voir `PEDALIER_MAPPING.md`, clavier
CC 26–39 + poussoir), extraire les intervalles et les écrire dans le `voicing` de la scène courante.
Les touches naturelles sélectionnent les sirènes éligibles. Répartition **par hauteur**
(S3 S4 S1 S2 S5 S6 S7), repliée dans l'ambitus de `sirenSpec`.

### 6. Composition — le grand pédalier

Émettre l'identité du morceau courant et son nombre de banques :

```json
{ "device": "LOOPER_SCENES", "composition": { "id": 12, "name": "Vertiges", "banks": 3 } }
```

Changer de morceau (grand pédalier, CC ~61–91) remplace le jeu de scènes entier.

### 7. NOUVEAU — tempo et signature éditables à l'écran (écran → PD)

Exception délibérée au principe « écran en lecture seule » : tempo et signature sont modifiables
directement sur l'écran, **dans les deux modes (jeu et config)**. Deux messages sortants —
l'écran envoie, PD doit recevoir.

**Tempo** — existe déjà côté ancien code, réutilisé tel quel :

```json
{ "device": "SIREN_LOOPER", "clock": { "bpm": 132 } }
```

**Convention à confirmer avec PD : le BPM est ancré sur la noire, toujours**, indépendamment du
dénominateur de la signature — ce n'est pas une évidence, à vérifier que PD fait pareil. Une croche
dure exactement la moitié d'une noire, une double-croche le quart : c'est arithmétique, pas musical
au sens interprétatif. Vérifié sur cet exemple : à 60 BPM, une mesure de 3/4 dure 3 s (3 noires
à 1 s) et une mesure de 6/8 dure **aussi** 3 s (6 croches à 0,5 s) — même durée réelle, la croche
tourne deux fois plus vite. Le calcul côté écran (`SimulationHarness._tick`) applique cette règle :
`durée d'unité = (60000 / bpm) × (4 / signatureDen)`. **Si PD ancre son BPM différemment (ex. sur
le temps ressenti plutôt que sur la noire), il y aura un décalage silencieux entre ce que l'écran
affiche et ce que PD joue** — à trancher avant l'intégration réelle.

**Signature** — n'existait nulle part avant cette décision. Même namespace `device`/`clock` que
le tempo. Deux réglages **indépendants**, et attention au vocabulaire — le dénominateur donne la
**valeur** (4 = noire, 8 = croche, 16 = double-croche), le numérateur compte combien de **ces
unités-là** remplissent la mesure. **7/8 = 7 croches, pas 7 temps.**

- **numérateur** : nombre d'unités de la valeur donnée par le dénominateur, réglable par pas de 1,
  de **1 à 21** ;
- **dénominateur** : limité aux valeurs usuelles **4 / 8 / 16**, cyclé au tap plutôt que réglé
  par pas.

Envoyée en chaîne `"N/D"` déjà composée :

```json
{ "device": "SIREN_LOOPER", "clock": { "signature": "7/8" } }
```

PD doit à la fois **recevoir** ce message et **répondre** en échoïsant la nouvelle valeur dans le
flux `clock` habituel, comme il le fait déjà pour `bpm` — l'écran affiche ce que PD confirme, pas
seulement ce qu'il a demandé.

#### Les vrais temps sont un champ à part : `groups`

Le nombre de temps musicaux n'est **pas** le numérateur — c'est un groupage. 7/8 se joue en général
2+2+3 (deux temps de deux croches, un de trois), pas en sept temps égaux. Ce groupage dépend de la
pièce et se règle comme sur une horloge musicale classique (à la MIDI), il n'est pas déductible
d'une formule unique côté écran.

**PD doit fournir ce groupage explicitement**, en plus de `signature` :

```json
{ "device": "SIREN_LOOPER", "clock": { "signature": "7/8", "groups": [2, 2, 3] } }
```

`groups` est un tableau d'entiers dont la somme vaut le numérateur ; chaque entrée est la taille
d'un temps, en unités du dénominateur. Pour une mesure simple (4/4), `groups: [1,1,1,1]`.

**État actuel côté écran** : en l'absence de `groups` reçu, un calcul par défaut s'applique
(`SimulationHarness._computeDefaultGroups`) — groupes de 3 pour les mesures composées classiques
en /8 (6, 9, 12), sinon remplissage par paires avec un dernier groupe absorbant le reste (7/8 →
`[2,2,3]`). **C'est un bouche-trou pour la démo, pas une vérité musicale** — dès que PD envoie
`groups`, l'écran doit l'utiliser à la place, sans discussion.

---

## Décisions à trancher avant de patcher

Reprises de `SCENES_SPEC.md §8`, elles bloquent une partie du travail :

1. **Moteur de `stop` et `mute`** : coupé (→ latence de reprise, à montrer par les RPM) ou en
   rotation à vide ? Décide ce que `source: "clip"` avec un mode silencieux envoie côté RPM.
2. **Rôle de `clip write` (CC 19)** si l'inscription en scène est déjà automatique.
3. **Système de couleur des notes** : le cartouche d'accord est en neutre faute de convention. Si
   les notes ont un code couleur (par hauteur/classe), le définir — il ne doit pas croiser les
   couleurs de sirènes.

---

## Récapitulatif du contrat de messages

| Message | Sens | État |
|---|---|---|
| `SIREN_LOOPER.clock` | PD → écran | existe |
| `SIREN_LOOPER.loops.states[]` + **`source`** | PD → écran | **à étendre (§3)** |
| `LOOPER_SCENES.scenesList` + `harmony` + `sirens[]` | PD → écran | **à enrichir (§2)** |
| `LOOPER_SCENES.sceneLoaded` | PD → écran | existe |
| `LOOPER_SCENES.composition` (id, name, banks, dirty) | PD → écran | **nouveau (§4, §6)** |
| MIDI binaire (note/vél/bend) | PD → écran | existe — sonde seulement |
| `SIREN_LOOPER.clock.bpm` | écran → PD | existe (ancien code, réutilisé — §7) |
| `SIREN_LOOPER.clock.signature` | écran → PD | **nouveau (§7)** |
| `SIREN_LOOPER.clock.groups` | PD → écran | **nouveau (§7)** — les vrais temps, groupés ; sans lui l'écran approxime |

Côté QML, il restera à câbler ce que `SceneManager.loadScenesFromServer` jette aujourd'hui, à
inverser la numérotation `SceneGrid` (bas 1-4 / haut 5-8 → ordre haut-bas gauche-droite), et à
brancher le flux `source` sur les anneaux.
