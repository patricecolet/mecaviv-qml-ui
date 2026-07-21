# Machine à états du looper pédale — enregistrement/lecture par sirène

Doc de synthèse pour ne pas perdre le fil pendant la construction (2026-07-19). Décrit le
comportement voulu pour la pédale REC/PLAY et la pédale STOP, par sirène, et comment ça se
raccorde à l'architecture déjà construite (`composition-io.pd`, `siren-clip-loader.pd`,
`clip-io.pd`, `midiclock.pd`). Ne remplace pas `SCENES_SPEC.md` (modèle scène/clip/harmonie) ni
`PD_WORK.md` (contrat de messages écran↔PD) — complète les deux côté "enregistrement live au
pied", qu'aucun des deux ne couvrait.

Contexte de la commande physique : `pd control.midi.routing` dans `pedalier.pd` reçoit les
messages MIDI du pédalier, retrouve le canal (= numéro de sirène) correspondant à la voix
sélectionnée, et route le bang REC/PLAY et le bang STOP par canal. Reste à construire : la
réception de ces bangs côté moteur de lecture, et la machine à états elle-même.

---

## 1. États, par sirène

```
VIDE ──rec/play (court)──► ENREGISTRE ──rec/play (court, en fin de mesure)──► JOUE
 ▲                              │                                              │
 │                    rec/play (long) = efface                        stop (court, immédiat)
 │                    stop (long) = efface                                     │
 └──────────────────────────────┴──────────────────────────────────────────────┴─► ARRÊTÉ (rempli)
                                                                                      │
                                                                          rec/play (court) ──► JOUE
                                                                          rec/play (long) = efface
                                                                          stop (long) = efface
```

- **VIDE** : pas de clip chargé pour cette sirène.
- **ENREGISTRE** : `clip-io` en train d'enregistrer (entre `record` et `stop`).
- **ARRÊTÉ** : un clip existe (chargé), mais rien ne pousse le pulse de `midiclock` vers son
  `clip-io` — pas de lecture en cours.
- **JOUE** : le pulse de `midiclock` avance ce `clip-io`, ce qui sort du MIDI vers `composeSiren~`.

## 2. Transitions

| État actuel | Entrée | Effet | Quantization |
|---|---|---|---|
| VIDE | rec/play court | démarre l'enregistrement | **attend le prochain bar, avec décompte** — même le tout premier enregistrement (contrairement à un looper audio classique, on est en MIDI : le joueur doit se caler sur un clic, il n'y a pas de détection de tempo a posteriori). "Pas de mainloop" ne veut donc pas dire "immédiat" — ça veut dire "pas de longueur existante à respecter" (voir §3). |
| ENREGISTRE | rec/play court | arrête l'enregistrement à une longueur en **puissance de 2 relative à la mainloop** (1x, 2x, 4x, 8x…) — pas forcément au moment exact de l'appui ; part en lecture ensuite | quantizé au prochain palier de longueur valide, pas juste au bar courant |
| ENREGISTRE | **stop** court | arrête l'enregistrement **immédiatement**, sans quantization — comportement distinct de rec/play | **immédiat, jamais quantizé** |
| ARRÊTÉ | rec/play court | part en lecture | **immédiat** — seule exception, rec/play attend toujours le début de mesure sauf dans ce cas (confirmé par Patrice) |
| JOUE | stop court | arrête | **immédiat, jamais quantizé** (confirmé par Patrice) |
| tout état non-vide | rec/play long **ou** stop long | efface, retour à VIDE | immédiat |

## 3. Le concept de "mainloop"

La toute première boucle enregistrée n'a rien à quoi se synchroniser — elle **devient** la
référence de tempo/mesure ("mainloop") pour tout le reste de la composition/scène. Les
enregistrements suivants se calent dessus (quantizés au prochain bar de cette référence).

**Règle de longueur relative** (donnée par Patrice) : si une boucle nouvellement enregistrée est
**plus longue** que la mainloop actuelle, elle **devient** la nouvelle mainloop. La longueur finale
se cale sur une **puissance de 2 relative à la mainloop** (1x, 2x, 4x, 8x…) — concept déjà présent
dans le protocole existant (`PD_WORK.md`, champ `loopSize`/`ratio` de `SIREN_LOOPER.loops.states[]`,
"le rapport en puissance de 2" qui alimente l'échelle des paliers côté écran). Pas une nouvelle
idée à inventer, un mécanisme déjà documenté à réutiliser ici.

**Décompte (count-in)** : contrairement à un looper audio classique (qui peut déduire le tempo a
posteriori de la longueur jouée), on est en MIDI — le joueur doit se caler sur un clic (visuel ou
sonore) **avant même le tout premier enregistrement**. "Pas de mainloop" ne veut donc pas dire
"démarrage immédiat" — ça veut seulement dire "pas de longueur existante à respecter". Le
déclenchement passe par un décompte, y compris pour la toute première boucle.

**Préservation d'offset** : si l'enregistrement démarre au milieu du cycle de la mainloop (ex. la
mainloop dure 2 mesures, et on enregistre à partir de la mesure 2 de ce cycle), le nouveau clip
doit se souvenir de cet **offset de départ** pour que sa lecture en boucle reste callée en phase
sur le cycle de la mainloop — pas de décalage à la lecture.

**Point non tranché** : comment est déterminé "il y a déjà un mainloop qui tourne" ? Deux
propositions discutées :
- Interroger `midiclock` (transport `playing`) — **rejeté par Patrice** : "c'est pas l'état de
  midiclock mais l'état de [notre] buffer qui est la source de vérité."
- Un buffer d'état de scène (à construire dans le nouveau système — voir §5) qui retient
  explicitement quelle sirène porte la mainloop actuelle, sa longueur, et son offset zéro.

## 4. Ce qui existe déjà dans l'ancien système (`harmonizer.pd`, sous-patch `recorder`, lignes
   1167–2764) — analysé en lecture seule, à *adapter*, pas à copier tel quel

Le stockage sous-jacent (`text define`) est incompatible avec notre nouveau système
(`clip-io`/`midifile`), mais la **logique** est réutilisable :

- **Buffer d'état** : `\$1.loop.definition` (`text define`), un buffer texte par instance
  (scoping `\$1`), avec des lignes taguées `mainLoop <size>`, `tempo <val>`, `voice.select <n>`,
  `isLoop <n> <val>`, `playing <n> <val>`, `loopSize <n>`, `loopBar <n>`.
- **Détection mainloop existant** : `text search \$1.loop.definition` sur le symbole `mainLoop`,
  puis `route -1` — trouvé (`mainLoopInit`, sous-patch 1949-1989, crée l'entrée `mainLoop` + lit
  `\$1.reaper.tempo.receive`) vs pas trouvé (`loopInit`, 1990-2020, rejoint la référence
  existante).
- **Quantization** : sous-patch `waitBar` (1837-1866) — un `spigot` s'ouvre sur le déclenchement
  (`\$1.rec.play.loop`), laisse passer **le prochain** `\$1midi.clock.bar.bang`, se referme
  aussitôt. Toute action qui passe par `waitBar` attend donc le prochain bar.
- **Non trouvé dans ce sous-patch** : le mécanisme de *bypass* "démarrage immédiat si pas encore de
  mainloop" — la branche candidate (`text size \$1enabled.pedals` → `> 0` → `sel 1`, lignes
  1849-1851) n'a **aucune connexion sortante** dans le patch. Semble être du code mort/inachevé
  (cohérent avec des annotations `?` laissées ailleurs par Patrice dans ce même fichier). **À
  construire de zéro côté nouveau système**, pas à porter depuis l'ancien.
- **Non trouvé** : persistance de ce buffer dans la sauvegarde de scène — le `text define` n'a pas
  le flag `-k` (keep), donc pas sauvé automatiquement par Pd. La logique de sauvegarde évoquée par
  Patrice doit être ailleurs (hors de ce sous-patch, ou dans le nouveau système à construire).

## 5. Structure retenue

Nouvelle abstraction **`siren-loop-state.pd`**, une instance par sirène (même pattern que
`siren-clip-loader.pd`) :
- reçoit les bangs rec/play et stop, déjà routés par canal via `pd control.midi.routing`
  (`pedalier.pd`) ;
- porte la machine à états (§1-2) ;
- envoie `record`/`stop` à son `clip-io` (elle pilote, `siren-clip-loader.pd` reste focalisé sur
  "charger un clip depuis une scène") ;
- **filtre le pulse de `midiclock`** : ne le laisse passer vers `clip-io` que si l'état est JOUE.

Détection "mainloop existe" : état **partagé au niveau de `looper`** (pas par sirène) —
`\$0.mainloop.siren` + `\$0.mainloop.lengthTicks`, mis à jour à chaque fois qu'une boucle devient
la référence. Repris du même pattern que `compdir`/`rootdir` dans `composition-io.pd`.

## 5ter. État actuel (2026-07-19)

`siren-loop-state.pd` est **construit et testé en headless** (`application.layer/siren-loop-state.pd`,
non versionné pour l'instant) : machine à états complète (§1-2), 6 transitions vérifiées de bout en
bout (VIDE→ENREGISTRE→JOUE→ARRÊTÉ→JOUE→VIDE). Interface :
- inlet unique, messages `recplay <0|1>`, `stop <0|1>`, `bar` (bang), `mainloop <0|1>` ;
- 5 outlets, chacun labellisé par un argument texte sans effet — voir CLAUDE.md global, gotcha
  `[outlet]`. **L'ordre réel est `record`, `playgate`, `stopclip`, `erase`, `state`**, donné par la
  position x des objets `outlet` (31, 100, 245, 462, 644) et non par leur ordre d'écriture dans le
  fichier. Une version antérieure de cette section annonçait `record, stopclip, playgate, erase,
  state` — c'était faux ; le câblage dans `siren-clip-loader.pd`, lui, a toujours suivi l'ordre
  réel ;
- état interne dans des `value \$0-state` / `\$0-pending` / `\$0-mainloopflag`, `\$0` obligatoire
  (confirmé : `[value]` est global par nom, pas local au patch — voir CLAUDE.md global).

Intégré comme **placeholder non câblé** dans `examples/pedalier.pd`, sous-patch `looper` (une seule
instance `[siren-loop-state]`, sans argument, aucune connexion) — pas encore le pattern
`<index> \$0` de `siren-clip-loader`, pas encore relié à un `clip-io` ni au `bar` de `midiclock.ws`.

**Prochaines étapes concrètes** (dans l'ordre logique) :
1. Donner à `siren-loop-state` les arguments `<index> \$0` (même pattern que
   `siren-clip-loader <N> \$0.scene.broadcast \$0`), et l'instancier 7 fois dans `looper`.
2. Câbler `outRecord`/`outStopclip` vers le `clip-io` correspondant (`record`/`stop`).
3. Câbler `outPlaygate` en filtre du pulse `midiclock` vers ce même `clip-io` (ne laisse passer le
   pulse que si JOUE — voir §5, dernier point).
4. Câbler l'entrée `bar` sur le vrai `bar` de `midiclock.ws` (actuellement testé avec un bang de
   synthèse seulement).
5. Construire le mainloop partagé (`\$0.mainloop.siren` / `\$0.mainloop.lengthTicks`, niveau
   `looper`) et l'entrée `mainloop` de chaque instance.
6. Câbler l'entrée réelle `recplay`/`stop` du pédalier (`pd control.midi.routing`, déjà routé par
   canal) vers l'inlet de chaque `siren-loop-state`.
7. Couche `clip-io` note-events → `composeSiren~` (protocole `<type> <param1> <param2> <canal>`,
   déjà clarifié §2 de la conversation, pas encore construite).

## 5quater. Chargement de scène fiabilisé (2026-07-21)

Le chargement compo→scène→clip était en place mais ne fonctionnait pas. Cinq défauts trouvés et
corrigés, tous vérifiés en Pd headless sur `examples/pedalier.compositions/12/` :

**Deux pièges de `pdjson dump`**, à retenir pour tout autre consommateur du même flux :
- une clé `null` (`"clipRef": null`) **n'apparaît pas du tout** dans le dump — l'absence d'une ligne
  est donc porteuse de sens, et ne peut pas être détectée en réagissant ligne par ligne ;
- l'ordre du dump est celui du **hash Lua**, pas celui du fichier JSON — `mode` peut précéder
  `clipRef`.

Conséquence : `composition-io.pd` (v3) encadre désormais son dump de scène par les marqueurs
`begin` et `end` sur la sortie scène. **Le trigger qui les produit doit être placé *avant* le
message box `read …, dump`** : la virgule y fait sortir deux messages, donc placé après il
encadrerait chacun séparément.

`siren-clip-loader.pd` mémorise (`begin` remet les deux `[symbol]` aux sentinelles `none`/`empty`,
les lignes du dump s'y rangent dans le désordre) et applique à `end`, dans l'ordre imposé **clip
puis mode**. Un `clipRef` resté à `none` déclenche un `clear` — c'est ce qui empêche une sirène de
garder le clip de la scène précédente.

`clip-io.pd` (v5) gagne ce message `clear` : `midifile` n'a **aucune méthode de vidage** (méthodes
réelles : `read write track flush rewind dump dump_notes meta verbose`), donc `clear` fait un
`rewind` et ferme une porte `$0.loaded` sur le passage `bang`/`float` vers `midifile`, puis annonce
`cleared` sur la sortie status. `read` rouvre la porte.

Deux bugs de fond trouvés au passage :
- **`pd read` de `clip-io` passait le nom du clip dans un `makefilename %d`** — tout nom symbolique
  devenait `0`, donc `read clip_A` cherchait `clips/0.mid`. Aucun clip nommé n'était lisible, y
  compris via `clip-io-help.pd` qui appelle pourtant `read demo-clip`. Remplacé par un `[symbol]`.
- **`pd mode` de `siren-loop-state` n'ouvrait jamais le playgate** : le seul
  `s $0.outlet.playgate` du canvas racine n'était alimenté que par le `msg 0` du chemin d'arrêt.
  Charger une scène en `mode play` posait bien l'état à 2 (l'écran affichait « joue ») sans
  qu'aucun pulse n'atteigne `clip-io` — **une scène ne jouait pas**. Les messages de mode portent
  maintenant `<état> <playgate>` ensemble (`empty → 0 0`, `play → 2 1`, `stop → 3 0`), un seul
  `unpack f f` ouvre la porte avant d'annoncer l'état.

`oneshot` repasse en ARRÊTÉ en fin de clip : `midifile` émet bien `end <track> <ticks>` en lecture
pilotée au tick (vérifié, ce n'était pas acquis — l'autre usage connu était le `dump`), tapé dans
`siren-clip-loader` derrière un `spigot` armé par le mode.

**`mute` reste volontairement mappé sur JOUE** — le comportement moteur exact (coupé ou rotation à
vide) est toujours la décision non tranchée de `SCENES_SPEC.md §8`.

**Manque identifié, non traité** : rien ne fait reboucler un clip en `play`. `midifile` émet `end`
et s'arrête ; l'état reste JOUE mais plus rien ne sort. Le rebouclage (via `rotate`/le compteur de
mesures) reste à construire.

## 5bis. Intégration dans le nouveau système — plan

- **Réutiliser** : le concept mainloop-relatif, le pattern `waitBar` (adapté pour lire le `bar` de
  notre `midiclock.pd`, déjà construit et qui sort déjà un signal `bar` séparé du `pulse`).
- **Reconstruire** :
  - Le buffer d'état par sirène (remplace `\$1.loop.definition`) — à concevoir pour vivre
    naturellement dans notre modèle de scène JSON existant (`sirens[].mode` porte déjà
    `play`/`mute`/`oneshot`/`empty` — probablement à étendre, pas à dupliquer).
  - Le bypass "démarrage immédiat sans mainloop" — absent/mort dans l'ancien système.
  - La génération d'un `clipId` pour un enregistrement déclenché au pied (distinct des clips
    pré-composés d'une scène — probablement horodaté, à l'ancienne convention `clip_<timestamp>`
    déjà vue dans le dépôt).

## 6. Questions encore ouvertes (ne pas deviner, demander à Patrice)

1. Mécanique exacte de détection "mainloop existe déjà" côté nouveau système (voir §3 — le rejet
   de "midiclock transport" est acté, mais le remplacement précis reste à concevoir).
2. Quand une boucle plus longue **devient** la nouvelle mainloop : est-ce que ça décale/redéfinit
   la mesure pour les autres sirènes déjà en lecture ? Comment gérer la discontinuité ?
3. Format de persistance exact de l'état par sirène dans la scène sauvegardée (extension du champ
   `mode`, ou nouveau bloc dédié dans le JSON de scène ?).
4. Détail exact du décompte (combien de temps/mesures, visuel et/ou sonore, où est-ce affiché ?) —
   défaut retenu pour démarrer la construction : **1 mesure**, ajustable plus tard.
5. Quand une boucle plus longue **devient** la nouvelle mainloop : est-ce que ça décale/redéfinit
   la mesure pour les autres sirènes déjà en lecture ? Noté comme cas limite à traiter plus tard,
   pas bloquant pour démarrer (chaque `clip-io` boucle déjà sur sa propre longueur indépendamment).

**Résolu** : rec/play attend toujours le début de mesure — y compris le tout premier enregistrement
(via décompte), sauf la transition ARRÊTÉ→JOUE qui est immédiate (seule exception). La longueur
d'enregistrement se cale en puissance de 2 relative à la mainloop. `stop` (pédale distincte) est
toujours immédiat, jamais quantizé, y compris pendant un enregistrement — **et garde le clip
partiel capturé** (transition vers ARRÊTÉ, pas VIDE ; rejouable tel quel).
