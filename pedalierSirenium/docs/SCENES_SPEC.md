# Cahier des charges — Scènes, clips et compositions (côté PureData)

Ce document définit ce que PureData doit produire et stocker pour les scènes. Il est le contrat
entre le patch (que Patrice code) et l'afficheur QML (qui le lit). Décisions arrêtées le 2026-07-16.

Voir aussi [`PEDALIER_MAPPING.md`](PEDALIER_MAPPING.md) pour les contrôleurs physiques.

---

## 1. Le modèle : trois niveaux

```
Composition  (un morceau)          ── change par le grand pédalier (CC 61-91)
  └─ Scène   (une section)         ── choisie par le petit pédalier (CC 51-58) + banque
       └─ 7 cellules (une par sirène) = (clipRef, mode)
            └─ Clip  (matériel nu) ── boucle enregistrée, dans le pool
```

Trois faits qui définissent tout :

- **Un clip est du matériel nu.** `loop.N.txt` + ses propriétés intrinsèques (taille, rapport de
  boucle, statut de référence). **Aucun mode de lecture dedans** — c'est le changement par rapport
  au stockage actuel, où `loop.definition.txt` mêle matériel et état.
- **Une scène est une couche.** 7 cellules, chacune disant *quel clip* et *dans quel mode*. La scène
  ne copie pas le matériel, elle le référence.
- **Une composition est une suite ordonnée de scènes**, plus son propre matériel (le pool de clips
  du morceau).

## 2. Le partage des clips — pool référencé

**Décision : pool de clips, référencé par les scènes** (modèle Live). Une cellule de scène pointe
vers un clip du pool par `clipRef`. Plusieurs scènes peuvent référencer le même clip avec des modes
différents — S3 en `play` dans « montée », en `mute` dans « creux », un seul matériel.

- **Conséquence assumée** : réenregistrer un clip partagé le modifie dans **toutes** les scènes qui
  le référencent. C'est le comportement de Live, et c'est voulu.
- **Dégradation naturelle** : si une sirène n'a qu'un clip sur tout le morceau, le modèle se réduit
  à « 7 clips fixes + rangées de modes ». Rien à prévoir de spécial.
- **Déjà en place** : le stockage sépare déjà les clips en dossiers (`looper.scenes/clip_XXX/`).
  Le pool existe ; ce qui change est la structure de la scène (7 `(clipRef, mode)` au lieu d'un
  `clipRef` unique).

## 3. Les cinq modes de lecture

| Mode | Son | Boucle | Moteur | Notes |
|---|---|---|---|---|
| **play** | oui | oui | tourne | lecture normale, en boucle |
| **stop** | non | remise au début | *à confirmer* | **pas de gel sur place** (fonction repoussée) ; la boucle repart de zéro au prochain lancement |
| **mute** | non | continue d'avancer | parqué (ghost note) | le clip avance en interne (phase) mais **n'émet plus de notes** ; une ghost note à la limite basse de l'ambitus parque le moteur (voir §3bis). Unmute = latence de spin-up |
| **solo** | oui | oui | tourne | **réduit au silence les autres sirènes** ; solo classique |
| **oneshot** | oui, une fois | non | tourne puis s'arrête | passe une fois, puis état « joué » |

### Le moteur est une dimension à part entière

Silencier une sirène = **arrêter son moteur** (décidé pour le solo : les non-solo se taisent moteur
coupé). Une sirène mécanique ne se tait pas instantanément — le rotor décélère, et remonte en
vitesse au retour. Donc :

- un changement de mode a une **durée** (spin-down / spin-up), pas une bascule nette ;
- cette durée est une information que **l'écran** doit porter (les LEDs ne rendent pas le transitoire) ;
- elle se lit déjà dans les RPM (`revolutionCount`) que le patch envoie.

Reste `stop` : son comportement moteur n'est pas encore tranché.

## 3bis. La ghost note — primitive de positionnement du moteur

**Concept fondamental des sirènes, réutilisé pour plusieurs choses** (mute, démarrage de clip,
sortie de mute, rotation…). À ne pas traiter comme un détail du mode `mute`.

Une **ghost note** est une note on de **vélocité 1** (0 restant le note off, convention PureData).
Sa propriété centrale : elle **positionne le moteur immédiatement, sans portamento** — la sirène
saute à la vitesse cible au lieu d'y glisser. Deux usages symétriques :

- **Parquer** : une ghost note à une hauteur très basse ramène le moteur vers une vitesse presque
  nulle. **Immédiat** (contrairement à un note off, qui laisse le rotor traîner) et **sans
  réinitialiser les contrôleurs** (contrairement à un `reset`, qui remet à zéro vibrato, trémolo,
  enveloppe…). C'est ce qui la rend préférable aux deux alternatives pour immobiliser une sirène.
- **Relancer** : une ghost note à une hauteur cible amène le moteur à cette vitesse instantanément —
  pour pré-positionner le rotor au démarrage d'un clip, à la sortie du mute, ou pour la rotation,
  avant que les vraies notes (avec portamento) prennent le relais.

**Hauteur de parking = une octave sous la limite basse de l'ambitus, pas zéro absolu.** On lit
`notemin` de la sirène dans `sirenspec` (`text define $0sirenspec` dans `pd sirenspec`, champs
`notemin`/`notemax` par sirène S1–S7) et on parque à `notemin - 12`. Rester *à* `notemin` ne suffit
pas : c'est la note la plus grave que la sirène sait **jouer**, donc encore audible (corrigé le
2026-07-25). Une octave dessous, le rotor tourne sans sonner.

C'est un compromis assumé : plus bas = plus silencieux, mais **spin-up plus long** au retour. Une
octave est le choix retenu ; parquer à zéro rallongerait le spin-up sans rien gagner en silence.

PD transmet la vélocité 1 telle quelle — c'est `composeSiren`, côté sirène, qui l'interprète comme
une commande de positionnement sans portamento. PD reste routeur.

Prérequis réglé côté décodage (`midi-status-decode`) : le **note off** (status 8) sort désormais en
vélocité 0 (il sortait avec la vélocité brute du fichier, indistinguable d'un note on). Les trois cas
se distinguent ainsi nettement — note on (vél 1-127), ghost (vél 1), note off (vél 0).

**État d'implémentation (2026-07-22)** : décodage note off→0 fait. `mute` **corrigé** : la sortie de
notes du clip est coupée par un gate (le clip continue d'avancer pour la phase) et une **seule ghost
note à `notemin - 12`** (vél 1, sur la voix de la sirène) parque le moteur à l'entrée en mute.
Vérifié le 2026-07-22, quand la hauteur était encore `notemin` : scène en `mute` → une seule
`note 43 1 <voix>` pour S1, plus aucune note du clip. Le `[- 12]` ajouté depuis attend une
re-vérification sur le matériel — elle devrait donner `note 31 1 <voix>` pour S1.

`notemin` est **lu au runtime dans `sirenspec`** (pas d'argument codé en dur) : `siren-clip-loader`
construit le libellé `S<index+1>` (`makefilename S%d`) et interroge le buffer du parent via
`text search $3sirenspec 0 1` avec le message `list S<n> notemin`, puis `text get` pour extraire la
valeur. Ainsi une modification de `sirenspec` est prise en compte sans toucher au patch.

**Syntaxe `text search` (piège vérifié)** : l'objet s'initialise avec les **numéros de colonnes** où
il cherche (`text search <buf> 0 1` = colonnes 0 et 1), et on lui envoie les valeurs à trouver **sous
forme de liste** (`list S3 notemin`, pas un message générique `S3 notemin` — sinon « no method for
S3 »). Il sort le **numéro de ligne** de la première occurrence, ou **-1** si rien ne correspond ;
`text get` récupère alors la ligne.

Reste à construire, primitive « relancer » : pré-positionner le moteur à la hauteur cible (ghost note)
au démarrage d'un clip et à la sortie du mute, avant les vraies notes à portamento.

## 4. Navigation / lecture

- Choisir une scène (petit pédalier, bouton + banque) **applique les 7 cellules** : charge le
  matériel référencé et met chaque sirène dans son mode.
- **Ordre des scènes = ordre des boutons** : 4 en haut, 4 en bas, de gauche à droite puis de haut en
  bas. `order` suit ce parcours ; il est donc dérivable du bouton, pas besoin d'un champ séparé.
  *(Corriger côté QML : `SceneGrid` numérote aujourd'hui le bas 1-4 et le haut 5-8, à inverser.)*
- **Banque** : `changeScenePage` prolonge la carte au-delà de 8 sections. Une composition n'a pas
  forcément 8 banques.

## 5. Enregistrement et persistance

- Enregistrer une boucle sur une sirène (CC 25 rec/play) crée un **clip** dans le pool.
- Le clip est **inscrit immédiatement dans la scène courante** (cellule de cette sirène = ce clip,
  mode `play`).
- **La permanence demande de sauver le morceau.** Tant que la composition n'est pas enregistrée,
  l'état courant diffère du disque → **état « modifié / non enregistré »**, que l'écran doit
  signaler discrètement.
- **À définir** : le rôle du geste `clip write` (CC 19) si l'inscription est déjà automatique —
  peut-être « figer » un clip, ou l'écrire nommément dans le pool.

## 6. Le contrat vers l'écran — `scenesList` enrichi

C'est la seule chose que l'afficheur attend. Aujourd'hui `saveScene` ne route que
`globalSceneId sceneId page sceneName` ; il faut y ajouter, **par scène, l'état des 7 sirènes**.

```json
{
  "device": "LOOPER_SCENES",
  "batch": "scenesList",
  "composition": { "id": 12, "name": "Vertiges", "banks": 3 },
  "scenes": [
    {
      "globalSceneId": 1, "page": 1, "sceneId": 1,
      "sceneName": "intro", "order": 1,
      "tempo": 120,
      "signature": "4/4",
      "harmony": {
        "scaleMode": "dorien",
        "root": "C",
        "voicing": "poly"
      },
      "sirens": [
        { "siren": 1, "mode": "play",    "clipRef": "clip_2025843444" },
        { "siren": 2, "mode": "empty",   "clipRef": null },
        { "siren": 3, "mode": "oneshot", "clipRef": "clip_2025843457" },
        { "siren": 4, "mode": "mute",    "clipRef": "clip_202584353"  },
        { "siren": 5, "mode": "solo",    "clipRef": "clip_2025843510" },
        { "siren": 6, "mode": "stop",    "clipRef": "clip_2025843529" },
        { "siren": 7, "mode": "play",    "clipRef": "clip_2025843536" }
      ]
    }
  ]
}
```

- `mode` ∈ `play | stop | mute | solo | oneshot | empty`. `empty` = pas de clip sur cette sirène
  dans cette scène.
- `clipRef` : nom du dossier clip, ou `null` si vide. Permet à l'écran de repérer les clips partagés
  entre scènes plus tard.
- `composition.banks` : nombre de banques du morceau (l'écran adapte l'affichage).

### L'harmonisation appartient à la scène

Chaque scène porte son état harmonique complet. Bloc `harmony` :

```json
"harmony": {
  "scaleMode": "dorien",
  "root": "C",
  "polyphony": "poly",
  "voicing": [
    { "siren": 3, "degree": 0 },
    { "siren": 4, "degree": 2 },
    { "siren": 1, "degree": 4 }
  ]
}
```

- `scaleMode` : **gamme + mode musical** (ex. `dorien` = 2ᵉ degré du majeur). La couleur.
- `root` : la **tonalité**, sur un **axe indépendant** du mode — on transpose sans changer la
  couleur, et inversement.
- `polyphony` : `poly` (l'harmoniseur répartit une ligne sur plusieurs sirènes) ou `mono` (une
  sirène). *(C'est le « mode » poly/mono ; ne pas confondre avec `scaleMode`, le mode musical.)*
- `voicing` : l'**accord posé**. Chaque entrée = une sirène **éligible** et son intervalle en degrés
  de gamme. Les sirènes absentes de la liste ne sont pas recrutées par l'harmoniseur.

Ainsi une scène = clips + modes de lecture + couleur harmonique + tonalité + accord :
**l'état complet de l'instrument**. Naviguer d'une section à l'autre fait tout défiler ensemble.

### Poser l'accord — au pied

Mécanique arrêtée le **2026-07-25**. Elle remplace la version antérieure, où le clavier
sélectionnait les sirènes et où l'accord se répartissait par hauteur.

- **Sélection des sirènes** : les 8 boutons ronds, **pas** le clavier. En mode poly (pédale 19 active),
  les appuis **cumulent** les sirènes en jeu au lieu de remplacer la sélection.
- **Réglage du voicing** : le clavier donne l'**intervalle de la dernière sirène ajoutée**. On
  construit donc l'accord voix par voix — ajouter une sirène, jouer sa touche, recommencer. Le
  clavier étant libéré de la sélection, c'est une octave chromatique complète.
- **Répartition** : l'intervalle est attribué **explicitement** à une sirène, et c'est une **classe**
  (mod 12) ; l'**octave où il sonne vient de l'ambitus de la sirène** (`sirenSpec`), pas de l'accord.
  Une quinte posée sur S3 sonne donc environ deux octaves sous la même quinte posée sur S7. L'ancienne
  règle « la note la plus grave va sur la sirène la plus grave » devient inutile : l'ordre des
  registres est garanti par les ambitus, quel que soit l'intervalle attribué.
- **Choisir les sirènes, c'est choisir le voicing.** L'écart entre les voix ne se règle pas
  séparément : il découle de quelles sirènes sont dans l'accord.

**Reste à écrire : quelle octave dans l'ambitus.** Les ambitus se chevauchent de près de trois
octaves (S1 43-86, S5 48-94), donc « replier dans l'ambitus » ne désigne pas encore une hauteur
unique — la quinte sur S3 existe à 43, 55 et 67. Deux candidats : « le plus grave possible », qui
donne bien les deux octaves d'écart attendues entre S3 et S7 mais colle l'accord en bas en
permanence ; ou « l'octave la plus proche de la note courante de la fondamentale, puis repli », qui
laisse l'accord suivre la ligne. Chiffres et question `transpo` dans `PEDALIER_MAPPING.md`.
- Réglable aussi sur l'**écran tactile** (précis, posé) — les deux écrivent le même `voicing` de la
  scène courante.

Deux états **orthogonaux** par sirène, à distinguer à l'écran : son **éligibilité** (dans l'accord
ou écartée) et son **activité** (ligne / voix d'accord / clip / libre).

Messages temps réel déjà en place à conserver : `sceneLoaded` (met à jour la scène active),
`sceneSaved`. À ajouter : un signal d'**état modifié** (`{ "composition": { "dirty": true } }` ou
équivalent) pour l'indicateur non-enregistré.

## 7. Correspondance avec le stockage actuel

| Aujourd'hui | Cible |
|---|---|
| `looper.scenes.txt` : `sceneId globalId page nom clipRef` (un clip) | `sceneId globalId page nom` + 7 × `(siren, clipRef, mode)` |
| `loop.definition.txt` : matériel **et** état (isLoop, playing, loopSize) mêlés, `tempo` par clip | Clip = matériel + propriétés intrinsèques ; **mode et tempo sortis dans la scène** (§16) |
| `saveScene` route 4 champs | route 4 champs + l'état des 7 sirènes |
| `clip_XXX/` en pool (déjà le cas) | inchangé — le pool existe déjà |

Le `mainLoop` et le champ de rapport de `loopSize` (dernier nombre de `loopSize 0 3 16 0 4`) sont
déjà écrits : ils alimentent le second cercle « référence » et l'échelle des paliers de l'écran.

## 8. Décisions restantes

- Comportement moteur exact de `stop` et `mute` (coupé ou rotation à vide → latence de reprise).
- Rôle de `clip write` (CC 19) si l'inscription en scène est automatique.
- Forme exacte du signal « modifié / non enregistré ».

---

## 9. Le recorder passe en amont de l'harmoniseur

**Problème identifié (2026-07-17)** : le recorder est aujourd'hui placé **après** l'harmoniseur — il
capture la sortie déjà voicée, pas la ligne d'origine. Un clip enregistré fige donc l'harmonie du
moment ; la rejouer avec une autre gamme, une autre tonalité ou un autre tempo est impossible sans
tout ré-enregistrer. Coût de développement constaté : énorme.

**Solution retenue** : enregistrer **en amont** de l'harmoniseur — la ligne brute du Sirénium,
horodatée en **temps musical fin** (frames/ticks MIDI, plus précis qu'une quantification
mesure/temps — préserve le geste exact plutôt que de l'arrondir à la grille). L'harmonie ne se
stocke jamais dans le clip ; elle est **réappliquée à la lecture**, à partir du bloc `harmony` de la
scène courante (§6). C'est une **conséquence nécessaire**, pas seulement cohérente, du fait déjà
acté que l'harmonie vit dans la scène (§1, §6) : il n'existe nulle part ailleurs dans le modèle où
une version « déjà harmonisée » pourrait légitimement se stocker.

**Conséquence sur l'harmoniseur** : il doit être **recâblé pour recevoir plusieurs entrées** — la
ligne du Sirénium en direct, et une ou plusieurs lignes brutes rejouées (depuis un clip ou un projet
MIDI, voir §11) — et **arbitrer une priorité** entre elles quand elles se disputent les mêmes
sirènes. C'est structurellement le même problème que le champ `source` (`docs/PD_WORK.md §3`,
« le dernier joué prime »), mais un cran plus tôt : pas *quelle sirène joue quoi*, mais *quelle
entrée alimente l'harmoniseur*. **Non tranché** : est-ce la même règle de priorité, ou une autre ?

## 10. Modèle actuel de l'harmoniseur — et une piste d'évolution

**Modèle actuel (confirmé par Patrice)** : pas un accord assigné dynamiquement. Chaque sirène
activée a son propre réglage d'**intervalle fixe**. La note du Sirénium se diffuse en broadcast vers
les sirènes activées (1 → [1..7]), chacune appliquant son intervalle propre pour produire sa voix.

**Piste évoquée, non décidée** : remplacer (ou compléter) l'intervalle fixe par une assignation
dynamique par **proximité de hauteur** — le degré d'un accord va chercher la sirène dont l'ambitus
est le plus proche, plutôt que d'être câblé sur une sirène pré-réglée. C'est une logique de
voice-leading (minimiser les sauts), différente du modèle actuel. Intéressant, à creuser plus tard —
pas une décision.

## 11. Sources de clip — enregistrement live et extraction de projets MIDI

Le pédalier devra aussi **lire des projets MIDI** (type Reaper), pour deux usages qui partagent le
même pipeline que l'enregistrement live (§9) — une ligne brute traverse l'harmoniseur, appliqué
**après**, séparément :

- **Réinterprétation** : une ligne écrite dans un projet MIDI traverse le pédalier *comme si* le
  Sirénium la jouait — geste **live**, pas seulement en préparation.
- **Extraction en clip** : la même ligne, capturée dans le pool de clips — même représentation
  qu'un clip enregistré en live (brute, sans harmonie).

Ces deux usages sont probablement **le même geste** : la ligne traverse le pipeline live, et le
geste `clip write` (CC 19, §5) la capture optionnellement en clip. Cohérent avec tout ce qui
précède ; à confirmer explicitement avant de patcher.

**Structurer les fichiers sources avec des markers MIDI** — l'événement standard *Marker*
(meta-event SMF, exportable nativement depuis Reaper), pas un format inventé. Un marker porte :

- un **point de déclenchement** (début, possiblement fin/bouclage) ;
- un **nom**.

Pas besoin d'y coder l'harmonie, le tempo ou la signature — déjà gérés ailleurs dans le modèle
(tous trois dans la scène, §16). **Non tranché** : un marker SMF standard est **global à la
timeline**, pas attaché à une piste. Si un projet contient plusieurs pistes candidates au même
marker, une convention de désambiguïsation (nommage dans le texte du marker, ou autre) reste à
définir.

## 12. Stockage du clip — fichier MIDI standard

**Idée retenue** : stocker un clip comme un vrai fichier `.mid` plutôt que le format texte
`loop.N.txt` actuel.

**Cohérent, pas juste plausible** : puisque l'harmonie vit dans la scène (§1, §6, §9), le clip ne
peut être que la ligne brute mono — exactement ce qu'une piste MIDI standard encode (note on/off,
ticks/PPQN = temps musical). Unifie enregistrement live et extraction MIDI (§11) dans un seul
format de stockage, dans les deux sens (lecture et écriture).

**Renforce l'intérêt d'un external PD dédié** à cette partie précise (enregistrement des clips
organisés en scènes, intention de Patrice) : lire/écrire du SMF standard en C est un problème bien
balisé (bibliothèques existantes), contrairement aux objets `text`/`sequence` de PD, natifs au
format texte à plat.

## 13. Recentrage du périmètre du patch pédalier

**Contexte** : un VST (évolution récente de ComposeSiren) route désormais le MIDI reçu directement
vers les sirènes en UDP — un chemin DAW → sirènes qui n'a plus besoin de PD. Le patch du pédalier
n'a donc plus vocation à « tout savoir faire » (Mac, pédalier, machine Linux lisant des projets
Reaper) : ComposeSiren couvre le rendu direct d'un DAW.

**Rôle précisé du patch pédalier** : le moteur temps réel de l'instrument live — enregistrer, jouer,
harmoniser, naviguer dans les scènes ; parler aux 5 appareils physiques (`PEDALIER_MAPPING.md`) et
au contrat JSON (`PD_WORK.md`) qui alimente l'écran. Rien d'autre.

**Test de nettoyage** (à appliquer patch par patch, lors du grand nettoyage prévu) : *est-ce que
cette partie sert à faire tourner le pédalier comme instrument vivant, ou était-ce pour un autre
contexte (Mac, machine Reaper, expérience passée) ?* Si non : candidat à sortir, pas à documenter.

La lecture de projets MIDI (§11) **reste dans le périmètre** — pas comme lecteur DAW générique
(ça, c'est ComposeSiren), mais comme **source de matériau** pour le pipeline live du pédalier
(réinterprétation, extraction en clip).

## 14. Nouvelles décisions ouvertes (2026-07-17)

- Priorité d'arbitrage à l'**entrée** de l'harmoniseur (Sirénium live vs ligne rejouée) — même règle
  que « le dernier joué prime » (§9, `PD_WORK.md §3`), ou une autre ?
- Réinterprétation et extraction en clip : confirmer que c'est bien le même geste (§11).
- Désambiguïsation des markers MIDI si plusieurs pistes candidates au même point (§11).
- Périmètre exact du grand nettoyage du patch (§13) — à mener avec le test proposé, résultat non
  connu à l'avance.

## 15. Réserve pour une 8ème sirène (décidé 2026-07-17, pas encore implémenté)

Un 8ème instrument pourrait rejoindre l'orchestre l'année prochaine. Décision : **concevoir pour 8,
peupler 7** — ne pas fermer la porte en codant "7" en dur comme une vérité permanente.

Endroits identifiés où "7" est actuellement une constante de conception, à revoir quand ce travail
reprendra : `sirenSpec.js` (7 entrées), les boucles et tableaux à 7 dans `LiveState`/
`SimulationHarness` (QML), `SirenRingRow2D`/`ModulationMatrix2D` (`model: 7`), le contrat
`sirens[]` de `scenesList` (§6), l'ordre de hauteur `S3 S4 S1 S2 S5 S6 S7` (mémoire
`siren-pitch-order` — où s'insère S8 dépend de son ambitus, inconnu).

**Non résolu** : quel contrôle physique du pédalier devient le sélecteur de S8 — un 8ème
emplacement matériel déjà câblé, ou une des 5 touches dièses libres du clavier PK-6
(`PEDALIER_MAPPING.md`) ? À trancher avant d'implémenter quoi que ce soit.

## 16. Tempo et signature — propriétés de la scène (décidé 2026-07-19)

**Décision : tempo et signature suivent exactement le même modèle que l'harmonie (§1, §6, §9) —
ils vivent dans la scène, jamais dans le clip.** Ça règle l'ambiguïté du §11, qui parlait d'un
« tempo dynamique côté écran/PD » comme si le tempo n'était pas stocké en scène ; en réalité les
deux ne s'opposent pas :

- **Valeur de départ par scène**, avec un **défaut à 120** (comme n'importe quel DAW) si rien n'est
  réglé.
- **Ajustable en live par-dessus**, pendant la lecture — même logique que le reste de l'état
  courant (harmonie, modes des 7 cellules).
- **Sauvegarder la scène sauve tout**, y compris le tempo et la signature ajustés en live — aucun
  traitement spécial par rapport aux autres champs de l'état de la scène (§5).

**Conséquence sur le stockage** : le `tempo` aujourd'hui écrit dans `loop.definition.txt` (par
clip) est le même genre de résidu que `isLoop`/`playing` déjà identifiés en §7 — il migre vers la
scène. Le contrat `scenesList` (§6) porte donc `tempo` et `signature` au même niveau que `harmony`,
par scène.

**Format de `signature`** : chaîne `"battements/division"` (ex. `"4/4"`, `"7/8"`), cohérent avec
`PD_WORK.md` et le message `clock` déjà en place côté WebSocket — pas un objet `{num, den}` séparé.

## 17. Grain d'horloge et décimation du bend (décidé 2026-07-21)

**Deux grains, pas un.** Le patch fait cohabiter deux résolutions temporelles, et c'est délibéré :

- **Placement des événements : 480 ticks/noire.** C'est la résolution des fichiers `.mid`
  (`clip-io` écrit `write <path> 480`) et donc celle à laquelle `midifile` avance. `midiclock`
  fournit ce grain fin par un diviseur **asservi aux tops 24 ppq reçus** (mesure de période par
  `timer`, 20 sous-ticks par top), et non par un metro calculé depuis le tempo affiché — sans quoi
  toute synchronisation sur une horloge MIDI externe (`source 1`) dériverait.
- **Contenu continu : 24 pulses/noire.** Le pitch bend et les contrôleurs de modulation sont
  décimés sur la grille de l'horloge MIDI, soit 48 valeurs/s à 120 bpm.

**Pourquoi cette asymétrie** : ce qui est transitoire (l'attaque d'une note) mérite la précision ;
ce qui est continu ne l'exploite pas, parce que **l'inertie mécanique des sirènes ne peut pas
restituer plus vite**. Un bend à chaque tick de 480 ppq, ce serait 480 messages/noire et par sirène,
soit 6 720 messages UDP/s pour les sept à 120 bpm — pour une différence inaudible. À 24 ppq on
tombe à 336/s.

**Le facteur limitant est le débit sortant, pas la mémoire.** Mesuré : `midifile` alloue exactement
la taille de la piste SMF (`getbytes(chunk_length)`) et y garde les octets bruts, sans expansion.
Un clip volontairement délirant (un bend à *chaque* tick de 480 ppq sur 4 mesures, 7 681 événements,
30 Ko de piste) chargé dans les 7 `clip-io` ne coûte que **+224 Ko de RSS** — conforme aux 215 Ko
de données attendus. Même extrapolé à un morceau de 10 minutes à ce régime, on reste sous 20 Mo.
La mémoire n'est jamais la contrainte ; le réseau et le firmware Artila le sont.

**Règle** : le grain fin sert à *placer* les événements, pas à en *créer*.

**Implémentation de la décimation** (à faire avec le recorder, pas encore construit) : échantillonner
sur la grille 24 ppq — garder la dernière valeur à chaque top — plutôt que de déclencher sur un
seuil de variation, sinon un bend lent ne produit rien pendant longtemps puis saute. Ajouter un
`[change]` derrière pour ne pas réémettre une valeur identique : grille régulière, sans redondance.

## 18. Énumérer scènes et compositions — `[file glob]`, pas un index écrit (2026-07-21)

**Pd vanilla sait lister un dossier** depuis 0.52, avec `[file glob]` (le sous-objet se choisit à la
création : `[file]` seul instancie `file handle`, qui n'a pas la méthode). Vérifié sur le dépôt réel :

```
[symbol <compdir>/scenes/*.json( -> [file glob] -> .../scenes/1.json 0
                                                   .../scenes/2.json 0
[symbol <root>/pedalier.compositions/*(            .../pedalier.compositions/12 1
```

La sortie est `<chemin> <isdirectory>` — 0 pour un fichier, 1 pour un dossier, ce qui permet de
lister les compositions (dossiers) comme les scènes (fichiers).

**Conséquence : aucun index de scènes n'est à écrire.** Ni tableau `scenes` ajouté à
`composition.json`, ni fusion des scènes en un fichier unique. On énumère à la volée, donc pas de
redondance à maintenir en cohérence avec les fichiers réellement présents. `composition.json` garde
sa forme actuelle (`id`, `name`, `banks`). Utiliser `[file splitname]`/`[file splitext]` pour
retrouver le `sceneId` depuis le nom de fichier.

## 19. « Pêcher » des parties d'une autre composition (anticipé, pas implémenté)

Intention annoncée par Patrice le 2026-07-21, à construire en fin de niveau composition : pouvoir
**aller chercher des parties d'une composition existante pour les injecter dans le projet en cours**
(une scène, un ensemble de scènes, ou du matériel).

Ce n'est pas seulement une fonctionnalité future — ça contraint une décision présente :

- Un `clipRef` est résolu **relativement au `clips/` de la composition ouverte** (`composition-io`
  sort ce dossier sur son outlet 2). Une scène importée référence donc des clips qui n'existent pas
  dans la composition d'accueil.
- **Rien ne garantit l'unicité des noms de clips entre compositions** — `clip_A` peut exister dans
  les deux, avec des contenus différents. Une copie naïve écraserait ou détournerait silencieusement.

Deux directions possibles, à trancher avant d'écrire l'import : **copier les clips référencés** dans
le pool d'accueil en renommant en cas de collision (`[file copy]` existe en vanilla, et la scène
importée doit alors être réécrite avec les nouveaux noms) ; ou **rendre les identifiants de clips
globalement uniques** dès l'enregistrement (horodatage, comme l'ancienne convention
`clip_<timestamp>` déjà vue dans le dépôt), auquel cas la copie est sans risque et la référence
reste valable telle quelle.

**Tranché le 2026-07-21, et implémenté** (`composition-io`, message `fetch`) :

- **On pêche un clip, pas une scène.** `fetch <compoSrc> <sceneSrc> <sirène>` va chercher le clip
  posé sur cette sirène dans une scène d'une autre composition.
- **Il se pose sur la sirène correspondante**, jamais sur une autre : un clip enregistré sur S3 l'a
  été dans l'ambitus de S3, le déplacer le ferait sonner faux. Un seul index de sirène suffit donc
  au message.
- **Copie dans le pool d'accueil, renommage seulement en cas de collision**, avec un suffixe égal à
  l'id de la composition source (`clip_A` venu de la compo 7 → `clip_A-7`). Déterministe et
  traçable, et repêcher le même clip ne le duplique pas puisqu'il retombe sur le même nom.
- Le clip arrive en `mode: play`.

La composition d'accueil reste donc autonome et transportable, et les noms restent lisibles tant
qu'il n'y a pas de conflit.

---

## 20. Le contrat depuis l'écran — éditer les scènes (implémenté 2026-07-31)

Sens inverse du §6 : l'écran tactile écrit, PureData exécute. Entrée par
`pd looperScenes.get` (chaîné derrière `composeSiren.get` dans `pd websocket`), qui traduit vers
`sceneEdit` sur `composition-io`. Les cinq commandes d'édition passent par `compdir-guard` : sans
composition ouverte, elles ne font rien.

```json
{"device":"LOOPER_SCENES","action":"sceneNew"}
{"device":"LOOPER_SCENES","action":"sceneLoad","n":3}
{"device":"LOOPER_SCENES","action":"sceneDelete","n":3}
{"device":"LOOPER_SCENES","action":"sceneRename","n":3,"name":"refrain"}
{"device":"LOOPER_SCENES","action":"sceneCopy","src":2,"dst":5}
{"device":"LOOPER_SCENES","action":"sceneCellCopy","src":2,"dst":5,"siren":3}
```

- `n`, `src`, `dst` sont des **positions de scène** (1..N), pas des numéros de bouton : `sceneId` et
  `page` en sont dérivés côté PD (`((pos-1)%8)+1` et `floor((pos-1)/8)+1`).
- **Supprimer décale les suivantes** (décidé 2026-07-31). Les fichiers sont réécrits *et*
  renumérotés dans leur contenu — `order`, `sceneId`, `page`, `globalSceneId`. Conséquence assumée :
  toutes les scènes après la suppression **changent de bouton**, donc le pied ne les retrouve plus
  au même endroit. C'est le prix de « pas de trou dans la timeline ».
- `sceneLoad` ne va pas à `composition-io` mais à `$0.scene.select`, qui met aussi à jour
  `$0.looper.scene.id` — le même chemin que les boutons du petit boîtier.
- **Les espaces dans un nom passent** (« partie A ») : vérifié de bout en bout, pdjson → buffer
  `text` → message → fichier → retour dans `scenesList`. Aucune substitution à faire ;
  `WebSocketController.sceneRename` se contente d'un `trim`.
- Une scène neuve n'écrit **pas** `signature` : `"4 4"` fait deux atomes, `setB` n'en prend qu'un.
  Elle hérite donc de la signature courante. `tempo` est écrit (120).
- Après chaque édition, PD republie `scenesList` tout seul (`$0.scenes.refresh`) — l'écran n'a rien
  à redemander.

Le mapping bouton→scène reste **positionnel** : les scènes occupent les N premières positions, comme
les compositions occupent les N premiers boutons du gros boîtier (voir `PEDALIER_MAPPING.md`).

## 21. L'état vit dans des buffers texte

Trois tables portent l'état de `composition-io`. Aucune n'est écrite sur disque : ce sont des
projections en mémoire, ce qui ne contredit pas le §18.

### `$0-scenes` — la carte du morceau

Une ligne par scène, dans l'ordre du morceau ; **la position est le numéro de ligne**, `order`,
`sceneId` et `page` s'en déduisent. La ligne porte les 14 atomes des cellules : champ `2j` = mode
de la sirène `j`, champ `2j+1` = son clipRef.

Le nom de scène n'y est pas : c'est la seule valeur qui peut contenir des espaces, donc la seule
qui interdise « la valeur est le dernier atome ». Aucun verbe ne le lit ; il vit dans les fichiers
et dans le payload `scenesList`.

**Les verbes d'édition ne l'écrivent jamais.** Ils le lisent, écrivent le fichier, et déclenchent
`$0.scenes.refresh` qui le reconstruit — une seule direction, donc pas de divergence possible avec
le disque. `pd open` déclenche aussi un refresh en fin d'ouverture, pour que le buffer soit prêt
avant toute commande. `pd new` et `pd delete` lisent `[text size $0-scenes]` ; `pd cell` lit la
cellule source avec `[text get $0-scenes]`.

### `$0-champs` — la disposition de la ligne, écrite une fois

`[text define -k $0-champs]`, une ligne par champ dans l'ordre : `0 mode`, `0 clipRef`, … `6
clipRef` — sirène 0-based et clé, telles que `dump` les émet. **Le numéro de ligne est le numéro de
champ.** `pd champ` y cherche le chemin reçu, `pd cell` y cherche `<j> mode` ; la disposition n'est
donc décrite qu'à un endroit, et comme donnée ouvrable. Le `-k` la fait vivre dans le fichier du
patch : ni `loadbang` ni message pour la remplir.

Deux points de mécanique à ne pas défaire :

- `pd champ` filtre sur `sirens` **avant** la recherche. Sans ce filtre, `text search` avec deux
  champs déclarés crie sur les clés plus courtes (`tempo`, `harmony root`).
- Un `[spigot]` piloté par `[>= 0]` garde l'écriture. Le silence de la recherche ne filtre que la
  branche du champ ; la branche de la valeur, elle, part quand même et `text set` écrirait au
  dernier champ connu.

### `$0-dirs` — le dossier courant

Deux lignes, `racine <chemin>` et `compo <chemin>`, écrites par `pd dirs` sur `$0.setdir` et
`$0.compdir-set`. Tout le patch y accède par une abstraction :

```
[dir-prefix <$0 du parent> <racine|compo>]
```

Elle préfixe son entrée avec le dossier demandé ; un bang rend le dossier seul. Tant qu'aucune
composition n'est ouverte, la ligne `compo` n'existe pas et `dir-prefix` ne rend rien — ce qui vaut
mieux que de construire `/scenes/scene_N.json` à la racine du disque. `compdir-guard` reste
par-dessus et garde les cinq commandes d'édition.

### Remplir les buffers : `[scenes-scan]`

`[scenes-scan <dossier de composition>]` énumère `scenes/scene_*.json` et en sort le contenu champ
par champ : à gauche `<i> <chemin...> <valeur>`, au milieu l'index de la scène (juste avant son
premier champ), à droite « fini ». Elle porte son propre `pdjson`.

`scenesList` s'en sert pour deux choses à la fois : remplir `$0-scenes` (`vider`, `ligne <i>`,
`champ …` vers `$0.scenes.buf`) et alimenter le constructeur du payload. **Elle prend le dossier
sur son entrée**, donc on peut la pointer sur n'importe quelle composition : c'est ce qui rend la
pêche du §19 possible sans deuxième lecteur.

Ce qui reste décrit à part : les valeurs par défaut d'une ligne neuve, dans `pd ligne`
(`empty null` × 7). Les tirer de `$0-champs` demanderait une deuxième colonne et une boucle pour la
relire.

## 22. `value` ou table : la forme de la donnée décide

Le critère n'est pas le nombre d'objets, c'est : la donnée est-elle isolée, ou appartient-elle à un
ensemble qu'on veut pouvoir lire en entier ?

**Isolée → `value`.** Les 9 variables internes de `siren-loop-state.pd` sont des scalaires lus sur
place, correctement scopés `$0`/`$2`. En table, chaque lecture coûterait une boîte de plus —
`text get` réclame un numéro de ligne sur son entrée chaude là où `value` se contente d'un bang — et
le défaut que les buffers corrigent (de l'état invisible, dépendant de l'ordre de remplissage)
n'existe pas : un `[value $0-x]` est nommé et se lit à tout moment.

**Associée → table.** L'état de lecture des sirènes est publié comme un ensemble :
`siren-clip-loader` diffuse `<index> <état>` sur `$0.loader.state`. `pd loop.states`, dans
`pedalier.pd`, en tient un `[text define -k $0.loopstates]` d'une ligne par sirène ; chaque
`siren-state-snapshot` y lit la sienne. L'état du looper entier se lit donc dans un objet, au lieu
d'être recopié dans sept caches privés.

Le `-k` sert à ce que les sept lignes existent au chargement : `text set` sur une ligne inexistante
ajoute *à la fin*, pas à l'index demandé — écrire la sirène 6 dans une table vide créerait la
ligne 0.

**Le signe qui ne trompe pas :** une donnée déjà diffusée et recopiée dans plusieurs caches privés
est une table qui s'ignore.

## 23. Piloter l'horloge pour tester

`midiclock` démarre en **source interne** (`; $1.source 0` dans son loadbang), et son horloge
interne n'est jamais démarrée : rien n'envoie `play`. Son inlet, dans `pedalier.pd`, ne reçoit que
`tempo` et `signature` depuis `$0.scene.broadcast` — `source`, `play` et `stop` ne sont routés de
nulle part. **Le transport reste donc à câbler.**

Pour tester la chaîne complète sans instrument, deux ports MIDI virtuels suffisent :

```
pd -nogui -noaudio -midiindev 3 -nomidiout  -open pedalier.pd     # écoute
pd -nogui -noaudio -nomidiin  -midioutdev 3 -open leurre.pd       # 250 puis 248 toutes les 20.83 ms
```

et un `source 1` envoyé à l'inlet de `midiclock` pour ouvrir la vanne du MIDI externe. La sortie
WebSocket publie alors `clock` puis `loops`, ce qui permet de vérifier de bout en bout l'état des
sept sirènes.
