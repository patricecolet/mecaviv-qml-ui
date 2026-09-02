# Processeur d'effet — conception

Décidé en discussion le **2026-09-01**. Ce document est la conception, pas un compte rendu : ce
qu'il décrit n'est **pas encore patché**. Ce qui est validé est marqué comme tel ; ce qui reste
ouvert est au §13, et rien de ce qui y figure ne doit être construit sans revalider.

Le processeur d'effet est la moitié manquante d'une chaîne déjà à moitié écrite :
`pedals.modulators` → `$0.modulation.pedal` existe, la matrice de modulation est stockée et éditable
depuis le QML, mais **rien ne l'applique** — elle ne voyage que vers l'écran. Concevoir le
processeur, c'est aussi décider ce que devient cette matrice. La réponse est : elle disparaît (§10).

---

## 1. Principe

**Le pied donne l'amplitude, la scène donne le temps.**

Une seule règle pour les trois pédales : la position de la pédale ouvre l'effet, tout ce qui est
rythme ou vitesse est un réglage de scène. Rien à décider au cas par cas, et le geste au pied
signifie la même chose partout.

Corollaire : la refonte **supprime les 8 `pedalId` virtuels**. Les boutons ne multiplexent plus les
pédales physiques, ils portent une fonction propre ; chaque pédale a une affectation fixe. C'est ce
qui rend l'usage « plus précis et plus simple » — au prix de la matrice 448, voir §3 et §10.

---

## 2. Les contrôles

Trois pédales d'expression continues et quatre interrupteurs, sur la **pédale BOSS** (IP .25,
canal 9). Les numéros sont du matériel, ils sont figés : boutons **43-46**, pédales **47-50**
(`PEDALIER_MAPPING.md`). Les interrupteurs ont chacun **leur LED** (43-46 en retour) : leur état est
visible au sol, donc latché — pas de momentané à simuler.

| Pédale | CC | Interrupteurs | Au pied | Dans la scène |
|---|---|---|---|---|
| **A** | 47 | **43 + 44** — choix du motif | amplitude : profondeur du trémolo, ou creusement du volet entre les notes | `tremoloSpeed`, et les 3 séquences |
| **B** | 48 | **45** — portée | `vibratoDepth` | `vibratoSpeed` |
| **C** | 49 | **46** — portée | transposition diatonique dans la gamme | `scaleMode`, `root` |

**Les deux interrupteurs de la pédale A** donnent quatre états stables, tous utiles :

| 43 | 44 | Pédale A agit sur |
|---|---|---|
| 0 | 0 | **trémolo** (modulation continue du volume) |
| 1 | 0 | séquence **1** |
| 0 | 1 | séquence **2** |
| 1 | 1 | séquence **3** |

Il n'y a donc pas d'état « la pédale ne fait rien » : sans séquence, elle fait le trémolo. C'est le
même geste — ouvrir les volets — avec ou sans motif rythmique.

**Les interrupteurs 45 et 46** portent la **portée** de leur pédale : appliquée à la seule sirène
sélectionnée, ou à toutes. La pédale A n'a pas d'interrupteur libre : sa portée vient de la scène
(§3), sans dérogation au pied.

La **quatrième pédale BOSS (CC 50) reste libre**, comme aujourd'hui — `pedals.modulators` ne route
que `47 48 49`.

---

## 3. L'état vit dans la table `voices` de la scène

C'est le point de conception le plus important, et il ne demande aucun format nouveau.

`pd scene.voices.load` remplit `$0.voices`, une ligne par voix, avec les champs :

```
enable   voice   degree   volume   gate   pedal   siren
```

Le champ **`pedal` n'est câblé à rien** — vérifié dans `pedalier.pd` le 2026-09-01 : les seuls
`text get $0.voices` du patch lisent les champs 1 et 6. C'est une case réservée, jamais branchée.
Elle attend exactement ce qu'on construit.

Répartition :

| Champ | Écrit par | Rôle |
|---|---|---|
| `volume` | pédale A | amplitude du trémolo / creusement du volet |
| `gate` | pédale A (séquences) | ouverture-fermeture rythmique |
| `degree` | pédale C | degré de la voix dans la gamme |
| `pedal` | **la scène** | quelles voix suivent les pédales |

Sept lignes, sauvegardées et rechargées avec la scène par une machinerie qui existe déjà, **au lieu
de 448 valeurs** dans un fichier de préréglage séparé. Une profondeur par sirène et par pédale reste
possible si le besoin apparaît, mais elle n'est pas dans cette conception : commencer par la table.

Le champ `pedal` et les interrupteurs 45/46 ne se contredisent pas : la scène dit qui suit la
pédale, l'interrupteur **force toutes les voix** tant qu'il est enclenché, sa LED le dit.

---

## 4. Les trois séquences

Une séquence n'est **pas une suite de hauteurs** : c'est un **motif rythmique de réattaques**. La
hauteur reste celle tenue au sirenium ; rejouer la note referme puis rouvre le volet. Un trémolo
programmable, en somme — ce qui explique que l'état sans séquence soit le trémolo continu.

**Trois séquences par sirène** (Patrice, 2026-09-02), soit 21 en tout — pas trois communes à la
scène comme une version antérieure de ce paragraphe l'affirmait. Les deux interrupteurs de la
pédale A choisissent l'**indice** 1, 2 ou 3 ; chaque sirène visée joue alors *sa* séquence de cet
indice.

### Une bibliothèque de fichiers, pas un bloc dans la scène (2026-09-02)

**Décision de Patrice, qui remplace tout ce qui précédait sur le format.** Les séquences ne sont plus
stockées dans la scène : elles vivent dans une **bibliothèque de fichiers `.txt`**, gérés par
`text define` et ses messages `read` / `write`. La scène ne garde qu'une **référence** — l'index de
la séquence.

Ce que ça supprime, et c'est l'essentiel : plus de tableau imbriqué à faire traverser le dump de
scène, plus d'index de tableau à reconstruire, plus de `sceneSet` par champ. Les deux anomalies qui
bloquaient la sauvegarde (voir plus bas) **n'ont plus d'objet** — le code fautif disparaît au lieu
d'être réparé. Et une séquence devient réutilisable d'une scène à l'autre, ce que le bloc embarqué
ne permettait pas.

Un fichier de bibliothèque, format proposé :

```
1920;        <- ligne 0 : la longueur en ticks
0 127;       <- puis un evenement par ligne : <tick> <velocite>
480 60;
960 100;
```

**Mesuré le 2026-09-02 : `text read` résout un chemin relatif depuis le dossier du PATCH**, pas
depuis le répertoire de travail — vérifié en lançant Pd depuis `/tmp` sur un patch situé ailleurs.
C'est l'inverse de `[file]` (qui résout depuis le cwd, piège du 2026-07-31). Conséquence : dans une
**abstraction**, le relatif viserait `application.layer/`, donc la bibliothèque doit être atteinte
par un **chemin absolu** construit depuis la racine des compositions, comme le fait déjà
`composition-io`.

### La racine se distribue depuis une seule source — elle existe déjà

**Contrainte posée par Patrice le 2026-09-02** : le chemin absolu doit venir d'une source unique pour
toutes les parties de `pedalier.pd`. Cette source existe : **`$0.racine`**.

`pd racine` (dans `looper`) lit `config.json`, vérifie par `file stat` que le chemin est accessible
en écriture, retombe sur `~/Documents/pedalier.compositions` sinon, crée le dossier au besoin, et
diffuse. `composition-io` renormalise et rediffuse sur le même canal — c'est donc sa valeur qui fait
foi en dernier. Aujourd'hui le canal n'a **qu'un seul lecteur**, `pd sortie.memo` : il est bon, mais
sous-utilisé.

Les résolutions concurrentes, toutes relatives au dossier du patch :

| Où | Comment | Sort |
|---|---|---|
| `pedals.get.preset.list`, `pedals.preset.load`, `pedals.preset.name.init` | `dir` → `pdcontrol` | **supprimées par le §10** — ce sont les préréglages de pédales |
| `clic.config`, `clic.save` | `file patchpath` | subsistent ; à rebrancher sur `$0.racine` si on veut la source unique partout |

Autrement dit, **le nettoyage déjà prévu satisfait la contrainte presque entièrement** : il ne
restera que le clic. La bibliothèque de séquences, elle, se branche sur `r $1.racine` et compose son
chemin par un message-box à substitution (`$1/sequences/$2.txt`), sans `pdcontrol` ni
`file patchpath` local.

**Tranché le 2026-09-02** : la bibliothèque vit dans **`<racine>/sequences/`**, à côté des dossiers
de composition — partagée, donc. La scène range ses références dans **trois champs de plus de la
table `voices`** (`seq1`, `seq2`, `seq3`, champs 9 à 11). Et les séquences sont **chargées à la
volée** : sept tables actives, une par sirène, rechargées quand les boutons changent d'indice —
pas les 21 en mémoire.

### Fait le 2026-09-02 — les références dans `voices`, et un sous-patch qui documente la table

`seq1 seq2 seq3` sont les champs 9, 10, 11. Mêmes quatre points à toucher que pour les vitesses :
init dans `siren.reset` (douze atomes), complétion dans `updateVoice` (`list append 0 0 0 0 0` puis
`list split 12`), préservation dans `voice.select.root` (`text get $1.voices 4 8`), sauvegarde et
chargement de scène.

Mesuré : `seq1` mis à 5, sauvegardé, **effacé en mémoire**, scène rechargée, ligne relue
`0 0 0 127 0 0 3 0 0 5 0 0` — douze champs, la référence revenue du fichier.

**Un sous-patch `pd champs` est posé à côté de la définition de la table** (demande de Patrice) : il
énumère les douze champs et rappelle les quatre points à toucher pour en ajouter un. C'est
l'application directe de « le diagramme est le programme » — la disposition d'une donnée décrite à un
seul endroit, en clair, et qui se lit en ouvrant l'objet plutôt qu'en relisant ce document.

---

## Ce qui suit décrit le format abandonné, gardé pour la trace

**Format mesuré le 2026-09-02**, en écrivant un bloc d'essai dans une scène et en sondant le dump.
Deux clés, toutes deux des tableaux d'objets comme `voices` — donc la même machinerie de chargement :

```json
"sequences": [
  { "siren": 1, "seq": 1, "tick": 0,   "velocite": 127 },
  { "siren": 1, "seq": 1, "tick": 480, "velocite": 60 },
  { "siren": 3, "seq": 2, "tick": 960, "velocite": 100 }
],
"sequenceLengths": [
  { "siren": 1, "seq": 1, "ticks": 1920 }
]
```

Ce que le broadcast en émet, vérifié :

```
list sequences 0 tick 0          list sequenceLengths 0 1920
list sequences 0 seq 1           list sequenceLengths 1 960
list sequences 0 velocite 127    list sequenceLengths 2 3840
```

Un tableau d'objets donne `<clé> <index> <champ> <valeur>`, un tableau de nombres
`<clé> <index> <valeur>`. **L'ordre est celui du hachage Lua** — dans la mesure, `sequenceLengths`
sortait avant `tempo` et `tick` avant `seq` : la règle du latch jusqu'à `end` n'est pas théorique.

**La longueur par défaut est d'une mesure** (1920 ticks) et **s'allonge à l'édition** — décidé le
2026-09-02. Une séquence plus longue que la mesure est donc prévue dès le départ, ce qui rejoint les
polyrythmes déjà assumés pour le looper (`project_looper_polyrythme_assume`).

### Construit le 2026-09-02 — `sequences-io.pd`

Le bloc `sequences` de la scène est rangé dans `$1.sequences`, **une ligne `<sirene> <seq> <tick>
<velocite>`**. La sirène est un champ, pas un niveau de tableau imbriqué : la forme plate est celle
que le dump sait rendre, et elle réutilise la machinerie de `voices`.

Le piège n'était pas le format mais **la longueur variable de la table**. `text set` refuse d'écrire
un champ sur une ligne qui n'existe pas, et le nombre d'événements n'est pas connu d'avance :
`pd garantir` comble donc jusqu'à l'index demandé avec des lignes neutres, avant chaque écriture de
champ. Mesuré : trois événements relus tels quels, et **deux chargements de suite laissent trois
lignes, pas six** — le vidage sur `begin` fait son travail.

Reste à écrire : la sauvegarde, les longueurs (`sequenceLengths`), et le séquenceur lui-même.

**Un piège mesuré en tentant la sauvegarde, à ne pas réessayer tel quel.** Le motif « `until` +
compteur + `text sequence` » ne s'entrelace pas comme on l'attend : avec un `[t b b]` qui bange le
compteur d'un côté et `text sequence` de l'autre, l'ordre réellement observé est

```
CPT 0 · LIGNE · LIGNE · LIGNE · CPT 1 · CPT 2
```

— les lignes sortent groupées, et l'index reste bloqué à sa première valeur. Conséquence dans la
sauvegarde : les 21 `sceneSet` partaient tous avec l'index 0 et s'écrasaient les uns les autres, ne
laissant qu'une entrée dans le JSON. Le compteur seul, hors de ce contexte, compte pourtant
correctement (0 1 2 3), y compris derrière un trigger.

**Le remède est de parcourir par index** : `until` → compteur → `text get <ligne>`, exactement le
motif de `sirenes-visees/emission`, qui est mesuré et fonctionne. Ne pas utiliser `text sequence`
quand l'index de la ligne est nécessaire en même temps que son contenu.

**Ce remède corrige la moitié du problème, et une seconde anomalie reste ouverte.** Avec le parcours
par index, les 21 longueurs partent bien avec 21 index distincts (au lieu d'une seule entrée). Mais
sur une table de **deux** lignes, la boucle produit **cinq itérations ou plus**, en relisant
alternativement la ligne 1 puis la ligne 0, pendant que l'index avance normalement 0, 1, 2, 3, 4.
Autrement dit les deux sorties d'un même `[t f f]` paraissent ne pas porter la même valeur — ce qui
ne devrait pas être possible, donc le modèle du montage est faux quelque part et la cause n'est pas
identifiée.

La sauvegarde a été **retirée** plutôt que laissée en place : elle écrivait des entrées mélangées
dans les scènes. `sequences-io` est revenu à son état du commit `8b95c98` (chargement seul, testé).
À reprendre en regardant le montage dans l'éditeur graphique, où le flux se lit d'un coup d'œil.

### D'où vient la hauteur

**Le séquenceur ne porte aucune hauteur.** Les notes de la séquence sont *pitchées* par ce qui passe :
la note du **clip en aval**, ou celle du **sirenium en amont**. C'est la réponse à la question posée
le 2026-09-02 — il ne s'agit ni d'un CC de volume, ni d'un générateur de notes autonome, mais d'une
réattaque de la note courante.

Conséquence pour la construction : le séquenceur doit suivre **la dernière note de chaque sirène**,
donc tenir sept états, alimentés en observant le flux. C'est ce qui le distingue des trois pédales,
qui sont sans mémoire.

Une ligne par événement :

```
<position en ticks>  <vélocité>
```

- **Position en ticks**, pas en millisecondes : la séquence est calée sur l'horloge comme tout le
  reste, et c'est ce qui permet de l'enregistrer telle quelle (§7). Référence : 1920 ticks par
  mesure, comme les clips (`length_ticks` de `clip_*.json`).
- **La vélocité combine la source et la pédale A** (Patrice, 2026-09-02) — la source étant le
  sirenium ou le clip. Formule retenue, à confirmer :

  ```
  velocite = source * (1 - a + a * seq/127)      avec a = pedale A / 127
  ```

  Au repos (`a = 0`) la vélocité **est** celle de la source : le motif est là mais inaudible, le jeu
  reste normal. À fond (`a = 1`) le motif s'applique pleinement et referme le volet là où il met 0.
  Ce n'est donc **pas** un produit sec `source × pedale`, qui rendrait l'instrument muet pédale
  relâchée. Même logique que le trémolo, et la nuance de la source reste audible à travers le motif
  au lieu d'être écrasée.
- La **vitesse est dans la séquence**, jamais au pied — §1.
- **Retrig sur note on** (Patrice, 2026-09-02) : la séquence redémarre à chaque attaque de la
  source. Sa phase est donc relative au geste, **pas à la mesure** — un compteur de ticks remis à
  zéro sur la note on, sans ancre absolue ni resynchronisation, contrairement au curseur du looper
  qui doit se caler sur `mainloop-startbar`.

  Deux points à trancher : ce qui arrive **au bout de la longueur** (le motif boucle tant que la
  note est tenue, ou joue une fois comme un ornement d'attaque), et ce qui **compte comme note on** —
  une **ghost note** (vélocité 1, moteur muet) ne devrait pas relancer le motif, sinon le
  rebouclage d'un clip le recalerait en silence.

**La table `voices` était déjà dans le format** — je l'avais cru absente en lisant une scène de
démonstration jamais réécrite, dans `examples/pedalier.compositions/`, qui n'est même pas la racine
utilisée. **La vraie racine est `~/Documents/pedalier.compositions/`.** `pd scene.voices.save` écrit
les champs des sept voix, `pd scene.voices.load` les relit, et le champ `pedal` en fait partie
depuis le début. Seules les séquences restent à ajouter au format.

### Étendu le 2026-09-02 — les deux vitesses, par sirène

`vibratoSpeed` et `tremoloSpeed` sont les **champs 7 et 8** de `$0.voices`, ajoutés **à la fin** :
aucun indice existant ne bouge, donc `text get … 6` (la sirène) et `text search … 1` (la voix)
restent valides chez tous leurs lecteurs.

Quatre points à toucher, trouvés en suivant les écritures plutôt qu'en lisant la disposition :

| Où | Quoi |
|---|---|
| `voice.select.root` | préservait trois champs (`text get $1.voices 4 3`), en préserve cinq — sinon il réécrivait une ligne de sept atomes et **effaçait les deux nouveaux à chaque sélection de voix** |
| `siren.reset` | **l'init du tampon** : son message `0 $1 0 127 0 0 $2` créait les sept lignes à sept atomes ; il en énonce neuf |
| `updateVoice` | complète toute ligne reçue à neuf champs (`list append 0 0` puis `list split 9`) |
| `scene.voices.save` | deux `sceneSet` de plus |
| `scene.voices.load` | deux clés de plus dans son `select` |

Les lignes de voix naissent dans `pd siren.reset`, sur `siren.reset all`, avec l'appariement
voix→sirène `0 3, 1 4, 2 1, 3 2, 4 5, 5 6, 6 7` — l'ordre par hauteur (`reference_siren_pitch_order`).
La complétion dans `updateVoice` reste en plus : c'est le point où **convergent toutes les écritures
de ligne**, donc la garantie de longueur y est mieux placée que répétée chez chaque émetteur.
Mesuré : 42 posé en `vibratoSpeed`, `siren.reset all`, la ligne revient à `0 0 0 127 0 0 3 0 0`.

**`text set` refuse d'écrire au-delà de la fin d'une ligne** (`field number past end of line`, mesuré) :
c'est pourquoi la complétion dans `updateVoice` est nécessaire, et pas seulement propre. Elle est
idempotente et vaut quel que soit l'émetteur, donc elle migre les lignes existantes sans rien casser.

Cycle vérifié bout en bout sur le vrai patch : 42 écrit en mémoire, sauvegardé, **effacé en mémoire**
(relu 0), scène rechargée, **relu 42 depuis le fichier**.

Deux pièges du format, à connaître avant d'y ajouter quoi que ce soit — ils viennent du commentaire
de `composition-io v4` : le dump d'une scène sort **en ordre de hachage Lua**, et **les clés nulles
sont omises entièrement**. Un récepteur doit donc latcher entre `begin` et `end`, jamais agir ligne
à ligne, et toute clé ajoutée doit avoir une valeur par défaut posée avant le dump — sinon elle
garde silencieusement celle de la scène précédente.

**Ce piège est observé, pas théorique** : au test, charger une scène antérieure au 2026-09-02 (donc
sans bloc `voices`) laisse les vitesses de la scène précédente en place. Ça se résout en sauvant la
scène une fois. **Aucune remise à zéro n'a été ajoutée**, et c'est délibéré : elle effacerait du même
coup l'appariement voix→sirène des scènes anciennes, ce qui serait pire que l'héritage.

### Construit le 2026-09-02 — `voices-vitesses.pd`

À chaque scène chargée (`$1.scene.loaded`), la table est parcourue et les deux vitesses partent vers
les sirènes : **CC 9** pour le vibrato, **CC 15** pour le trémolo — les fréquences de la table
composeSiren. Il réutilise `vers-ctl`. Sans lui, les deux champs restaient inertes : stockés, relus,
et personne pour les jouer.

Mesuré : 14 CC par chargement, dans l'ordre des voix (3 4 1 2 5 6 7), et après sauvegarde la
sirène 3 reçoit `ctl 50 15 3` et `ctl 30 9 3`.

### Un vestige laissé en place — `voices.siren.preselection`

Dans `harmoniseur.pd`, ce sous-patch **reçoit** les lignes de voix depuis `updateVoice`, mais les
cherche dans une table globale `voices` (sans `$1`) qui n'existe pas, et écrit sur `sirenVoice` et
`siren.voices.update`, deux canaux globaux sans destinataire. Son entrée `$1.siren.preselection` n'a
elle-même aucun émetteur. Il fait la **présélection de sirène**, la fonction que la refonte du
2026-07-31 a déplacée sur le clavier.

Lui ajouter les `$1` serait le pire des gestes : ça le rebrancherait sur la vraie table pour exécuter
un design abandonné. Il faut le **supprimer** — mais depuis l'éditeur graphique, où Pd renumérote
lui-même. Trois tentatives de suppression scriptée ont échoué ici (indice mal calculé, puis deux fois
une mauvaise attribution des connexions par profondeur, la seconde ayant touché d'autres
sous-patchs) ; le fichier a été restauré à chaque fois. **Ne pas réessayer par script.**

---

## 5. Pédale C — transposition diatonique

La pédale C transpose **chaque sirène dans la gamme sélectionnée** : toutes montent du même nombre
de degrés, l'harmonie garde sa forme. Ce n'est pas un changement d'accord — poser l'accord est un
autre chantier, et il vient après le mode polyphonie (§11).

La machinerie existe déjà dans `harmoniseur.pd` : `$1.scaleBuffer` tient la gamme,
`text search $1.scaleBuffer <= 0` donne la position d'une note dedans, `text size` donne son
étendue. Transposer de N degrés est une addition sur cette position plus un repli d'octave.

Deux conséquences :

- **La course de la pédale s'adapte à la gamme.** Le nombre de crans est `text size $1.scaleBuffer`,
  pas une constante — une dizaine de valeurs en pratique. Rien à reconfigurer en changeant de mode.
- **Il faut une hystérésis, et ce n'est pas un détail.** Une pédale d'expression tremble ; sur une
  valeur quantifiée à dix crans, elle ferait clignoter l'harmonie à chaque frontière. Marge de
  recouvrement à la montée et à la descente, sinon l'effet est inutilisable au pied.

### Construit le 2026-09-02 — `pedale-degre.pd`

Le CC 49 devient un décalage de degrés ; le CC 46 dit s'il vaut pour toutes les sirènes ou pour la
seule sélectionnée (traduite depuis `$0.loop.voice.select` par la table `voices`). L'objet émet une
paire `<sirene> <decalage>` par sirène, à chaque changement de position, de portée ou de sélection.

Trois valeurs sont posées et se changent en une constante — **elles sont mon choix, pas le tien** :

| Réglage | Valeur | Effet |
|---|---|---|
| Course | `pos × (taille+1) / 128` | 0 au repos, **une octave pleine à fond**, quel que soit le nombre de degrés du mode |
| Hystérésis | +1,2 / −0,2 cran | il faut dépasser franchement la frontière pour monter, et redescendre nettement pour revenir |
| Sens | vers le haut seulement | la pédale part de sa butée basse, qui est le neutre |

Mesuré : CC 64 met les sept sirènes à 4, l'interrupteur relâché ne laisse que la sélectionnée,
CC 70 ne bouge rien (hystérésis) et CC 90 passe à 5. Bout en bout sur le vrai patch, une note 59
ressort 65 — six demi-tons, ce qui est juste sur la chromatique chargée par défaut.

**Il lit `$0.midi.pedalier.sirenium` en parallèle de la chaîne de rejet**, sans toucher à
`pedals.modulators` : celui-ci continue d'alimenter la matrice 448 pour rien, ce qui est inoffensif.
La suppression du §10 attendra un essai au pied — casser l'étage existant pendant que le Raspberry
est inaccessible n'aurait aucun intérêt.

### Construit le 2026-09-02 — `pedale-vibrato.pd` et `sirenes-visees.pd`

La pédale B lit le CC 48 et émet **`ctl <valeur> 1 <sirene>`** : le CC 1 des sirènes est
*Vibrato Amount*, et ce format est celui que `pd sendNote` utilise déjà (`$1 72 3`, CC 72 =
Release). L'interrupteur 45 choisit la portée.

**`sirenes-visees.pd` est sorti de `pedale-degre`** avant d'être recopié pour la pédale B : portée,
sélection et boucle sur les sept sirènes étaient identiques. Ce que l'extraction supprime est réel —
l'ordre des lectures avant la boucle est subtil, et il n'a plus à être juste qu'à un seul endroit.
Chaque instance a son `$0`, donc les deux pédales ne se télescopent pas.

**Elle n'émet que ce qui change**, et ce n'est pas une optimisation gratuite : sans ça, chaque
mouvement de la sélection renvoyait sept valeurs identiques aux sirènes. Mesuré sur le vrai patch,
**35 messages pour un seul mouvement utile, ramenés à 14**. La table des dernières valeurs part à
`-1` pour que la première passe toujours. À rapprocher de `project_pedalier_flux_degrade` : ce
chemin-là, au moins, ne contribuera pas au bruit.

### Construit le 2026-09-02 — `pedale-tremolo.pd`, moitié trémolo de la pédale A

CC 47 vers le **CC 92** des sirènes (*Tremolo Depth*). Les interrupteurs 43 et 44 composent le
motif : 0 = trémolo, 1 à 3 = les séquences, qui restent à construire.

**Le point qui compte est l'état, pas le mapping.** Dès qu'un interrupteur est enclenché, la
profondeur retombe à **zéro** — sans ça le trémolo resterait figé à sa dernière valeur pendant
qu'une séquence joue, et rien dans l'interface ne le dirait. La position reste mémorisée, donc
revenir au trémolo la réapplique sans avoir à rebouger le pied. Mesuré : 80 sur les sept, 0 dès
l'enclenchement, pédale ignorée pendant ce temps, 60 réappliqué au retour.

`vers-ctl.pd` est sorti de `pedale-vibrato` au passage : le même montage `<sirene> <valeur>` →
`ctl <valeur> <cc> <sirene>` servait déjà deux fois et servira aux séquences. Le numéro de CC est
son argument de création.

**Sa portée vient du champ `pedal` de la scène** (depuis le 2026-09-02). `sirenes-visees` prend
désormais un **mode** et non plus un booléen :

| Mode | Sirènes visées | Qui l'utilise |
|---|---|---|
| 0 | la seule sélectionnée | pédales B et C, interrupteur relâché |
| 1 | toutes | pédales B et C, interrupteur enclenché |
| 2 | celles dont `pedal` vaut 1 dans la table `voices` | **pédale A**, qui n'a pas d'interrupteur libre |

Mesuré : sur une table où seules les voix 0 et 2 portent `pedal = 1` (sirènes 3 et 1), une valeur de
90 en mode 2 ne part que vers ces deux-là.

Ce qui manque encore à la pédale A : `tremoloSpeed` (CC 15) est censé venir de la scène, qui ne
sait pas non plus le stocker. Aujourd'hui la vitesse du trémolo reste celle réglée sur la sirène.

---

## 6. Placement dans la chaîne

`SCENES_SPEC.md` §9 (décidé le 2026-07-31) pose **deux harmoniseurs, le point de captation entre les
deux** ; l'harmoniseur aval était **reporté, pas abandonné**. Le processeur d'effet le rend
nécessaire : c'est lui qui reçoit les notes engendrées.

Et il fixe le placement du processeur. §9 dit que ce qui entre dans le clip est *déjà* harmonisé et
réparti ; un processeur branché entre les deux harmoniseurs enverrait donc ses notes sur
`$0.to.sirens` sans harmonie ni répartition. Il est **en amont de l'harmoniseur 1**, avec le
sirenium :

```
sirenium ─┬────────────────────→ harmoniseur 1 ──→ [rec couche 1]   (gate ici)
          └→ processeur ────────↗                  [rec couche 2] ──→ harmoniseur 2 → sirènes
                  ↑
      pédales A/B/C → table voices de la scène (volume / gate / degree)
```

### Construit le 2026-09-01 — `harmoniseur-aval.pd`

§9 annonçait un recâblage : « la relecture doit entrer **dans** l'harmoniseur aval au lieu d'arriver
à côté ». **Il n'y en a pas eu besoin**, et c'est la bonne surprise de ce chantier. Le bus
`$0.to.sirens` a trois producteurs (l'harmoniseur amont via `pd filter`, et les deux `s $3.to.sirens`
de `siren-clip-loader` — relecture et ghost note) mais **un seul lecteur qui va au son** :
`r $0.to.sirens` → `pd route.device`. L'objet s'insère donc sur le **lecteur**, en un seul câble
coupé, et les clips le traversent d'eux-mêmes.

Mieux : `pd captation` lit ce même bus, donc **en amont** de l'aval. Ce qui part dans le clip n'est
pas transposé — exactement le partage que §9 demande, obtenu sans déplacer le point de captation.

L'abstraction décale chaque `note` de N degrés dans `$1.scaleBuffer` ; `bend` et tout message
inconnu passent intacts. Deux points à connaître :

- **La convention du quart de ton est prise en compte** : la note du bus est un demi-ton sous la
  hauteur réelle, d'où un `+ 1` avant la recherche du degré et un `- 1` après. Exact tant que le
  bend est neutre ; sous bend réel la note dérive d'au plus un demi-ton, comme partout ailleurs sur
  ce bus (`reference_to_sirens_note_decalee`).
- **Neutre au repos, et neutre au démarrage.** Décalage 0 → la note ressort identique. Gamme pas
  encore chargée → `text search` rend `-1`, une garde fait passer la note telle quelle : l'objet ne
  peut pas rendre le patch muet au boot.

Mesuré en headless (Ionian : +1 do→ré, +2 do→mi, +7 une octave, −1 le si dessous ; Diminished à
4 degrés : le repli d'octave tient ; gamme vide : note intacte), puis bout-en-bout sur le vrai
patch. **La gamme chargée au démarrage est `Chromatic`** (12 degrés, `pd defaultScale` de
`scaleManager`) — un décalage y vaut donc un demi-ton tant qu'aucune gamme n'est choisie.

**Le décalage est par sirène, pas global.** L'entrée droite prend `<sirene> <decalage>` et l'objet
tient sept lignes remises à zéro au chargement. C'est ce qu'exige l'interrupteur 46 : sans décalage
par sirène, « toutes les sirènes ou la seule sélectionnée » n'a nulle part où agir.

---

## 7. Enregistrement — deux couches

Le rec libre **n'écrit pas dans le clip** : il insère ses événements dans un **second midifile qui
tourne en parallèle**, pour que la seconde couche soit supprimable d'un geste sans toucher à la
première. Conséquence heureuse : ce qui est gravé par le processeur est figé, mais jetable — ce qui
lève l'objection habituelle contre l'enregistrement d'un résultat plutôt que d'un geste.

**Quand une boucle existe déjà, le rec/play ne dépend plus du début de la mesure.** Le risque n'est
pas le déclenchement, c'est **l'origine des ticks** : libéré de la mesure, il faut écrire à la phase
courante

```
(mesure − mainloop-startbar) mod longueur
```

et non à 0. C'est exactement le défaut qui a produit le bug de grille du 2026-08-22
(`pd phase` côté PD, `_loopPhase` côté QML). La couche 2 **garde la longueur de la boucle
existante** : elle ne devient jamais boucle de référence, `mainloopCommit` ne la voit pas.

---

## 8. Le gate sirenium

Le message `SIRENIUM` porte `note` et `velocity`. `note 0` = plus rien sous les doigts ;
`note > 47` = dans l'ambitus (il commence à 48, `ambitusLow` dans `SireniumMonitor2D.qml`). Le vrai
signal est donc : **le sirenium joue, ou ne joue pas**.

À la fermeture du gate :

- **seules les notes et le bend du sirenium** cessent d'être captées. Les CC continuent d'être
  écrits, et la couche 2 n'est pas touchée ;
- **le temps continue d'avancer** — sinon désynchronisation immédiate ;
- **la note en cours reçoit son note off**, sinon sirène bloquée volet ouvert.

Il faut une **hystérésis** : un seul `note 0` entre deux notes hacherait l'enregistrement. Soit une
temporisation, soit attendre la fin de la note en cours. La forme exacte est au §13.

---

## 9. Découpage dans `pedalier.pd`

Convention du patch : un sous-patch porte le **nom de la sortie dont il pend**, avec un préfixe de
famille quand le mot est courant — la forêt de fenêtres Pd doit rester lisible.

| Sous-patch | Rôle |
|---|---|
| `pd pedals.modulators` | **réécrit** : plus de `pedalId` virtuel ; route `47 48 49` vers trois sorties nommées, `43 44 45 46` vers les états d'interrupteur |
| `pd effect.tremolo` | pédale A, état `00` : amplitude → `volume` des voix concernées |
| `pd effect.sequence` | pédale A, états `01/10/11` : lit la séquence de la scène, engendre les réattaques, amplitude → vélocité |
| `pd effect.vibrato` | pédale B → `vibratoDepth` |
| `pd effect.degree` | pédale C : quantification sur `text size $1.scaleBuffer`, hystérésis, transposition diatonique |
| `pd effect.scope` | interrupteurs 45/46 : sélection courante ou toutes, en surcharge du champ `pedal` |
| `pd led.effect.state` | LEDs 43-46, valeur 127 comme le reste du patch |
| `pd sirenium.gate` | §8 : ferme la captation notes+bend, hystérésis, note off |
| `pd rec.couche2` | §7 : midifile parallèle, origine des ticks à la phase courante |

Les paramètres passent par des **buffers `text`**, pas par des inlets froids, et l'état par instance
par `value $0-nom` — jamais un `value` en nom nu, qui serait global.

---

## 10. Ce qui disparaît

La refonte rend caduc tout l'étage `pedalId` :

| Élément | Où | Sort |
|---|---|---|
| Matrice 8 × 7 × 8 = 448 | `$0.modulation.pedal.config` | supprimée, remplacée par la table `voices` (§3) |
| `pedalId` virtuels 1-8 | `pedals.modulators` (décalages 0/4/6) | supprimés |
| Préréglages de pédales | `pedal.presets/`, `pd pedals.preset.load`, `pd pedals.get.preset.list`, `pd pedals.default.preset` | supprimés |
| `SIREN_PEDALS.pedalConfigChange` | `WebSocketController.qml` | supprimé |
| Page CFG | `ConfigView2D.qml`, `ModulationMatrix2D.qml`, `PedalboardPortrait2D.qml` | à réexaminer : la matrice n'a plus d'objet, le reste peut survivre |
| Liste des 8 contrôleurs | `config.js` | réduite à ce que les pédales touchent réellement |

À vérifier avant de supprimer quoi que ce soit côté QML : `data.qrc` est manuel, et `ConfigView2D`
est la seule cible du bouton `CFG`. Retirer la matrice sans lui donner un successeur laisse un
bouton qui ouvre une page vide.

Divergence relevée au passage, à trancher en même temps : PD liste neuf contrôleurs
(`vibratoSpeed vibratoDepth vibratoProgression tremoloSpeed tremoloDepth attack release tune voice`)
et `config.js` en liste huit, avec `volume` en plus et sans `vibratoProgression` ni `tune`. Les deux
listes ne se correspondent pas ; la refonte est l'occasion de n'en garder qu'une.

---

## 11. Ordre des chantiers

Ordre validé par Patrice :

1. ~~**L'harmoniseur aval**~~ — **fait le 2026-09-01** (§6). Le socle est posé et neutre ; ce qui
   reste de `SCENES_SPEC.md` §9, c'est rejouer un clip dans une **autre** gamme que celle où il a
   été joué, et ça demande d'écrire la gamme d'origine dans le `.json` du clip (§13).
2. **Le processeur d'effet** — ce document.
3. **Le mode polyphonie** — nécessaire pour la suite, et jamais tranché
   (`PEDALIER_MAPPING.md` : piste en réflexion depuis le 2026-07-25).
4. **Poser l'accord** — en dernier, une fois la polyphonie décidée.

Le nettoyage du §10 n'est pas un chantier séparé : il se fait avec le 2.

---

## 12. Banc de test sans matériel

`harmoniseur.pd` embarque un **sirenium virtuel** : `pd sirenium` → `pd virtualSirenium`, armé par
le toggle **`$1.sirenium.auto`**. Le toggle porte un nom de receive, donc il s'arme par `send` —
sans souris, sans GUI, en headless.

Ce qu'il produit : un `metro` (2000 ms, commutable à 1000) tire une valeur au hasard, la ramène
**dans la gamme courante** par `text search $1.scaleBuffer <= 0` puis `text get $1.scaleBuffer`
(un `route -1` écarte ce qui n'y est pas), transpose autour de 60 et sort la paire note/bend au
quart de ton par `+ 0.5` / `* 8192` / `mod 8192`, dans un `makenote`.

Deux conséquences pour ce chantier :

- **C'est le banc de test de la pédale C.** Le sirenium virtuel puise dans le **même**
  `$1.scaleBuffer` que la transposition diatonique du §5 : la gamme, la quantification et
  l'hystérésis se vérifient sans toucher au matériel.
- **Il respecte la convention du quart de ton** (`reference_to_sirens_note_decalee`) : ce qui en sort
  a la même forme que le vrai sirenium, bend compris. Un test qui passe ici n'aura pas de surprise de
  format au branchement.

Restent à leurrer, eux : les CC des pédales (par la sonde FUDI, ou un port MIDI virtuel avec
`amidi`) et les LEDs, qui ne se vérifient qu'au sol.

---

## 13. Non tranché

- **Amplitude au pied pour la pédale A** : déduit de la règle du §1, jamais confirmé explicitement.
  L'autre lecture serait la vitesse au pied et l'amplitude dans la séquence.
- **Longueur des séquences** : posée à 1920 ticks par défaut, propre à chaque séquence — c'est mon
  choix, pas une décision de Patrice, qui n'a pas tranché entre ça et « boucler sur la mesure ».
- **Une scène chargée se demande par un numéro nu** sur `$0.scene.select`, pas par `scene <n>` :
  ce dernier ne charge rien et fait rediffuser la scène courante. Mesuré le 2026-09-02, après s'y
  être laissé prendre.
- **Portée de la pédale A** : elle suit le champ `pedal` de la scène faute d'interrupteur libre.
  À confirmer que c'est acceptable en jeu.
- **Par quel geste on supprime la couche 2**, et par quel geste on la crée. Rien n'a été dit ; c'est
  pourtant tout l'intérêt de la séparer.
- **Forme de l'hystérésis du gate sirenium** (§8) : temporisation, ou attente de fin de note.
- **`gate`, `pedal` et `siren`** dans la table `voices` : personne ne les **lit**, mais ils sont déjà
  **préservés** — `pd voice.select.root` (`harmoniseur.pd`) fait `text get $1.voices 4 3` et remet
  ces trois champs en place quand il réécrit une ligne de voix. Le transport existe donc ; c'est leur
  sémantique qui est vide, et c'est une chance : on peut la définir sans rien casser. Reste à mesurer
  ce que `enable` déclenche réellement avant d'y toucher.
- **La quatrième pédale BOSS (CC 50)** reste libre.
- **Rejouer un clip dans une autre gamme** — le vrai objectif de `SCENES_SPEC.md` §9, et la seule
  part non livrée. Elle demande la gamme d'origine dans le `.json` du clip (qui ne porte aujourd'hui
  que `siren`, `is_reference`, `length_bars`, `length_ticks`, `id`, `offset_ticks`) et une
  conversion position→position. `harmoniseur-aval` est l'endroit où ça viendra se greffer.

### Un canal mort trouvé en chemin : `$1.tune`

Dans `harmoniseur.pd`, **quatre `r $1.tune` et pas un seul émetteur**. La tonique circule en réalité
sur le canal **global `tune`** (le `nbx` de `pd tune`, `send tune` / `receive tune-s`, sans `$0` ni
`$1`) — même famille de vestige que les huit `send midi.pedalier.sirenium-r` corrigés le
2026-08-01. Conséquence : dans tout calcul de degré, **la tonique vaut toujours 0**, quelle que
soit la valeur affichée.

Ça se répare en une boîte (`s $1.tune` à côté du `r tune`), mais **ce n'est pas anodin** : les
degrés bougeront dès que la tonique ne sera pas do, donc le son change. `harmoniseur-aval` lit
`$1.tune` — le nom juste, pas le vestige — et se comportera donc correctement le jour où le canal
sera raccordé. Décision à prendre par Patrice, hors de ce chantier.
