# Mapping du pédalier Sirenium

Ce document décrit ce que chaque contrôle physique du pédalier envoie, et ce que PureData renvoie
pour allumer ses LEDs.

> **Attention — deux couches à ne pas confondre.**
> Les **numéros de contrôleur** sont du matériel : ils sont figés, ils identifient un objet
> physique. Les **fonctions** qui leur sont associées plus bas sont du *design*. Une partie a été
> refondue le **25 juillet 2026**, puis à nouveau le **31 juillet 2026**. C'est la section
> **« Entrées »** qui fait foi : elle porte la décision la plus récente. « Refonte » et « Fonctions
> actuelles » sont conservées comme état antérieur, avec les points qu'elles gardent de valables.

Le dessin annoté `pedalierSirenium.svg` (même dossier) porte ces fonctions sur la surface physique.

---

## Refonte (décidé le 2026-07-25)

- **Jeu à 7 sirènes.** Le rond 17 reste donc `toutes` ; la réserve « concevoir pour 8 » de la
  mi-juillet est mise de côté pour cette surface.
- ~~**Le clavier ne sélectionne plus les sirènes.**~~ **Renversé le 2026-07-31.** Cette refonte
  libérait le clavier pour en faire la surface d'accord et déplaçait la sélection sur les 8 boutons
  ronds. La décision du 31 juillet fait l'inverse : la sélection reste sur les **touches blanches du
  clavier** (26-37, ce que le patch fait déjà), et les boutons ronds passent au **transport**
  stop/play. **Reste sans domicile : la surface d'accord** — c'était tout l'objet de libérer le
  clavier, et il n'est plus libre.
- **Mode poly — piste en réflexion, pas figée** (Patrice, 2026-07-25 : « c'est possible que je change
  d'avis »). Elle occupait la pédale 19, que la rangée du 31 juillet réattribue à
  `scene play/stop` + `scene clear` : cette piste n'a donc plus de pédale non plus. Pédale active : les appuis sur les
  ronds **cumulent** les sirènes en jeu au lieu de remplacer la sélection ; le clavier donne
  l'**intervalle de la dernière sirène ajoutée**. Ne rien implémenter là-dessus sans revalider.
- **L'intervalle est une classe** (mod 12). L'octave où il sonne vient de l'**ambitus de la
  sirène**, pas de l'accord. Conséquence : choisir *quelles* sirènes entrent dans l'accord **est**
  la décision de voicing — S3 ou S5 pour la quinte, c'est le même intervalle dans deux registres.
- **Tap tempo conservé** sur la pédale 21 (la case vide de la feuille est donc tranchée).

Restent ouverts : la règle exacte de choix d'octave dans l'ambitus (les ambitus se chevauchent de
près de trois octaves, voir plus bas), et l'encodage de l'état du clip sur une seule LED rouge.

**Sources**, par ordre d'autorité :

1. L'inventaire matériel —
   [Google Sheets, onglet `1011614034`](https://docs.google.com/spreadsheets/d/1LTnEgYfVpFBTAgfd6xlL7Uy5ax5Er7T9-mhmfIBq0Ks/edit?gid=1011614034#gid=1011614034).
   C'est la version courante, et c'est elle qui fait foi pour les numéros.
   L'onglet `73822960` est un **vieux design** : ses numéros restent bons, ses fonctions non.
2. `mecaviv/puredata-abstractions/examples/pedalier.pd` — **le patch réellement lancé** : c'est lui
   que `deploy/pedalier-ctl.sh` démarre sur le Pi (`PD_PATCH="pedalier.pd"`, sous systemd `--user`).
   `MidiToSiren.pd`, son prédécesseur, existe encore dans le même dossier mais n'est plus lancé ;
   `scripts/start.pedalier.sh` n'est plus qu'un stub de dépréciation. Dans les deux patchs, les
   commentaires de plage sont parfois périmés (copier-collés) : l'arithmétique (`- 50`, `moses`) est
   fiable, les commentaires non.

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
- **La Grosse Boîte a 31 boutons** (61–91), dont **29 lancent une composition** (61–89) : le 30e
  (CC 90) est le bouton d'inventaire (voir plus bas), le 31e (CC 91) n'est branché à rien.
- **Les LED pedal 18–25 existent en matériel** et le chemin est ouvert depuis le 2026-08-01 :
  huit `send` visaient `midi.pedalier.sirenium-r` sans `$0` — un vestige de `MidiToSiren.pd`, seul
  patch à porter le receive de ce nom — et sont passés sur `$0.midi.pedalier.sirenium-r`. Reste
  `led.pedal.board`, laissé volontairement sur `.old` (voir plus bas). Huit LEDs disponibles.
- **La BOSS expose 4 pédales continues (47–50)**, mais `pedals.modulators` n'en route que trois
  (`route 47 48 49`). Une pédale d'expression est libre.

---

## Fonctions actuelles (vieux design — pour information)

- **Roland PK-6 reconditionné** — clavier d'orgue, 13 touches sensibles à la vélocité
  (8 naturelles, 5 dièses), une octave chromatique. La feuille les appelle *pédales de notes*.
- **8 pédales de commande** — poussoirs situés au-dessus du clavier, numérotés **de gauche à
  droite** en CC 18 → 25.
- **7 boutons de sirène** — un par sirène, avec LED jaune. Ils portent le stop / play depuis le
  2026-07-31 ; la présélection qu'ils assuraient est passée sur le clavier.
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

### Transport par sirène — CC 10 à 17 (décidé le 2026-07-31)

| CC | Appui court | Appui long (400 ms) |
|---|---|---|
| 10 – 16 | **Stop / play** de la sirène 1 à 7 | **Delete** du clip de cette sirène |
| 17 | Stop / play de **toutes** les sirènes | — |

Un bouton par sirène : c'est le geste direct pour jouer avec les clips. Ces boutons portaient
auparavant la *présélection* de sirène ; celle-ci vit désormais sur le clavier (voir plus bas).

`pedals.stop/play` traduit le CC en **numéro de voix** (`text search $0.voices 6` →
`text get $0.voices 1`) et envoie `<voix> <0|1>` sur `$0.pedal.stop`. Le tri court/long se fait
ensuite **dans chaque `siren-clip-loader`**, qui filtre sur sa propre voix puis passe par
`pedal-press-duration` sans argument, donc au seuil par défaut de 400 ms.

**C'est du transport, pas de l'édition** : une boucle arrêtée est arrêtée, pas « non enregistrée ».
Le fichier de scène n'est pas touché. Vérifié dans le patch le 2026-07-31 — ni `siren-clip-loader`
ni `siren-loop-state` n'écrivent de scène, et les seuls `commit.mode` / `commit.clip` vont dans
l'autre sens : ils appliquent la scène au loader quand on la charge.

`mute`, `solo` et `oneshot` sont des modes secondaires, traités plus tard.

### Pédales de commande — CC 18 à 25, de gauche à droite (décidé le 2026-07-31)

Trois pédales portent **deux fonctions**, séparées par la durée d'appui. Le seuil est l'argument de
`pedal-press-duration` et diffère d'une pédale à l'autre : plus le geste est destructif, plus il
faut tenir longtemps.

| CC | Appui court | Appui long | Seuil | Envoi PD |
|---|---|---|---|---|
| 18 | **Rec / play** | — | — | `$0.pedal.play.rec` |
| 19 | **Scene play / stop** | **Scene clear** | 3 s | `$0.scene.play.stop` / `$0.scene.clear` |
| 20 | **Scene next** | — | — | `$0.scene.next` |
| 21 | **Scene write** | **Scene duplicate** | 2 s | `$0.scene.write` / `$0.scene.duplicate` |
| 22 | **New scene** | — | — | `$0.scene.new` |
| 23 | libre | — | — | — |
| 24 | **Tap tempo** | — | — | `$0.tempo.tap` |
| 25 | **Reset** de toutes les sirènes | — | — | `$0.siren.reset all` |

**L'ordre est celui de la portée croissante** : niveau clip (18-19), niveau scène (20-22), global
(24-25). Le geste le plus fréquent est sur la pédale la plus atteignable.

`scene clear` vide la scène **en mémoire** ; c'est `scene write` (CC 21) qui valide. Tant qu'on n'a
pas écrit, le geste est réversible. Voir `SCENES_SPEC.md` §5 : le patch écrit aujourd'hui chaque
édition immédiatement, ce modèle-là reste à construire.

CC 18 envoie le **numéro de voix** de la sirène présélectionnée, pas son numéro de sirène : il lit
`$0.loop.voice.select` tel quel, parce que c'est ce que les sept `siren-clip-loader` attendent sur
leur `route $4`. Sans sirène sélectionnée la valeur est `-1`, qui ne matche aucun loader — le
message part mais ne fait rien. Même espace de valeurs que `$0.pedal.stop` des boutons sirène.

CC 25 part **au relâché** (`sel 0`), pas à l'appui, contrairement aux autres.

Deux fonctions ont disparu de cette rangée, volontairement : « clear all loops » est devenue
`scene clear` (vider le *pool* est de l'entretien, sa place est à l'écran), et « boucle
présélectionnée suivante » n'a plus d'objet dès que chaque sirène a son bouton.

### Annoncer l'appui long — `pedal-press-duration` et `led-blink`

Un seuil de 2 ou 3 secondes n'est pas tenable sans retour : rien ne dit au pied s'il faut continuer
d'appuyer. `pedal-press-duration` porte donc **trois sorties** :

| Sortie | Émet | Quand |
|---|---|---|
| 0 `court` | bang | au relâché, si le seuil n'est pas atteint |
| 1 `long` | bang | **au seuil, pied encore au sol** — pas au relâché |
| 2 `attente` | `1` puis `0` | `1` à l'appui, `0` dès que `court` ou `long` est sorti |

`attente` est faite pour piloter la LED de la pédale. Le seuil est l'argument de création (défaut
400 ms, garde-fou `moses 100` : un argument absent ou aberrant laisse le défaut).

`led-blink` transforme ce `1` / `0` en clignotement à 120 ms, **valeur 127** comme le reste du
patch, avec un **timeout de 10 s** armé à l'allumage et annulé par le `0`. Dans tous les cas —
geste abandonné, `attente` perdu, expiration — la dernière valeur émise est `0` : la LED ne peut pas
rester allumée.

La chaîne complète, sur CC 19 comme sur CC 21 :

```
inlet → [pedal-press-duration 3000] ─[2 attente]→ [led-blink] → [$1 19] → s $0.midi.pedalier.sirenium-r
                                    ├[0 court]→ s $0.scene.play.stop
                                    └[1 long] → s $0.scene.clear
```

Vérifié par test headless sur le sous-patch extrait du fichier : un appui de 300 ms fait clignoter
deux fois puis émet `scene.play.stop` ; un appui tenu fait clignoter pendant les 3 s, éteint, puis
émet `scene.clear`. Le clignotement s'arrête **au seuil**, pas au relâché — le pied sait qu'il peut
lever.

### Autres entrées

| Plage CC | Contrôle | Effet | Sous-patch |
|---|---|---|---|
| **26 – 37** | Clavier PK-6 — **les sept touches blanches**, do à si | `- 26` → `route 0 2 4 5 7 9 11` → sélection de sirène 1-7 → `$0.loop.voice.select` | `pedals.piano` |
| **27, 29, 32, 34, 36** | Clavier PK-6 — **les cinq touches noires** | mode poly sur l'une, sélection de la voix sur une autre — **règle à discuter**. Trois restent libres, plus la huitième blanche (38). | à construire |
| **43 – 46** | 4 interrupteurs montés sur les pédales d'expression | combinés au numéro de pédale (voir plus bas) | `pedals.modulators` |
| **47 – 49** | 3 pédales d'expression (continues) | `$0.modulation.pedal` | `pedals.modulators` |
| **53 – 60** | 8 boutons du petit boîtier | `- 50` → charge une scène → `$0.looper.scene.select.json` | `pedals.littlebox.buttons` |
| **61 – 89** | 29 boutons du gros boîtier | `- 61` → `compoSelect <n>`, **0-based** → ouvre la n-ième composition | `pedals.bigbox.buttons` |
| **90** | 30e bouton du gros boîtier | **inventaire** : tant qu'on appuie, les LEDs 61+ des boutons qui portent une composition s'allument | `pedals.bigbox.buttons` → `led.compo.available` |
| **91** | 31e bouton du gros boîtier | rien | — |

**Le rang du bouton n'est pas le nom de la composition.** `composition-io` remplit sa table par
`file glob <racine>/*` : les compositions occupent donc toujours les **N premiers** boutons, dans
l'ordre alphabétique du nom de dossier — aujourd'hui `comp_12` = bouton 1, `comp_7` = bouton 2.
C'est ce que le bouton 90 rend visible.

### Le clavier sélectionne les sirènes (état antérieur — supprimé par la refonte)

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

**Six touches ne sont branchées à rien**, pas cinq : les 5 dièses (27, 29, 32, 34, 36) **et le Do
aigu 38**, qui donne 12 après le `- 26` et tombe lui aussi à côté du `route 0 2 4 5 7 9 11`.

Cette redondance est ce que la refonte supprime : la sélection de sirène était faite **deux fois**,
par les ronds 10-16 avec LED et par les naturelles sans retour. Le clavier libéré redevient une
octave chromatique complète.

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

Envoyées en `ctlout` **canal 9**, via le bus `$0.midi.pedalier.sirenium-r`.

**L'ordre des atomes est `<valeur> <numéro de CC>`, pas l'inverse.** Le receive du bus fait
`list append 9` puis `ctlout`, qui attend `valeur, contrôleur, canal`. C'est pour ça que tous les
producteurs existants — `led.siren.selected` / `playing` / `recording`, `led.pedal.selection`,
`led.compo.available`, `initLED` — passent par un `swap` avant leur `pack` : ils construisent le CC
en premier et le renvoient en second. Une boîte `19 $1` envoie donc le CC 1 avec la valeur 19 ; il
faut écrire `$1 19`. L'erreur est silencieuse, aucun message ne la signale.

Pour une sirène `N` de 1 à 7 :

| État | CC | Plage | Sous-patch |
|---|---|---|---|
| Sirène **sélectionnée** | `9 + N` | 10 – 16 | `led.siren.selected` |
| Sirène **en lecture** | `17 + N` | 18 – 24 | `led.siren.playing` |
| Sirène **en enregistrement** | `25 + N` | 26 – 32 | `led.siren.recording` |

Les LEDs réutilisent les numéros des boutons correspondants — entrée et sortie ne se marchent pas
dessus puisqu'elles vont dans des directions opposées.

### Mais `led.siren.playing` écrit dans la rangée des pédales

Le matériel compte **22 LEDs**, et pas trois par sirène : une **jaune** (10-16) et une **rouge**
(26-32) sur chacun des 7 ronds, plus **une par pédale de commande** (18-25). C'est ce que dit
l'inventaire de la feuille, et c'est ce que Patrice confirme.

Or `led.siren.playing` fait `+ 17`, donc écrit sur **18-24** : « sirène 3 en lecture » allume la LED
de la pédale `scene next`. Et `led.pedal.board` revendique la même plage pour les huit pédales
(vérifié dans le patch : messages `$1 22`, `$1 23`, `$1 24`, `$1 25`). Les deux se battent sur 18-25
— c'est très probablement pourquoi la sortie de `led.pedal.board` a été renvoyée vers
`midi.pedalier.sirenium-r.old`, un nom que personne ne reçoit, plutôt que tranchée.

**Tranché le 2026-08-01, sur le dessin de `pedalierSirenium.svg`** : la plage 18-25 appartient aux
huit pédales de commande, une LED par fonction. Ce qui suppose deux déplacements :

- `led.siren.playing` (`+ 17` → 18-24) **quitte cette plage**. L'état du clip descend sur la LED
  rouge de la sirène, 26-32, avec `led.siren.recording` : **clignotement = enregistrement, continu =
  lecture**, éteint sinon. Une seule LED pour trois états, ce que le matériel impose de toute façon.
- La LED jaune (10-16) garde la présélection, seule, comme aujourd'hui.

Le retour des huit pédales passe par les sous-patchs de fonction, pas par `led.pedal.board`.

### Table de transitions de `siren-loop-state`

Mesurée le 2026-08-01 en headless, en instrumentant les cinq sorties de l'abstraction
(`record`, `playgate`, `stopclip`, `erase`, `state`) et en lui envoyant ses verbes entrecoupés de
`bar`. Les quatre états sont ceux que `$0.loader.state` diffuse et que `$0.loopstates` mémorise,
une ligne par sirène.

| État de départ | `recplay` | `stop` | `delete` |
|---|---|---|---|
| **0** vide | → **1** *au `bar` suivant*, `record` | rien | rien |
| **1** enregistre | → **2** *au `bar` suivant*, `stopclip`, `playgate 1` | → **3** immédiat, `stopclip` | → **0** immédiat, `erase` |
| **2** joue | → **1** *au `bar` suivant*, `record` | → **3** immédiat, `playgate 0` | → **0** immédiat, `erase` |
| **3** arrêté | → **2** **immédiat**, `playgate 1` | rien | → **0** immédiat, `erase` |

Trois choses qui ne se lisent pas dans le patch :

- **`recplay` est quantisé, `stop` et `delete` ne le sont pas.** `pd recplay` ne fait que poser un
  `$0-pending` ; c'est le `bar` qui applique. Un `recplay` sans horloge ne produit donc rien du
  tout — c'est ce qui rend le sous-patch muet quand on le teste sans envoyer de mesures.
- **Sauf depuis l'état 3** : relancer une boucle arrêtée part **tout de suite**, sans attendre la
  mesure. Asymétrie voulue ou non, elle est réelle.
- **L'état 1 est bien « en cours d'enregistrement »**, pas « contient un enregistrement » : le
  `record` part à l'entrée dans l'état, et c'est le `recplay` suivant qui ferme le clip avec
  `stopclip <ticks> <mesures> …`. C'est donc **l'état 1 qui doit faire clignoter la LED rouge, et
  l'état 2 l'allumer en continu** ; 0 et 3 l'éteignent.

**PD a trois états par sirène pour deux LEDs physiques : il y en a un de trop.** À trancher avant
toute logique à modes, parce qu'un mode invisible au pied n'est pas utilisable : le décompte avant
départ quantizé et la confirmation d'effacement ont besoin de ces 8 LEDs de pédales.

Et l'état du clip doit tenir sur la seule LED rouge pour trois états non-vides (enregistre,
arrêté-rempli, joue) — donc du clignotement, à des cadences à choisir.

Autres retours : `led.pedal.selection`, `led.pedal.preselection` (jaune), `initLED` (extinction au
démarrage), `tempo.to.led`.

**À connaître avant de dessiner un écran** : le pédalier signale déjà sous les pieds, par ses LEDs,
quelle sirène est sélectionnée, laquelle joue, laquelle enregistre, et le tempo. L'écran n'est pas
la seule surface de retour.

---

## `led.pedal.board` — numérotation juste, sortie débranchée

Ce sous-patch associe huit fonctions aux CC 18-25, et sa numérotation est bonne — mais **ce sont
les fonctions d'avant le 2026-07-31**. Les noms de retour LED disent encore l'ancienne rangée :
`rec.play`, `tempo` et `reset` restent valables, `clip.play.stop`, `clip.write`, `clear.loops`,
`next` et `stop` nomment des fonctions qui n'existent plus. Les renommer est le préalable à tout
câblage de la nouvelle rangée, sans quoi le retour au pied dira autre chose que la pédale.

Son unique sortie part vers `s midi.pedalier.sirenium-r.old`, **un nom que personne ne reçoit**, et
elle y reste : la rebrancher allumerait les LEDs avec les fonctions d'avant la refonte. C'est
maintenant le **seul** envoi orphelin du fichier — les sept autres qui visaient
`midi.pedalier.sirenium-r` sans `$0` ont été recollés sur le bus vivant le 2026-08-01.

Le retour LED des pédales de commande passe désormais **par les sous-patchs de fonction**, pas par
`led.pedal.board` : `pd scene.play.stop.del` (CC 19) et `pd $0.scene.write.duplicate` (CC 21)
prennent la troisième sortie de `pedal-press-duration` et l'envoient sur le bus.

---

## L'ambitus des sirènes existe en trois copies

Le repli d'un intervalle dans l'ambitus d'une sirène s'appuie sur des valeurs qui vivent à trois
endroits — et **c'est le `.txt` qui fait sonner les notes** :

| Fichier | Rôle |
|---|---|
| `mecaviv/puredata-abstractions/examples/sirenspec.txt` | lu par PD au runtime — **ce qui sonne** |
| `QtFiles/qml/qmlwebsocketserver/sirenSpec.js` | l'affichage QML |
| `QtFiles/qml/qmlwebsocketserver/sirenSpec.json` | mort, mais toujours dans `data.qrc` |

Une correction d'ambitus doit être faite aux trois endroits, sinon l'écran et le son divergent
silencieusement.

État au 2026-07-25, après correction de S4 (`notemin` 30 → 36, S4 tenant moins bien le grave que S3) :

```
S4 36–79   S3 36–77   S1/S2 43–86   S5/S6 48–94   S7 48–94
```

Deux conséquences :

- **Les ambitus se chevauchent énormément** — S1 et S5 ont presque trois octaves en commun. « Replier
  dans l'ambitus » ne désigne donc pas une octave unique : la quinte sur S3 existe à 43, 55 et 67. La
  règle de choix reste à écrire. « Le plus grave possible » donne bien les deux octaves d'écart
  attendues entre S3 et S7, mais colle l'accord en bas en permanence ; « l'octave la plus proche de
  la note courante de la fondamentale, puis repli » laisse l'accord suivre la ligne.
- **L'ordre grave→aigu S3 S4 S1 S2 S5 S6 S7** (voir `SCENES_SPEC`) est cohérent depuis la correction :
  S3 et S4 partent du même `notemin`, et S3 plafonne plus bas (77 contre 79). Avant, S4 descendait à
  30 et l'ordre écrit contredisait les chiffres.

**Question ouverte : `transpo` et `transpose` ne disent pas la même chose.** Le `.txt` porte
`S1 transpo 24 / S3 12 / S5 36`, le `.js` porte `transpose: 0` partout sauf S7 à 12. Soit ce sont
deux notions distinctes (transposition mécanique de la roue vs musicale), soit l'une est périmée.
Comme elle décide de la vitesse réelle du rotor pour une note donnée, elle doit être tranchée avant
d'écrire la règle de repli — et avant de conclure quoi que ce soit sur la hauteur de parking du mute.

---

## Non résolu

- **Plage exacte du gros boîtier** : son commentaire annonce `filters controllers 26 to 42`, ce qui
  est la plage du clavier — copier-coller qui a vieilli. Son `moses 91` indique une plage autour de
  91, mais le nombre de boutons et la correspondance bouton ↔ composition restent à établir.
- ~~**CC 21** : `led.pedal.board` dit *tempo*, la feuille laisse la case vide.~~ Tranché le
  2026-07-25 : le tap tempo est conservé — il est passé en **CC 24** avec la nouvelle rangée.
- ~~**Confirmation du `scene clear`** : on ignore quel geste confirme et ce qui est censé
  l'annoncer.~~ Tranché et câblé le 2026-08-01 : le geste est l'**appui long de 3 s sur CC 19**,
  l'annonce est le clignotement de la LED de la pédale. Le geste reste réversible tant que
  `scene write` (CC 21) n'a pas validé.
- **Les sept envois de la rangée n'ont aucun receive** : `$0.scene.play.stop`, `$0.scene.clear`,
  `$0.scene.next`, `$0.scene.write`, `$0.scene.duplicate`, `$0.scene.new`, `$0.tempo.tap`. Le côté
  pédale est fini et mesuré ; ce qui manque est l'aval, c'est-à-dire les commandes de scène
  elles-mêmes — voir `SCENES_SPEC.md`. Seul `$0.pedal.play.rec` est branché des deux bouts.
- **Cinq pédales n'ont aucun retour LED** : 18, 20, 22, 24, 25 n'ont pas d'appui long, donc pas de
  sortie `attente`. Leur donner un flash bref à l'appui demande de choisir une durée.
- **`led.siren.recording` n'a pas de source.** Son `r led.main.pedals` — sans `$0`, encore un nom
  de l'époque `MidiToSiren.pd` — n'a d'émetteur nulle part. L'état par sirène qu'il lui faut existe
  déjà dans `$0.loopstates` (`pd loop.states`, alimenté par `$0.loader.state`) : voir la table de
  transitions ci-dessous. Le câblage est mécanique, rien ne le bloque plus.
- **`compo.save.json`** ← `$0.compo.save` : conservé, destiné à une pédale libre — CC 23 est la
  seule de la rangée.
- **Les trois états par sirène pour deux LEDs physiques** : `led.siren.playing` fait `+ 17` et
  écrit sur 18-24, la rangée des pédales de commande, qui porte maintenant le retour d'appui long
  de CC 19 et CC 21. Le conflit décrit plus haut n'est plus théorique — il faut trancher lequel des
  deux occupe 18-25.

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
