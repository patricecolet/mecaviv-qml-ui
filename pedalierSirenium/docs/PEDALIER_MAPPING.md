# Mapping du pédalier Sirenium

Ce document décrit ce que chaque contrôle physique du pédalier envoie, et ce que PureData renvoie
pour allumer ses LEDs.

> **Attention — deux couches à ne pas confondre.**
> Les **numéros de contrôleur** sont du matériel : ils sont figés, ils identifient un objet
> physique. Les **fonctions** qui leur sont associées plus bas sont du *design*, elles datent d'une
> version antérieure et sont **ouvertes à la refonte**. Ne pas lire ce document comme une
> spécification à reproduire.

**Sources**, par ordre d'autorité :

1. L'inventaire matériel —
   [Google Sheets, onglet `1011614034`](https://docs.google.com/spreadsheets/d/1LTnEgYfVpFBTAgfd6xlL7Uy5ax5Er7T9-mhmfIBq0Ks/edit?gid=1011614034#gid=1011614034).
   C'est la version courante, et c'est elle qui fait foi pour les numéros.
   L'onglet `73822960` est un **vieux design** : ses numéros restent bons, ses fonctions non.
2. `mecaviv/puredata-abstractions/examples/MidiToSiren.pd` — le patch lancé par
   `scripts/start.pedalier.sh`. Ses commentaires de plage sont parfois périmés (copier-collés) ;
   l'arithmétique (`- 50`, `moses`) est fiable, les commentaires non.

Tout passe par des **Control Change**, jamais des notes. Les LEDs repartent en `ctlout` sur le
**canal 9** (`control.midi.routing`).

---

## Inventaire matériel — cinq appareils réseau

Le « pédalier » n'est pas un objet mais un **système de cinq appareils**, chacun avec son IP, tous
sur le canal 9 sauf le Sirénium. « Entrée » = ce que l'appareil reçoit (ses LEDs) ; « sortie » = ce
qu'il envoie (ses boutons).

| Appareil | IP | Canal | Sorties (boutons) | Entrées (LEDs) |
|---|---|---|---|---|
| **Pedalier Sirenium** | .20 | 9 | Boutons **10–17**, Pédalier **18–25**, Grand Pédalier (clavier) **26–39** | LED jaune **10–16**, LED pedal **18–25**, LED rouge **26–32** |
| **Pédale BOSS** | .25 | 9 | Boutons **43–46**, Pédales **47–50** (plage continue) | LED **43–46** |
| **La Petite Boîte** | .26 | 9 | Boutons **51–58** | LED **51–58** |
| **Grosse Boîte à bouton** | .27 | 9 | Boutons **61–91** | LED **61–91** |
| **SIRENIUM** | .10 | 11 | Notes → .113, .103, .15 (si jumper) | — |

Soit environ **59 contrôles** et **54 LEDs**. Trois faits qui comptent pour le design :

- **Le pédalier a autant de LEDs que de contrôles.** Chaque bouton peut s'éclairer. C'est une
  surface de retour entière, sous les pieds, en plus de l'écran.
- **La Grosse Boîte a 31 boutons** (61–91) — de quoi lancer 31 compositions.
- **Les LED pedal 18–25 existent en matériel mais PureData ne les allume pas** : `led.pedal.board`
  envoie vers `midi.pedalier.sirenium-r.old`, un nom que personne ne reçoit. Huit LEDs disponibles.
- **La BOSS expose 4 pédales continues (47–50)**, mais `pedals.modulators` n'en route que trois
  (`route 47 48 49`). Une pédale d'expression est libre.

---

## Fonctions actuelles (vieux design — pour information)

- **Roland PK-6 reconditionné** — clavier d'orgue, 13 touches sensibles à la vélocité
  (8 naturelles, 5 dièses), une octave chromatique. La feuille les appelle *pédales de notes*.
- **8 pédales de commande** — poussoirs situés au-dessus du clavier, numérotés **de gauche à
  droite** en CC 18 → 25.
- **7 boutons de sirène** — un par sirène, avec LED jaune de présélection.
- **Petit boîtier** — 8 boutons, **charge les scènes** (`pedals.littlebox.buttons`).
- **Gros boîtier** — **lance des compositions entières** (`pedals.bigbox.buttons`).
- **3 pédales d'expression** — la première porte 2 interrupteurs, les deux autres 1 chacune.

Le périphérique est reconnu côté ALSA sous le nom **`FS-1-WL`** (`autoConnectPedal`, qui le
reconnecte automatiquement toutes les 10 s via `aconnect`).

### Trois niveaux d'organisation

Une **composition** (gros boîtier) contient des **scènes** (petit boîtier). Une scène est l'état
des 7 boucles. Une boucle rangée est un **clip** (`set.clip.slot`, stockage `$0.looper.clips`).

---

## Entrées — du pédalier vers PureData

### Sélection de sirène — CC 10 à 17

| CC | Fonction |
|---|---|
| 10 – 16 | Sirènes 1 à 7 (présélection — **LED jaune**) |
| 17 | Toutes les sirènes |

Traité par `pedals.stop`, qui retire 9 pour retrouver le numéro de sirène et émet `pedal.stop` /
`pedal.stop.all`.

### Pédales de commande — CC 18 à 25, de gauche à droite

| CC | Fonction | Appui long (3000 ms) |
|---|---|---|
| 18 | Clear all loops | |
| 19 | Clip write | |
| 20 | Clip play / stop | |
| 21 | Tempo (`led.pedal.tempo` ; case vide dans la feuille) | |
| 22 | Reset de la sirène courante | → reset de **toutes** les sirènes |
| 23 | Boucle présélectionnée suivante | |
| 24 | Stop de la boucle courante | → **clear** de la boucle courante, *après confirmation* |
| 25 | Rec / play de la boucle courante | |

Ces huit CC sont traités par `pedals.rec/play` (nommé d'après sa fonction principale, mais il filtre
toute la plage 18-25).

**Deux appuis longs de 3 s existent, et l'un d'eux demande une confirmation.** C'est une mécanique
temporelle avec un état intermédiaire — elle a besoin d'un retour visuel, sans quoi l'interprète ne
sait ni que le compte à rebours court, ni qu'une confirmation est attendue.

### Autres entrées

| Plage CC | Contrôle | Effet | Sous-patch |
|---|---|---|---|
| **26 – 42** | Clavier PK-6 (*pédales de notes*) | `- 26` → `route 0 2 4 5 7 9 11` → sélection de sirène 1-7 → `$0.loop.voice.select` | `pedals.piano` |
| **43 – 46** | 4 interrupteurs montés sur les pédales d'expression | combinés au numéro de pédale (voir plus bas) | `pedals.modulators` |
| **47 – 49** | 3 pédales d'expression (continues) | `$0.modulation.pedal` | `pedals.modulators` |
| **53 – 60** | 8 boutons du petit boîtier | `- 50` → charge une scène → `$0.looper.scene.select.json` | `pedals.littlebox.buttons` |
| **~91 +** | Boutons du gros boîtier | lance une composition (`moses 91` ; plage exacte à confirmer) | `pedals.bigbox.buttons` |

### Le clavier sélectionne les sirènes

`pedals.piano` retire 26 puis route `0 2 4 5 7 9 11` — les degrés d'une gamme majeure, donc les
**touches naturelles** :

| Touche | CC | Sirène |
|---|---|---|
| Do | 26 | S1 |
| Ré | 28 | S2 |
| Mi | 30 | S3 |
| Fa | 31 | S4 |
| Sol | 33 | S5 |
| La | 35 | S6 |
| Si | 37 | S7 |

Les **5 dièses ne sont branchés à rien** : ils tombent à côté du `route`. Ce sont cinq contrôles
disponibles.

---

## Les 8 pédales d'expression virtuelles

Il y a **3 pédales physiques** mais `pedalId` va de **1 à 8** dans la matrice de modulation
(`SIREN_PEDALS.pedalConfigChange`). `pedals.modulators` fait la conversion : l'état des
interrupteurs (`* 2`) s'ajoute à un décalage propre à chaque pédale (`list prepend 0 / 4 / 6`).

| Pédale | CC | Interrupteurs | Décalage | Donne accès à |
|---|---|---|---|---|
| A | 47 | 43, 44 | 0 | pédales virtuelles **1 – 4** |
| B | 48 | 45 | 4 | pédales virtuelles **5 – 6** |
| C | 49 | 46 | 6 | pédales virtuelles **7 – 8** |

Deux interrupteurs offrent quatre combinaisons, un seul en offre deux : 4 + 2 + 2 = **8**.

C'est **la clé de lecture de la matrice 448** : un `pedalId` n'est pas un objet physique, c'est une
combinaison pédale + interrupteurs. Ses 56 valeurs (7 sirènes × 8 paramètres) sont les
**profondeurs en butée** appliquées quand cette pédale est enfoncée à fond.

---

## Sorties — LEDs, de PureData vers le pédalier

Envoyées en `ctlout` **canal 9**. Pour une sirène `N` de 1 à 7 :

| État | CC | Plage | Sous-patch |
|---|---|---|---|
| Sirène **sélectionnée** | `9 + N` | 10 – 16 | `led.siren.selected` |
| Sirène **en lecture** | `17 + N` | 18 – 24 | `led.siren.playing` |
| Sirène **en enregistrement** | `25 + N` | 26 – 32 | `led.siren.recording` |

Les LEDs réutilisent les numéros des boutons correspondants — entrée et sortie ne se marchent pas
dessus puisqu'elles vont dans des directions opposées.

Autres retours : `led.pedal.selection`, `led.pedal.preselection` (jaune), `initLED` (extinction au
démarrage), `tempo.to.led`.

**À connaître avant de dessiner un écran** : le pédalier signale déjà sous les pieds, par ses LEDs,
quelle sirène est sélectionnée, laquelle joue, laquelle enregistre, et le tempo. L'écran n'est pas
la seule surface de retour.

---

## `led.pedal.board` — numérotation juste, sortie débranchée

Ce sous-patch associe les huit fonctions aux CC 18-25, et **la feuille de référence le confirme
exactement**. Sa numérotation est bonne.

En revanche son unique sortie part vers `s midi.pedalier.sirenium-r.old`, **un nom que personne ne
reçoit** : le retour LED des pédales de commande ne part donc jamais. Le chemin vivant est
`midi.pedalier.sirenium-r`, alimenté par `led.siren.selected` / `playing` / `recording`,
`led.pedal.selection`, `led.pedal.preselection`, `initLED` et `tempo.to.led`.

Autrement dit : les LEDs **par sirène** fonctionnent, celles **des huit pédales de commande** sont
mortes. À vérifier sur le matériel avant d'en conclure quoi que ce soit.

---

## Non résolu

- **Plage exacte du gros boîtier** : son commentaire annonce `filters controllers 26 to 42`, ce qui
  est la plage du clavier — copier-coller qui a vieilli. Son `moses 91` indique une plage autour de
  91, mais le nombre de boutons et la correspondance bouton ↔ composition restent à établir.
- **CC 21** : `led.pedal.board` dit *tempo*, la feuille laisse la case vide.
- **Confirmation du clear** (CC 24, appui long) : la mécanique existe côté feuille, mais on ignore
  quel geste confirme et ce qui est censé l'annoncer.

---

## Ce que le QML ignore de tout ça

`pedalierSirenium` ne voit **rien** de ce mapping : il reçoit l'état des boucles et des scènes déjà
digéré par PureData, en JSON. Trois notions de « pédale » coexistent dans le QML sans jamais se
parler ni correspondre à ce document :

- `selectedPedalId` (1-8) — la pédale virtuelle dont on édite la matrice ;
- `pedalPosition` (1-8) dans `SceneGrid` — l'étiquette d'un emplacement de scène, qui correspond en
  réalité aux boutons **53-60** du petit boîtier ;
- `siren.pedalActive` — un booléen par sirène venu de `voice.pedal`.

Unifier ce vocabulaire sur celui de la feuille et du patch est un préalable à tout écran de
configuration.
