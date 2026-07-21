# Reconstruction du patch — briques disponibles et architecture cible

Doc de travail pour refaire le patch pédalier (successeur de `MidiToSiren.pd`) avec le périmètre
resserré défini dans [`SCENES_SPEC.md` §13](SCENES_SPEC.md) : le moteur temps réel de l'instrument
live, plus rien d'autre. Voir aussi `SCENES_SPEC.md §9-12` pour le modèle recorder/harmoniseur/clip
que ce patch doit implémenter.

**Sources vérifiées** (lues directement, pas supposées) : `~/repo/pd-externals/critapec/pdjson/`,
`~/repo/pd-externals/critapec/midifile/`. Si ces externals évoluent, ce document doit être mis à
jour en conséquence — il documente leur état au 2026-07-17.

---

## 1. Remplacer PuRestJson par pdjson

`MidiToSiren.pd` utilise aujourd'hui PuRestJson (C compilé : `json-encode`, `json-decode`,
`json-array-to-list`). Décision : passer à **pdjson**, un external maison en **pdlua**, déjà écrit
et testé (`~/repo/pd-externals/critapec/pdjson/pdjson.pd_lua`).

### Dépendances (déjà documentées dans `pdjson-help.pd`)

- L'external **pdlua** (le runtime Lua pour Pd).
- La bibliothèque Lua **lunajson** (`require 'lunajson'`).
- Installation :
  - macOS : `brew install lua && brew install luarocks`, puis `luarocks install lunajson`
  - Debian/Pi : `sudo apt install lua5.4 luarocks`, puis `luarocks install lunajson`
- **À vérifier avant le déploiement** : présence de lua5.4/luarocks/lunajson sur les machines cibles
  (Pi, Artila) — pas seulement sur le Mac de dev.

### API (méthodes sur l'inlet, `pdjson [fichier]` au constructeur)

| Message | Effet |
|---|---|
| `read <fichier>` | Charge/recharge un JSON en mémoire |
| `get <clé...>` | Navigue par chemin (clés string ou index numériques 0-based) ; sort la valeur, ou la sous-arborescence aplatie si c'est une table |
| `set <clé...> <valeur>` | Modifie une valeur par chemin, crée les tables intermédiaires si besoin |
| `dump` | Sort tout le JSON chargé, aplati en listes `[clé... valeur]` — une ligne par valeur terminale |
| `write <fichier>` | Sérialise l'état courant vers un fichier JSON |
| `dumpBinary` | Enveloppe l'état dans `{type:"CONFIG_FULL", config:...}`, encode, découpe en chunks binaires (4096 octets, préfixés taille totale + offset sur 4 octets) — pensé pour un envoi par canal binaire |

**Déjà validé sur un cas réel** : `config.json` à côté de l'external contient une config
`sirenConfig` avec `ambitus`/`clef`/`transposition` — la même forme que `sirenSpec.js` côté QML.
Ce n'est pas un jouet, c'est déjà rodé sur une structure proche de la nôtre.

**Portée pour ce projet** : pdjson peut porter à la fois la lecture de configuration (remplace
PuRestJson pour ça) et potentiellement la sérialisation du contrat `scenesList`/`composition`
(`PD_WORK.md`) avant envoi WebSocket — à confirmer si c'est le rôle qu'on lui donne ou si l'external
clips (§3) s'en charge lui-même.

### Manque identifié : pas de construction incrémentale — comblé (2026-07-17)

`pdjson` n'avait que `set <chemin> <valeur>`, qui suppose de connaître le chemin complet depuis la
racine à chaque appel — viable pour éditer une config déjà chargée, lourd pour construire à neuf un
payload comme `scenesList` à chaque envoi (des dizaines de `set` séquentiels pour une seule scène).

**Vérifié sur PuRestJson** (`~/repo/pd-externals/PuRestJson/unittests/json-encode/`, patchs
`add-object.pd`/`add-array.pd`) : `json-encode` a l'API qui manquait — `add`/`array`/composition
par imbrication/`clear`.

**Ajouté à `pdjson.pd_lua`** (portée réduite, une seule table Lua mutable avec curseur, pas
d'instanciation de plusieurs objets `pdjson`) :

| Message | Effet |
|---|---|
| `add <clé> <valeur>` | Écrit une paire clé/valeur dans l'objet courant (`self.builder`, ou le sous-objet visé par `push`) |
| `array <clé> <valeur>` (répété) | Accumule des valeurs dans un tableau sous une clé, un appel par valeur |
| `push <clé>` | Descend dans un sous-objet à cette clé (le crée si absent), l'empile comme curseur courant |
| `pop` | Remonte au niveau parent |
| `clear` | Vide `self.builder` et la pile de curseurs |
| `build` | Sérialise `self.builder` (via `table_to_json`, déjà utilisé par `write`) et le sort comme un unique atome symbole sur l'outlet |

État par instance (`self.builder`/`self.builderStack`), pas une variable de module comme
`json_data`/`jsonFileBuffer` — évite de reproduire le partage d'état inter-instances déjà présent
ailleurs dans le fichier pour les instances multiples de `pdjson`.

Syntaxe vérifiée avec `luac -p` (pas de runtime PD disponible dans cet environnement de dev — voir
`SCENES_SPEC.md`/session notes sur la vérification statique). **À tester en conditions réelles dans
Pd** avant de s'en servir pour sérialiser `scenesList`/`composition`.

## 2. `midifile` — lecture/écriture SMF bas niveau (déjà disponible)

`~/repo/pd-externals/critapec/midifile/` est un **vendoring identique** (diff vide) de
`mrpeach/midifile`, l'external MIDI file bien établi de Martin Peach — pas quelque chose écrit pour
ce projet, mais déjà présent et compilé (`midifile.pd_darwin`).

### Méthodes exposées (vérifiées dans `midifile.c`)

`read`, `write`, `rewind`, `dump`, `dump_notes`, `flush`, `meta`, `track`, `verbose`.

### Usage vu dans `midifile-help.pd`

- `write <fichier>.mid [ticks_par_noire]` — ouvre un fichier en écriture (défaut 90 ticks/noire).
- Événements MIDI envoyés comme triplets bruts `[status data1 data2]` — ex. `144 60 64` = note-on
  canal 0, note 60, vélocité 64. **Même format que le reste du patch pédalier** (pas de conversion
  supplémentaire à inventer).
- `track <n>` — sélectionne la piste courante.
- `meta <type> <data...>` — événements meta (tempo, **marker** — directement ce qu'on a spécifié en
  `SCENES_SPEC.md §11` pour structurer les fichiers sources).
- `flush` — finalise/ferme le fichier.

**Ce que ça couvre déjà, sans rien construire** : l'I/O SMF bas niveau pour `SCENES_SPEC.md §12`
(stocker un clip comme fichier `.mid`) et pour lire les markers d'un projet Reaper (§11). Ce n'est
**pas** l'external clips lui-même — c'est la brique sur laquelle il doit s'appuyer.

**Non vérifié** : `midifile` gère-t-il nativement le pitch bend (event `E0`) ? Le README/help ne le
montre pas explicitement dans les extraits lus — à tester, sinon prévoir une extraction manuelle des
events `0xE_` bruts. Pertinent pour `SCENES_SPEC.md §12` (conversion bend sirène 13 bits/centre 4096
↔ MIDI standard 14 bits/centre 8192).

### Protocole d'écriture — vérifié dans `midifile.c` (2026-07-17)

Le timing n'est **pas** automatique (pas de wall-clock implicite) — c'est l'appelant qui pilote tout,
confirmé en lisant `midifile_write_delta_time`/`midifile_float`/`midifile_list` :

1. `write <path> 480` — ouvre le fichier, **480 ticks/noire** pour matcher la convention déjà en
   place dans `~/repo/mecaviv/compositions` (`MIDI_LIBRARY_PREP.md` §2) — aucune conversion de
   résolution temporelle entre clip et compo.
2. `track <n>` — sélectionne la piste courante avant d'écrire dessus.
3. Avant **chaque** événement : un message `float <delta_ticks>` — en mode écriture, `midifile_float`
   fait `x->total_time += delta_ticks` (cumulatif, pas absolu). `x->total_time` est un compteur
   **partagé entre pistes** sur l'instance, mais chaque piste retient son propre `total_time` de
   dernier événement (`track_chunk[track].total_time`) — donc alterner les pistes avec des `track <n>`
   entre deux écritures reste correct, le delta par piste est recalculé indépendamment.
4. Puis l'événement lui-même en liste brute : `144 60 64` (triplet status/data, même format que le
   reste du patch, `midifile_list` n'ajoute pas de deltatime implicite — le `float` précédent est
   obligatoire).
5. `flush` — ferme le(s) fichier(s) **et écrit automatiquement l'End-of-Track de chaque piste active**
   (`midifile_write_end_of_track`, appelé en boucle dans `midifile_flush`) : pas besoin d'envoyer
   `meta 47` à la main.

Même protocole en lecture (`read`/`track`/`float`/`dump`), dans l'autre sens — pertinent pour
l'extraction directe depuis les compos existantes (§2 ci-dessus, `MIDI_LIBRARY_PREP.md` §3a) : un
seul chemin d'I/O SMF à connaître pour le clip recorder et pour l'extracteur, pas deux.

### Une version modifiée existe déjà — à retrouver et évaluer pendant le nettoyage

`midifile` a été **recodé pour SirenePupitre** afin d'extraire les durées de note **en avance**
(look-ahead), pour alimenter l'affichage d'anticipation (`AnticipationLine2D.qml`,
`FallingNote2D.qml`). Localisation : le patch **`M645.pd`**, dont plusieurs copies existent dans le
monorepo (situation qualifiée de « bordélique » par Patrice, nettoyage prévu cette semaine) :

- `mecaviv/puredata-abstractions/application.layer/M645.pd` — **41 usages de `midifile`**, 3902
  lignes. À côté de `harmonizer.pd` : probablement la version courante.
- `mecaviv/puredata-abstractions/examples/M645-test.pd` — 0 usage, probablement obsolète/test.
- `mecaviv/patko-scratchpad/volant/M645.pd` et
  `mecaviv/patko-scratchpad/sirenMidiRouter/abs/inputModules/M645.pd` — 0 usage chacun, copies
  scratch, probablement à écarter.

**Pas creusé plus loin ici** — le fichier va bouger pendant le nettoyage de la semaine. À retenir :
si cette version fait déjà du look-ahead de durée de note, elle est probablement **directement
réutilisable** pour l'extraction MIDI du `SCENES_SPEC.md §11` (qui demande le même genre de lecture
anticipée plutôt qu'une lecture séquentielle temps réel) — à évaluer au moment du nettoyage plutôt
que de réécrire cette capacité depuis zéro.

## 3. L'external clips — à construire

Contrairement à `pdjson` et `midifile`, celui-ci n'existe pas encore. Son rôle, tel que posé dans
`SCENES_SPEC.md §9` et `§12` : gérer les clips organisés en scènes — le pool de clips, la table des
scènes (7 cellules `clipRef`+mode), la composition, l'arbitrage `source` — avec, pour le stockage,
des fichiers `.mid` bruts (ligne mono, sans harmonie).

**Relation avec les deux briques ci-dessus** :
- S'appuie sur `midifile` pour l'I/O SMF réelle (lire/écrire les fichiers `.mid` des clips) —
  pas besoin de réimplémenter un parseur/writer SMF. Protocole d'écriture/lecture vérifié ci-dessus
  (§2, « Protocole d'écriture »).
- S'appuie sur `pdjson` (méthodes `add`/`array`/`push`/`pop`/`clear`/`build`, §1) pour le fichier
  `.json` compagnon de métadonnées de chaque clip.

**Décisions prises (2026-07-17)** :

- **Architecture** : `pdlua` ne peut pas appeler un external compilé (`midifile`, en C) comme une
  bibliothèque interne — il ne peut que lui envoyer des messages Pd. La seule architecture
  réalisable est donc une **abstraction `.pd`** qui instancie `midifile` + la logique clip/scène à
  côté (vanilla/pdlua), pas un binaire qui « enveloppe » `midifile`. Ce n'était pas vraiment un
  choix de conception, plutôt une contrainte de la plateforme.
- **Métadonnées non-MIDI d'un clip** (référence, statut « boucle de référence », rapport de
  longueur) : un **fichier `.json` compagnon**, écrit/lu par le patch via `pdjson` — pas édité à la
  main. `clip_XXX.mid` (brut, `midifile`) + `clip_XXX.json` (métadonnées, `pdjson`), séparation
  nette entre les deux formats.
- **Migration** des `clip_XXX/loop.N.txt` existants : **différée**, hors périmètre de ce chantier —
  l'external clips vise le nouveau matériau, la bibliothèque existante de loops sera traitée dans
  une session future.

## 4. `pdjson-help.pd` — section builder ajoutée

Une démo `clear`/`add`/`push`/`add`/`pop`/`build` a été ajoutée au patch d'aide (indices d'objets
52-63, connexions isolées du reste du patch, vérifiées programmatiquement pour ne référencer que des
indices existants). Pas encore ouvert dans Pd pour vérification visuelle — cet environnement de dev
n'a pas de runtime Pd (contrainte déjà notée pour toute la session, voir aussi `SCENES_SPEC.md`) ;
la cohérence structurelle (indices, connexions) est vérifiée statiquement, le rendu visuel ne l'est
pas.

## 4bis. `clip-io.pd` — construit et vérifié en conditions réelles (2026-07-17, refait 2026-07-18)

**Refait le 2026-07-18** selon les conventions de patching de Patrice, pour que le patch reste
lisible une fois ouvert (le premier jet, bien que fonctionnel, avait des câbles qui se croisent sur
tout le canevas) :

1. **`#X declare -path ... -path ... -lib pdlua`** en tête de patch — le patch trouve `midifile` et
   `pdjson` par lui-même, plus besoin de lancer Pd avec des `-path` en ligne de commande. Vérifié
   avec `pd -verbose` : les deux externals se chargent depuis les chemins déclarés, sans aucun flag
   CLI. Attention, `declare -path` prend des chemins absolus (pas de `~`, pas testé) — donc
   spécifique à cette machine tant que ces externals ne sont pas dans un chemin standard.
2. **Un sous-patch par branche** (`record`, `stop`, `read`, `dump`, `noteevent`), reliés au niveau
   racine par `route` puis par `send \$0.xxx`/`receive \$0.xxx` plutôt que des câbles longs — `\$0`
   scope les canaux à l'instance courante (plusieurs `clip-io` en parallèle ne se marchent pas
   dessus). Détail non évident : **un sous-patch n'hérite pas automatiquement du `\$1` du patch
   parent** — il faut le lui repasser explicitement en argument d'instanciation
   (`[pd record \$1]`), comme pour n'importe quel abstraction.
3. **Un seul `[list trim]`, bien placé** — mais **pas un seul pour tout le patch**, un par
   *canal de commandes* menant à chaque destination (`midifile`, `pdjson`), avec le flux
   d'événements MIDI bruts sur un canal **séparé qui contourne le trim**. Bug trouvé en testant la
   version « un seul trim pour tout ce qui va vers midifile » : `list trim` reconstruit
   correctement le message générique quand le premier atome est un **symbole** (`add id valeur` →
   sélecteur `add`, args préservés), mais avec un premier atome **flottant** (une liste
   d'événements MIDI bruts comme `144 60 64`), il **tronque tout au premier flottant** — la ligne
   de note enregistrée était devenue « `0 0 128 16363 0` » au lieu de la note correcte. D'où deux
   canaux distincts : `\$0.to-midifile` (commandes, passe par `[list trim]`) et
   `\$0.to-midifile-evt` (événements bruts, direct, aucun trim).

Retesté intégralement après la reconstruction (mêmes vérifications qu'avant : cycle complet, `.mid`
comparé octet par octet — **identique** au précédent, aucune régression). Détail de l'inventaire des
briques et du protocole `midifile` inchangé, voir ci-dessous.

**Passe 2, mise en page (2026-07-18)** : Patrice a corrigé à la main les sous-patches `record` et
`stop` dans l'éditeur Pd, avec deux règles supplémentaires — détaillées dans la mémoire
`pd-patching-conventions` :

- **Jamais connecter une seule sortie à plusieurs destinations directement** — toujours passer par
  un `trigger` explicite, même quand l'ordre entre les destinations n'a pas d'importance
  fonctionnelle (rend le branchement visible plutôt qu'implicite).
- **Lecture verticale = ordre d'exécution** : les sorties d'un `trigger`/`unpack` se déclenchant
  droite-à-gauche, la convention adoptée place le résultat qui se déclenche en premier **en haut**
  (ou en colonne la plus proche), et empile la suite en dessous plutôt que de laisser les câbles
  se croiser sur tout le canevas.
- **Types de trigger** : `b`/`f`/`s`/`l`/`a` peuvent être mélangés dans un seul `[t ...]`, mais `b`
  (bang) et `a` (anything) restent le choix par défaut — les types plus précis seulement quand la
  valeur réelle est nécessaire en aval (ex. `[t b l]` dans `stop` : la sortie `l` porte la vraie
  liste vers `unpack`, la sortie `b` ne sert qu'à déclencher la suite).

Les sous-patches `read` et `dump` avaient la même faute (`route`/`list split` connectés directement
à deux destinations) — corrigés à la suite, avec `[t a a]` (les deux branches de `read` ont besoin
de la vraie valeur du `clipId`) et `[t b b]` (les deux branches de `dump` n'ont besoin que d'un
déclencheur). Revérifié structurellement (script nesting-aware) et en Pd réel — sortie strictement
identique, aucune régression.

**Piège trouvé au passage, confirmé répété (pas un accident isolé)** : la ligne `#X declare`
disparaît du fichier **à chaque** aller-retour dans l'éditeur Pd sur cette machine — arrivé trois
fois dans la même session. Casse silencieusement le chargement de `pdjson`/`midifile`
(`error: ... couldn't create`) jusqu'au prochain test. Traiter comme acquis : `grep "#X declare"`
et la remettre si absente, en routine avant de faire confiance à un test sur un patch rouvert dans
l'éditeur depuis la dernière modification.

**Portabilité du `declare`** (correction de Patrice) : la première version pointait vers un chemin
absolu propre à cette machine (`/Users/patricecolet/repo/pd-externals/...`). Corrigé vers
`~/Documents/Pd/externals/critapec` et `~/Documents/Pd/externals/pdjson` — le dossier deken
standard que Pd lit par défaut selon l'OS. Vérifié que `~` s'expanse bien dans `declare -path`
(pointé vers un dossier de test isolé, confirmé par `pd -verbose` que Pd a cherché le chemin
absolu correctement résolu). Le patch dépend maintenant explicitement de cette copie déployée —
à resynchroniser avec le dépôt git à chaque modif de `pdjson`/`midifile` (mémoire
`pd-externals-shadowing`).

**Detour `list split 3` pour `noteevent` (suggestion de Patrice) — élégant, mais mène à un vrai bug
plus subtil.** `[list split 3]` évite le repackage `pack f f f` de `unpack f f f f`, séduisant sur
le papier. Vérifié isolément (contenu et ordre corrects), et même vérifié « typé float » via
`[route float]` après un `[list trim]` sur le reste — mais ça ne suffisait pas : le vrai patch
continuait à écrire un `.mid` corrompu (`error: midifile: sysex list terminator is 0x0`,
`deltaTicks=240=0xF0` interprété comme un octet de statut SysEx). La trace verbose de `midifile`
lui-même (`verbose 3`) a montré que la valeur passait toujours par son gestionnaire `list`
(`midifile_list`), jamais par `midifile_float`, **malgré** le typage apparent confirmé par
`[route float]`. Explication : `route float` est un objet de confort qui accepte une liste à un
seul flottant comme un vrai `float` — le dispatch strict `class_addfloat` d'un external C n'a pas
cette tolérance. `unpack` reste le bon choix ici : ses sorties individuelles déclenchent
réellement `class_addfloat`, vérifié par le comportement de `midifile` lui-même, pas par un test
de confort. `noteevent` est resté sur `unpack f f f f` + `pack f f f` (le design original,
re-vérifié identique octet pour octet).

**État final vérifié** (2026-07-18, fin de session) : `declare` portable, `record`/`stop`/`read`/
`dump` selon les règles de patching (sous-patches, trigger, alignement de colonnes), `noteevent`
sur `unpack`/`pack`. Cycle complet retesté sans flag CLI, `.mid` identique octet pour octet à
toutes les versions précédentes validées, zéro erreur.

**Bug de fond corrigé dans `pdjson.pd_lua` : chemin relatif mal résolu.** En préparant un dossier de
démo committable pour `clip-io-help.pd` (pour éviter `/tmp`, cassé au premier redémarrage), test
comparatif de `midifile` et `pdjson` sur le même chemin relatif : `midifile` le résout correctement
par rapport au **dossier du patch appelant** ; `pdjson` le résolvait par rapport à **son propre
dossier d'installation** (`resolvePath` utilisait `self._loadpath`, qui pointe vers l'emplacement
du script `pdjson.pd_lua` lui-même, pas vers le patch instanciateur). Trouvé par introspection
directe du runtime (petit external pdlua de diagnostic listant tous les champs de `self`) plutôt
que par lecture de source, qui n'a donné aucune piste : le bon champ est **`self._canvaspath`**.
Corrigé dans `pdjson.pd_lua` (et resynchronisé vers `~/Documents/Pd/externals/pdjson/`) — un chemin
relatif donné à `pdjson` se résout maintenant comme celui donné à `midifile`, cohérent pour
n'importe quel patch qui utilise les deux (pas seulement `clip-io.pd`). Revérifié : cycle complet
`record`→`stop`→`read`→`dump` avec un dossier de clips **relatif**, `midifile` et `pdjson`
d'accord sur l'emplacement, zéro erreur.

**`clip-io-help.pd` construit et testé** — patch d'aide manuel/interactif, dans le même dossier que
`clip-io.pd`, suivant la convention déjà en place localement (`curve-map-help.pd` : boîtes de
message étiquetées câblées directement sur l'abstraction, pas d'auto-séquencement). Un message par
étape (`record`/événements/`stop`/`read`/`dump`), trois `print` pour observer les trois outlets.
Vérifié fonctionnellement via un enrobage temporaire à déclenchement automatique (retiré après
test, pas livré) : cycle complet correct, `.mid` produit correct, zéro erreur. Accompagné de
`clip-io-demo/` (dossier committé, chemin relatif, à côté des deux patches) contenant un vrai
`demo-clip.mid`+`.json` pré-généré — les étapes 4/5 (`read`/`dump`) fonctionnent sans avoir joué
les étapes 1-3 avant, vérifié isolément.

Abstraction dans `mecaviv/puredata-abstractions/application.layer/clip-io.pd` (à côté de
`harmonizer.pd`) — combine `midifile` + `pdjson` pour l'I/O d'**un** clip, selon les décisions du
§3. Construite par génération programmatique (indices d'objets et connexions calculés et vérifiés
par script avant écriture) **puis réellement testée dans Pd 0.55** en mode headless
(`pd -nogui -stderr -noaudio -nomidi`, `pd` est installé sur cette machine) : cycle complet
`record` → événements MIDI → `stop` → `read` → `dump`, sortie confirmée **octet par octet** (`.mid`
décodé à la main : en-tête `MThd` correct, format 0, 1 piste, 480 ticks/noire, meta-event nom de
piste, Note On/Off avec delta-time correctement encodé, End-of-Track automatique ; `.json`
compagnon avec les 5 champs attendus).

**Trois bugs réels trouvés et corrigés grâce à ce test** (aucun n'était visible par relecture
statique) :

1. **`route` transforme un reste commençant par un symbole en message "générique"** (sélecteur =
   ce symbole), pas en message `list`/`symbol` — `[t l l]`/`[t s s]` ne peuvent PAS convertir un
   message générique (`error: trigger: generic messages can only be converted to 'b' or 'a'`).
   Fixé en passant ces `trigger` à `t a a` là où le reste peut commencer par un symbole.
2. **`[list prepend ...]` encapsule toujours sa sortie sous le sélecteur `list`**, même quand le
   premier atome ajouté est un symbole voulu comme sélecteur (`add`, `write`, `meta`, `read`,
   `writeBuilder`). `pdjson` (pdlua) le rejette bruyamment (`no method for 'list'`) ; `midifile` (C,
   sans override list) le **rejette silencieusement, sans aucune erreur** — c'est ce deuxième cas
   qui a fait perdre le plus de temps (le patch semblait tourner sans erreur, mais n'écrivait aucun
   `.mid`). Fixé en insérant `[list trim]` après **chaque** `list prepend` menant à `pdjson` ou
   `midifile` (10 au total) — `list trim` désencapsule le message générique depuis son enveloppe
   `list`, déjà un idiome utilisé dans `pdjson-help.pd` lui-même.
3. **L'ordre des outlets d'une abstraction est déterminé par la position X des objets `[outlet]`
   dans le canvas, pas par leur ordre d'écriture dans le fichier.** `OUT_MIDI` était physiquement à
   gauche d'`OUT_META` → les deux outlets étaient inversés côté appelant, sans erreur, juste des
   données au mauvais endroit. Fixé en réordonnant les positions X.

**Découverte annexe, importante** : `~/Documents/Pd/externals/pdjson/` contient une copie
**indépendante** de `pdjson.pd_lua`/`pdjson-help.pd` (deken, pas un lien symbolique), antérieure à
toutes les modifications de cette session (datée d'octobre 2025), et **prioritaire dans le chemin de
recherche par défaut de Pd** sur le dépôt `critapec` — confirmé via `pd -verbose`. C'est cette copie
qui a été chargée dans les deux premiers essais et qui a produit les erreurs "no method" trompeuses.
Elle a été resynchronisée avec `critapec/pdjson/` (copie directe, pas un lien) pour que la vraie
config Pd de cette machine profite des correctifs. **Si `pdjson` est modifié à nouveau, penser à
resynchroniser cette copie** — les deux dossiers ne sont pas liés automatiquement.

**Nom de méthode évité** : `clear` seul ne dispatch jamais vers `in_1_clear` (semble intercepté par
Pd/pdlua avant résolution de méthode personnalisée, sans message d'erreur clair sur la cause) —
renommé `clearBuilder`, cohérent avec `writeBuilder`.

**Instanciation (v3, 2026-07-19) : `[clip-io]`, sans argument.** Le dossier des clips est
maintenant un **état runtime**, plus un argument de création — voir « v3 » ci-dessous pour la
raison et le détail. `[clip-io <clipsDir>(` (le `\$1` d'origine) n'existe plus.

**Simplification assumée** : un clip est **mono-piste** (SMF track 0 unique) — contrairement aux
compos existantes (SMF1, une piste par sirène), un clip ne porte qu'une ligne, donc pas besoin de la
structure multi-piste. Le nom de piste est posé via `meta 3 <clipId>` (Sequence/Track Name).

**Messages acceptés (inlet unique)** :

| Message | Effet |
|---|---|
| `record <clipId> <sirenId>` | `pdjson clearBuilder`, ouvre `<clipId>.mid` en écriture (480 ticks/noire), pose `meta 3 <clipId>`, mémorise le chemin `.json`, initialise les métadonnées (`id`, `siren`) |
| `[status data1 data2 deltaTicks]` (liste à 4 floats, **ticks en dernier** — voir note d'ordre ci-dessous) | Écrit un événement MIDI brut dans le clip en cours |
| `stop <lengthTicks> <lengthBars> <isReference 0\|1>` | Complète les métadonnées, `pdjson writeBuilder` vers le `.json` mémorisé, `flush` le `.mid` (End-of-Track automatique), bang sur l'outlet status |
| `read <clipId>` | Ouvre `<clipId>.mid` en lecture + charge `<clipId>.json` — ne sort rien tant que `dump` n'est pas envoyé (même convention que `pdjson` seul) ; `midifile` sort spontanément le format/nb de pistes/résolution sur son outlet status à l'ouverture |
| `dump` | Sort les métadonnées (outlet 0, depuis `pdjson dump`) et les notes consolidées note-on+off avec durée (outlet 1, depuis `midifile dump_notes`) |
| `dir <chemin>` | **(v3)** Change le dossier des clips utilisé par `record`/`read`. Défaut `.` (dossier du patch appelant) tant qu'aucun `dir` n'a été envoyé. |

**Outlets** (ordre réel côté appelant, vérifié — déterminé par la position X des `[outlet]` dans le
patch, pas par l'ordre d'écriture, cf. bug §3 ci-dessus) : **0 = métadonnées** (pdjson), **1 =
données MIDI** (midifile), **2 = statut** (bang de fin d'écriture côté patch, plus tout ce que
`midifile` sort lui-même sur son outlet `anything` — format/pistes/résolution à la lecture).

**Note d'ordre volontaire** : le format d'événement est `[status data1 data2 deltaTicks]`, avec le
delta-tick **en dernière position**, pas en premier comme on l'écrirait naturellement. C'est fait
exprès : `midifile` exige le `float` (delta) *avant* la liste d'événement (§2 ci-dessus), et l'ordre
de déclenchement naturel de `[unpack f f f f]` en Pd est droite-à-gauche — mettre `deltaTicks` en
dernier atome le fait sortir en PREMIER de `unpack`, dans le bon ordre, sans `trigger` supplémentaire
pour ce sous-chemin précis. Documenté aussi en commentaire dans le patch lui-même.

### v3 (2026-07-19) — le dossier des clips devient un état runtime, pas un argument

**Problème de fond identifié par Patrice**, en repérant `clip-io \$0` (mal typé — `\$0` est un
entier, pas un chemin) dans `pedalier.pd` : ce n'était pas juste une coquille, mais un défaut de
conception plus profond. Fixer `<clipsDir>` dans les arguments de création (`\$1`) suppose que le
dossier est connu au moment où l'abstraction est instanciée — or il ne peut pas l'être si on veut
garder le patch **portable** (chemin relatif au patch, pas absolu, cf. règle générale « pas de
chemin absolu ») *et* que le dossier puisse varier en cours d'exécution (plusieurs sirènes/scènes
enregistrant dans des sous-dossiers différents, par exemple) : créer dynamiquement une nouvelle
instance d'abstraction par dossier n'est pas raisonnable.

**Solution retenue** : le dossier des clips devient un **message runtime** (`dir <chemin>`) plutôt
qu'un argument de création. Défaut `.` (résolu par rapport au dossier du patch appelant, cohérent
avec `midifile`/`pdjson`, cf. `_canvaspath` plus haut), appliqué au chargement via `loadbang`.
`record`/`read` demandent le dossier courant à un aller-retour `send $0.reqdir` /
`receive $0.clipdir` avant de construire le chemin final.

**Construction du chemin — trois mécanismes essayés, un retenu**, suite à une préférence explicite
de Patrice pour éviter les externals quand un message suffit :

1. `makefilename` (rejeté) — un seul spécificateur `%s` runtime supporté ; le format `%s/%s.mid`
   avec deux valeurs runtime (dossier + id) donne `error: invalid format string ... too many
   format specifiers`. Ne convient que si l'un des deux segments est fixé à la création (ce qui
   est précisément ce qu'on abandonne).
2. `pack`/`makesymbol` (rejeté) — fonctionnel, mais chaque inlet froid typé `s` exige un
   enrobage explicite `"symbol X"` (vérifié via le patch d'aide officiel de `pack`), ce que
   Patrice préfère éviter pour simplifier le patching.
3. **`[list prepend]` + boîte de message à substitution `$` (retenu)** — `[list prepend]` (sans
   arguments) accepte des valeurs brutes sur son inlet froid, pas d'enrobage symbole nécessaire ;
   la liste `[dossier clipId]` résultante alimente une boîte `[$1/$2.mid(` qui fait la
   concaténation par substitution de position, sans aucun external. C'est la méthode adoptée pour
   les deux chemins (`.mid` et `.json`) dans `record` et `read`.

**Nouveaux pièges trouvés en la mettant en place** (aucun visible par relecture statique, tous
confirmés par test réel dans Pd — voir la règle générale sur le test réel) :

- **`pack`/`list prepend` ont des rôles chaud/froid inversés.** Migrer un design de l'un à l'autre
  oblige aussi à inverser l'ordre de déclenchement du `trigger` en amont : `[t b s]` (correct pour
  `pack`, froid=dossier déjà posé, chaud=id déclenche) devient `[t s b]` pour `list prepend`
  (chaud=id déclenche, mais le froid=dossier doit être posé **avant**, donc sortir en dernier du
  trigger). Repéré en observant un message d'erreur trompeur (« argument number out of range » sur
  la boîte `$1/$2`) alors que la sortie de `list prepend`, vérifiée isolément via `print`, était
  correcte.
- **`[t s s s s]` tronque une liste multi-atomes au premier élément.** La paire
  `[dossier clipId]` sortant de `list prepend` perdait `clipId` en traversant ce trigger — les
  types `s`/`f` d'un trigger convertissent en valeur unique, pas en liste. Fixé en passant à
  `[t a a a a]` partout où une liste complète doit survivre à la traversée d'un trigger (déjà noté
  comme règle générale, confirmé concrètement ici).
- **Le résultat d'une boîte à substitution `$` sur un seul atome peut rester un message
  « générique »**, pas un vrai message `symbol` — casse en arrivant sur l'inlet froid strict de
  `[symbol]` dans le sous-patch `stop` (`error: inlet: expected 'symbol' but got
  './defclip.json'`), alors que le même mécanisme fonctionnait sans problème pour le chemin `.mid`
  (qui alimente l'inlet chaud, permissif, de `pack` côté `midifile`). Fixé en insérant
  `[list prepend symbol] -> [list trim]` juste avant `send $0.jsonpath` dans `record`. Pas
  nécessaire côté `read` (le chemin `.json` y passe par le dispatch générique de `pdjson` via
  `[list prepend read]`, pas par un inlet strict).

**Revérifié intégralement** (2026-07-19, headless `pd -nogui`) : cycle par défaut (`.`) et cycle
avec `dir` explicite (dossier alternatif) — les deux produisent des fichiers `.mid`/`.json`
corrects au bon endroit, zéro erreur dans les deux cas. `pedalier.pd` mis à jour (`clip-io \$0` →
`clip-io`, argument obsolète retiré) et `clip-io-help.pd` mis à jour (`clip-io clip-io-demo` →
`clip-io` nu + `loadbang`/`dir clip-io-demo` pour préserver le comportement « les étapes 4/5
marchent seules » sans dépendre d'un argument de création).

**Ce que ce patch ne fait PAS (hors périmètre, à construire séparément)** :
- Le pool de clips / la table des scènes à 7 cellules / l'arbitrage `source` (§3, `SCENES_SPEC.md
  §9`) — `clip-io.pd` gère un clip à la fois, pas l'orchestration entre plusieurs.
- Le câblage réel dans `voiceRecorder.pd`/`harmonizer.pd` existants (vérifié : ils n'utilisent
  aujourd'hui ni JSON ni `midifile`, stockage `text`/`sequence` — `clip-io.pd` est un nouveau bloc
  autonome, pas une modification de l'existant).
- **Testé une fois, en local, headless, un seul clip mono-événement** (record → 1 note → stop →
  read → dump) — pas encore testé en répétition, pas testé avec plusieurs clips séquentiels dans la
  même session Pd, pas testé le cas `record` sans `stop` préalable ni les erreurs de chemin (dossier
  absent, permissions).

## 5. Ce qui reste hors de ce document

- Le recâblage de l'harmoniseur pour recevoir plusieurs sources (`SCENES_SPEC.md §9`) — pas un
  problème de stockage, à traiter séparément.
- Le grand nettoyage du patch existant (`SCENES_SPEC.md §13`) — ce doc prépare le terrain du
  nouveau patch, il ne dit pas quoi supprimer de l'ancien.

## Ajouts à `pdjson` — `pushArray` et `setB`

Le tableau de l'API en §1 est incomplet ; deux méthodes du constructeur s'y sont ajoutées depuis.
Toutes deux sont documentées dans `pdjson-help.pd` (sections dédiées, en bas du patch).

| Message | Effet |
|---|---|
| `pushArray <clé>` | Ajoute un **nouvel** objet vide au tableau à cette clé et y descend le curseur. `push` seul redescend dans *le même* objet à chaque appel — il ne peut donc pas construire une liste d'éléments distincts. `pop` referme l'élément, prêt pour le suivant. |
| `setB <chemin...> <valeur>` | Comme `set`, mais sur le **builder** au lieu de `json_data`. Crée les tables intermédiaires ; un élément de chemin numérique est un index de tableau 0-based (donc `scenes 0` puis `scenes 1` construisent un tableau à deux éléments). |

**Pourquoi `setB` compte** : `<clé...> <valeur>` est *exactement* la forme que `dump` émet. Le dump
d'un fichier peut donc être réinjecté tel quel dans le builder, ligne par ligne, sans être retraduit
en séquence `push`/`add` côté patch — ce qui aurait demandé un analyseur de chemin à profondeur
variable (`tempo 120` = 2 atomes, `harmony voicing 0 degree 0` = 5). C'est ce qui rend l'agrégation
de N fichiers de scènes en un seul `scenesList` tenable en Pd.

Contrairement à `set`, `setB` **ne fait pas de `deepcopy`** : appelé une fois par ligne de dump, soit
des centaines de fois par payload, copier l'arbre entier à chaque appel serait ruineux.

**Attention au déploiement** : Pd charge `~/Documents/Pd/externals/pdjson/` (chemin par défaut), pas
la copie git de `~/repo/pd-externals/critapec/pdjson/`. Les deux doivent être synchronisées à la
main après chaque modification — sinon le patch tourne sur une version périmée sans le dire.
