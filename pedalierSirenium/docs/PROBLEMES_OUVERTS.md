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

### Prochaine étape

Ouvrir `application.layer/websocket-server.pd` (2563 lignes, vendorisé, clients
gérés en `list`) et vérifier ce qu'il fait de l'emplacement d'un client
déconnecté. Et côté QML, espacer les tentatives de reconnexion au lieu d'une
toutes les 2 secondes, pour que l'échec ne se transforme pas en tempête.

Reste hors de ce cadre, et à ne pas oublier : `rtpmidid` répète
`[ERROR] Bad CK count. Ignoring.` toutes les 25 secondes en annonçant une latence
de 0,20 ms.

## 2. `scene write` n'enregistre pas les boucles

**Mesuré le 2026-08-30 à 20:56.** Une boucle tourne sur la sirène 1 (`loader.state`
= 2), on demande l'écriture de la scène, `composition-io` répond bien
`Builder JSON saved to: …/scene_N.json` — et le fichier écrit porte
`mode: "empty"` sur les sept sirènes.

Ce n'est pas nouveau : les deux écritures déclenchées à 18:19 et 18:21 pendant la
campagne avaient déjà produit des scènes vides. **`scene write` n'a donc jamais
rien sauvé.** C'est le socle de toute la gestion des scènes — tant qu'il ne
fonctionne pas, rien de ce qui est joué ne peut être gardé, et une nouvelle scène
emporte forcément le travail en cours.

Conséquence immédiate : l'écriture automatique posée dans `scene new` (« ne pas
emporter le travail non écrit ») est correctement câblée mais **inopérante**,
puisqu'elle appelle un mécanisme qui écrit du vide.

**Où chercher** : `pd scene.save` envoie `report` sur `$0.scene.broadcast` puis
`saveScene` à `composition-io`. Le `report` doit faire remonter la cellule de
chaque loader (`pd report` lit `$0.scene.mode` et `$0.scene.clipRef`, remplis par
`pd sirens` et `pd loop.erase`). Vérifier d'abord **ce que chaque loader répond
au `report`**, ensuite seulement l'ordre entre les réponses et le `saveScene`.

## 3. Affichage pendant l'enregistrement

- **Le curseur défile pendant l'enregistrement**, alors que le looper ne connaît
  pas encore la longueur du parcours. Décidé le 2026-08-30 : il ne doit pas
  défiler ; une indication graphique doit dire « ça enregistre », sans prétendre
  situer une position. Non construit.
- **Le début de la première boucle ne correspond pas au début de
  l'enregistrement** quand le clip passe en lecture. Non diagnostiqué.

## 4. Les clips effacés restent sur le disque

L'effacement vide le loader et remet sa cellule à `empty`, mais ne supprime ni le
`.mid` ni le `.json`. Les orphelins s'accumulent à chaque effacement. La commande
`clean` est spécifiée depuis le 2026-08-22, jamais construite.

## 5. LEDs — trois défauts sans conséquence bloquante

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

## 6. Le timer de câblage MIDI s'est tu pendant dix-neuf minutes

Le 2026-08-30, entre 18:17 et 18:36, `pedalier-midi-connect.timer` n'a pas
déclenché une seule fois alors qu'il est réglé sur 60 s et qu'il fonctionnait à
17:45. Contourné — Pd redemande lui-même son câblage au démarrage — mais **la
cause reste inconnue**, et le timer reste le filet de sécurité pour un
branchement à chaud.

## 7. Le portrait QML ne dessine pas le pédalier

`PedalboardPortrait2D` montre 8 poussoirs assignables, 3 pédales d'expression et
le PK-6 — c'est-à-dire la Petite Boîte et la BOSS, pas le pédalier. Il manque les
ronds 10–17 et la rangée 18–25 ; aucun numéro de CC n'y figure ; et la matrice de
modulation qu'il commande est indexée par pédale physique (0–2) alors qu'elle
attend un `pedalId` 1–8, donc les interrupteurs n'ont aucun effet sur ce qu'elle
affiche.

## 8. `PEDALIER_MAPPING.md` porte deux plages fausses

- Petite Boîte : le tableau « Autres entrées » dit 53–60 ; le patch fait
  `moses 59` puis `- 50`, donc **51–58**, ce que dit l'inventaire.
- Le tableau des LEDs décrit `led.siren.playing` et `led.siren.recording`, deux
  sous-patchs qui **n'existent plus** : `led.clip.state` les remplace, avec
  `+ 26` → 26–32 et `select 1 2` (clignote à l'enregistrement, fixe en lecture).

## 9. Sondes de diagnostic encore en place

`print sonde.pedale.S<n>`, `print sonde.confirme.S<n>` dans `siren-clip-loader`,
et `pd sonde.voices` / `print sonde.etat` dans `pedalier.pd`. À retirer en un
commit quand la campagne de tests sera close.

## 10. Surface non attribuée

Les pédales **23, 24, 25** sont libres depuis la refonte du 2026-08-30, ainsi que
les **cinq touches noires et le Do aigu (38)** du PK-6. La confirmation par appui
long sur `scene write / duplicate` (rond 21) reste à discuter.
