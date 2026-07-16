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
| **mute** | non | continue d'avancer | *à confirmer* | la position tourne en silence → retour synchro à l'unmute |
| **solo** | oui | oui | tourne | **réduit au silence les autres sirènes** ; solo classique |
| **oneshot** | oui, une fois | non | tourne puis s'arrête | passe une fois, puis état « joué » |

### Le moteur est une dimension à part entière

Silencier une sirène = **arrêter son moteur** (décidé pour le solo : les non-solo se taisent moteur
coupé). Une sirène mécanique ne se tait pas instantanément — le rotor décélère, et remonte en
vitesse au retour. Donc :

- un changement de mode a une **durée** (spin-down / spin-up), pas une bascule nette ;
- cette durée est une information que **l'écran** doit porter (les LEDs ne rendent pas le transitoire) ;
- elle se lit déjà dans les RPM (`revolutionCount`) que le patch envoie.

**À définir** : pour `stop` et `mute`, le moteur s'arrête-t-il aussi (silence = moteur coupé) ou
reste-t-il en rotation à vide ? La réponse décide si ces modes ont une latence de reprise. Colonne
« Moteur » à compléter.

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

- **Sélection des sirènes** : les touches naturelles du clavier (Do→S1 … Si→S7) rendent une sirène
  **éligible** à l'accord. Même geste que la sélection de sirène habituelle.
- **Réglage du voicing** : un **poussoir maintenu** pendant qu'on **joue l'accord** sur le clavier ;
  l'harmoniseur extrait les intervalles, relatifs à la fondamentale.
- **Répartition** : par **hauteur**, pas par étiquette — la note la plus grave va sur la sirène la
  plus grave. Ordre des sirènes grave→aigu : **S3 S4 S1 S2 S5 S6 S7**. Chaque voix est repliée dans
  l'ambitus de sa sirène (`sirenSpec`).
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
| `loop.definition.txt` : matériel **et** état (isLoop, playing, loopSize) mêlés | Clip = matériel + propriétés intrinsèques ; **mode sorti dans la scène** |
| `saveScene` route 4 champs | route 4 champs + l'état des 7 sirènes |
| `clip_XXX/` en pool (déjà le cas) | inchangé — le pool existe déjà |

Le `mainLoop` et le champ de rapport de `loopSize` (dernier nombre de `loopSize 0 3 16 0 4`) sont
déjà écrits : ils alimentent le second cercle « référence » et l'échelle des paliers de l'écran.

## 8. Décisions restantes

- Comportement moteur exact de `stop` et `mute` (coupé ou rotation à vide → latence de reprise).
- Rôle de `clip write` (CC 19) si l'inscription en scène est automatique.
- Forme exacte du signal « modifié / non enregistré ».
