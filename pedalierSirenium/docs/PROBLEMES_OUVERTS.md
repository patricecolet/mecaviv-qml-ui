# Problèmes ouverts — pédalier Sirenium

Tenu à jour au fil des campagnes de test. Le premier point est celui qui bloque
le plus l'usage ; les suivants sont classés par domaine, pas par gravité.

---

## 1. Le flux vers les sirènes se dégrade avec le temps

**Symptôme, rapporté le 2026-08-30 après une heure de jeu** — et déjà rencontré
la veille : les informations venant du sirénium arrivent de plus en plus
tronquées, des notes ne se déclenchent pas. Ça empire à mesure que la session
dure. Un **redémarrage rétablit** le fonctionnement normal, sans couper le
courant.

**Ce que le symptôme dit déjà** : les notes qui ne sonnent pas **apparaissent à
l'écran**. Pd les reçoit donc. La perte est en aval de la captation.

### Mesure du 2026-08-30 à 20:47, machine franchement dégradée

| | dégradé | après un simple redémarrage de Pd |
|---|---|---|
| CPU de Pd | **95 %** | 20,2 % stable |
| RSS | **1,15 Go, +2,4 Mo/s** | 872 Mo stable |
| `watchdog: signaling pd` | toutes les 2 s | zéro |
| déconnexions websocket | toutes les 2 s | zéro |

Le chien de garde de Pd se déclenche quand son fil temps réel n'est plus servi à
l'heure. À 95 % de CPU, le MIDI part en retard ou se perd : **c'est très
probablement la cause directe des notes tronquées.**

### Ce qui accumule

La page QML était dans une **boucle de reconnexion** — `Reconnexion` →
`The remote host closed the connection` → retry, toutes les 2 secondes. Pd
accepte puis referme aussitôt, et les numéros d'emplacement montent dans son
journal (`WEBSOCKETS LIST: 49` puis `51`). Le `websocket-server` vendorisé ne
paraît pas libérer les emplacements des clients partis : chaque rechargement de
page, chaque redémarrage de Pd et chaque reconnexion en consomme un. Une fois la
table pleine, le serveur referme tout, la page reboucle, et la tempête sature le
processeur.

Un redémarrage de Pd remet le compteur à zéro — ce qui explique que « le reboot
règle tout », et **écarte une boucle de messages qui se réalimenterait** dans les
patchs : celle-là repartirait aussitôt après le redémarrage, ce qui n'arrive pas.

### Écarté par la mesure, ne pas refaire

Une fuite mémoire de Pd **au repos** (872 Mo parfaitement stables sur plusieurs
minutes, deux fois vérifié) ; l'accumulation dans les 9 sockets UDP de Pd (files
0/0) ; toute file UDP de la machine ; un gonflement de `rtpmidid` (5,8 Mo,
0,1 % de CPU après 71 minutes).

> Une conclusion antérieure de cette fiche disait « ce n'est pas une fuite ».
> Elle était fausse parce que mesurée au repos : la consommation ne monte que
> quand la tempête de reconnexions tourne. Mesurer un régime, pas un instant.

### Corrigé le 2026-08-30

**La cause est la cadence de reconnexion, pas une fuite.** Le serveur plafonne à
**24 clients simultanés** — écrit en dur dans le patch vendorisé
(`websockets-list` → `list length` → `< 24`, sinon « connections limit
reached »), et confirmé au banc sur le Mac : la 25ᵉ connexion simultanée est
refusée. Les places sont bien rendues quand un client meurt (`pd remove_socket`),
donc rien ne fuit. Mais à 2 s fixes et sans relâche, une page qui n'arrive pas à
se connecter ouvre **30 connexions par minute** : un refus passager suffit à
remplir la table, le serveur refuse alors tout, et la page reboucle de plus
belle.

Le délai part maintenant de 1 s, double à chaque échec, plafonne à 15 s, et
repart à sa base dès que la socket s'ouvre — un redémarrage de PD est donc
rattrapé aussi vite qu'avant. Mesuré sur le Mac, page servie en local sans PD :
2, 4, 8, 15, 15 s, soit sept tentatives en 75 s là où l'ancienne cadence en
faisait trente-sept.

**Reste à vérifier en session longue** : que la dégradation d'une heure ne
revienne pas. Si elle revient malgré cet espacement, c'est qu'une autre source
remplit la table — chercher alors les connexions à demi mortes que PD ne réape
pas, et non une fuite.

Et hors de ce cadre, toujours ouvert : `rtpmidid` répète
`[ERROR] Bad CK count. Ignoring.` toutes les 25 secondes en annonçant une latence
de 0,20 ms.

## 2. La carte Artila de S6 a planté

**Constaté le 2026-08-30 en fin de soirée.** La sirène 6 a cessé de répondre en
pleine session. Un `reset` envoyé depuis le Mac n'a rien donné non plus — la
carte ne répondait à rien. Elle est revenue seule, après un délai qui correspond
au **temps de redémarrage d'une Artila** : elle a donc très probablement
redémarré d'elle-même. Cause inconnue.

C'est la même famille que le blocage de file de réception déjà connu sur ces
cartes, dont on ne sort que par un redémarrage.

**Ce que ça change pour le point 1.** Une carte qui tombe est une autre
explication des « notes qui ne se déclenchent pas » : côté pédalier tout est
correct — Pd reçoit la note, l'affiche, l'envoie — et pourtant rien ne sonne,
parce que la machine d'en face n'est plus là. Avant de creuser encore le chemin
Pd → sirènes, **vérifier d'abord que les sept cartes répondent**, et le noter
dans le compte rendu du symptôme. Un `ping` par sirène pendant la dégradation
suffirait à trancher.

## 3. Un `.last` qui désigne une composition disparue fait boucler le démarrage

**Mesuré le 2026-08-30.** Après avoir vidé la racine des compositions, le patch
part en `error: stack overflow` en rafale au démarrage et n'ouvre rien : la
machine est morte au boot, sans message compréhensible. `.last` nomme encore la
composition partie, le patch tente de l'ouvrir, et tourne en rond.

`pd last-opened` a déjà un repli quand `.last` est **absent ou vide** — mais pas
quand il nomme une composition qui n'existe plus.

**Une tentative de correctif a été faite puis retirée** (commit `7c1bd7f`,
annulé) : un garde-fou dans `pd open` testant `<racine>/<nom>/composition.json`
avec `file isfile` avant d'ouvrir, et retombant sur `compo.defaut` sinon. Il
récupérait bien, mais **saturait Pd** — 79 % de CPU, 1,2 Go, watchdog en rafale,
plus aucun MIDI traité — parce qu'il boucle entre `pd open` et `compo.defaut`.
La machine redevient saine dès qu'on l'enlève.

**À reprendre avec une sonde sur `compo.defaut`** pour voir la boucle au lieu de
la deviner. (`file isdir` n'existe pas dans ce Pd ; `file stat` est l'autre voie.)

## 3bis. `scene write` — CORRIGÉ le 2026-08-30

Le `report` envoyé aux loaders avant l'écriture lit `$0.scene.mode` et
`$0.scene.clipRef`, que seuls le chargement d'une scène et l'effacement
mettaient à jour : enregistrer ne les touchait pas, le loader répondait « empty »
et la scène partait vide. La prise les valide désormais. Vérifié :
`{"mode": "play", "siren": 1, "clipRef": "clip_…"}`.

Dans la foulée : les scènes sont rappelées au démarrage (un clip apporté par une
scène atterrit **arrêté**, il joue au premier `scene play`), une scène neuve vide
vraiment les pistes, et `scene new` écrit celle qu'on quitte.

## 4. Affichage pendant l'enregistrement

- **Le curseur défile pendant l'enregistrement**, alors que le looper ne connaît
  pas encore la longueur du parcours. Décidé le 2026-08-30 : il ne doit pas
  défiler ; une indication graphique doit dire « ça enregistre », sans prétendre
  situer une position. Non construit.
- **Le début de la première boucle ne correspond pas au début de
  l'enregistrement** quand le clip passe en lecture. Non diagnostiqué.

## 5. Les clips effacés restent sur le disque

L'effacement vide le loader et remet sa cellule à `empty`, mais ne supprime ni le
`.mid` ni le `.json`. Les orphelins s'accumulent à chaque effacement. La commande
`clean` est spécifiée depuis le 2026-08-22, jamais construite.

## 6. LEDs — trois défauts sans conséquence bloquante

- **`led.pedal.preselection` allume le mauvais rond** : il fait `+ 9` sur le
  numéro de **voix**, alors que `led.siren.selected` convertit voix → **sirène**
  avant son `+ 9`. Les deux réagissent au même événement et se contredisent d'un
  cran. C'est `led.siren.selected` qui a raison : la LED est sur le rond, et les
  ronds sont numérotés par sirène.
- **`led.pedal.selection` est mort** : il écoute `voice.update.value` **sans
  `$0`**, un nom global qu'aucune abstraction instanciée n'émet. S'il revenait à
  la vie, son `+ 25` écrirait sur 26–32, la rangée que `led-clip-state` pilote.
- **`initLED` éteint encore 18–24** à chaque scène chargée : son `+ 17` visait la
  rangée « sirène en lecture », supprimée le 2026-08-01. Il tombe aujourd'hui sur
  les LEDs des pédales, qui s'éteignent brièvement à chaque chargement.

## 7. Le timer de câblage MIDI s'est tu pendant dix-neuf minutes

Le 2026-08-30, entre 18:17 et 18:36, `pedalier-midi-connect.timer` n'a pas
déclenché une seule fois alors qu'il est réglé sur 60 s et qu'il fonctionnait à
17:45. Contourné — Pd redemande lui-même son câblage au démarrage — mais **la
cause reste inconnue**, et le timer reste le filet de sécurité pour un
branchement à chaud.

## 8. Le portrait QML ne dessine pas le pédalier

`PedalboardPortrait2D` montre 8 poussoirs assignables, 3 pédales d'expression et
le PK-6 — c'est-à-dire la Petite Boîte et la BOSS, pas le pédalier. Il manque les
ronds 10–17 et la rangée 18–25 ; aucun numéro de CC n'y figure ; et la matrice de
modulation qu'il commande est indexée par pédale physique (0–2) alors qu'elle
attend un `pedalId` 1–8, donc les interrupteurs n'ont aucun effet sur ce qu'elle
affiche.

## 9. `PEDALIER_MAPPING.md` porte deux plages fausses

- Petite Boîte : le tableau « Autres entrées » dit 53–60 ; le patch fait
  `moses 59` puis `- 50`, donc **51–58**, ce que dit l'inventaire.
- Le tableau des LEDs décrit `led.siren.playing` et `led.siren.recording`, deux
  sous-patchs qui **n'existent plus** : `led.clip.state` les remplace, avec
  `+ 26` → 26–32 et `select 1 2` (clignote à l'enregistrement, fixe en lecture).

## 10. Sondes de diagnostic — RETIRÉES le 2026-08-30

Elles sortaient **14 lignes par seconde** : `$0.loader.state` est réémis deux fois
par seconde et par loader même quand rien ne change. Retrait mesuré : 280 lignes
de journal par 20 s → 1. Le CPU de Pd n'en bouge pas (21,7 %) — elles coûtaient
du disque et de la lisibilité, pas du calcul.

Au passage, deux choses à retenir de cette campagne. Le **gros consommateur de
cette machine est le kiosque Chromium, à 46 %**, contre 22 % pour Pd : si
l'interface paraît molle, c'est là qu'il faut chercher, et la page anime ses
anneaux en continu même quand rien ne bouge. Et **relancer Pd jette tout ce qui
est dans les loaders et n'a pas été écrit** — ne pas le faire pendant que
quelqu'un joue.

## 11. Surface non attribuée

Les pédales **23, 24, 25** sont libres depuis la refonte du 2026-08-30, ainsi que
les **cinq touches noires et le Do aigu (38)** du PK-6. La confirmation par appui
long sur `scene write / duplicate` (rond 21) reste à discuter.
