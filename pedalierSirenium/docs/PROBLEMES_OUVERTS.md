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
l'écran**. Pd les reçoit donc, et les relaie au QML par le canal binaire. La
perte est **en aval de Pd**, sur le chemin vers les sirènes — pas dans la
captation.

**Mesures prises le 2026-08-30 vers 19:55, machine en état dégradé :**

| Mesure | Valeur | Ce qu'elle écarte |
|---|---|---|
| Pd, RSS | **872 Mo, stables sur 2 min** | pas de fuite mémoire |
| Pd, CPU | 20,9 %, stable | pas d'emballement |
| 9 sockets UDP de Pd | files `0 / 0` | rien ne s'accumule à l'émission |
| files UDP de la machine | aucune non vide | rien ne s'accumule à la réception |
| rtpmidid | 71 min, 5,8 Mo, 0,1 % CPU | le démon ne gonfle pas |
| charge | 1,53 / 1,75 / 1,82 | machine pas saturée |

**Le seul signal anormal trouvé** : `rtpmidid` répète toutes les 25 secondes
`[ERROR] rtppeer.cpp:315 | Bad CK count. Ignoring.`, alors qu'il annonce une
latence de 0,20 ms. `CK` est la synchronisation d'horloge RTP-MIDI. À creuser en
premier — c'est le seul compteur qui parle d'un désaccord qui pourrait s'aggraver.

**Non exploré** : le débit MIDI réellement émis vers les sirènes ; l'état des
neuf sockets UDP, ouvertes **une seule fois au chargement du patch** et jamais
rouvertes (voir la note sur le démarrage sans réseau) ; le comportement des
machines de destination, dont `192.168.1.103` et `.113` ne répondaient pas au
ping pendant la mesure.

**Comment mesurer la prochaine fois, sans attendre une heure** : relever RSS,
CPU et les files UDP à intervalles réguliers depuis le début de la session, pour
obtenir une pente au lieu d'un point.

---

## 2. Affichage pendant l'enregistrement

- **Le curseur défile pendant l'enregistrement**, alors que le looper ne connaît
  pas encore la longueur du parcours. Décidé le 2026-08-30 : il ne doit pas
  défiler ; une indication graphique doit dire « ça enregistre », sans prétendre
  situer une position. Non construit.
- **Le début de la première boucle ne correspond pas au début de
  l'enregistrement** quand le clip passe en lecture. Non diagnostiqué.

## 3. Les clips effacés restent sur le disque

L'effacement vide le loader et remet sa cellule à `empty`, mais ne supprime ni le
`.mid` ni le `.json`. Les orphelins s'accumulent à chaque effacement. La commande
`clean` est spécifiée depuis le 2026-08-22, jamais construite.

## 4. LEDs — trois défauts sans conséquence bloquante

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

## 5. Le timer de câblage MIDI s'est tu pendant dix-neuf minutes

Le 2026-08-30, entre 18:17 et 18:36, `pedalier-midi-connect.timer` n'a pas
déclenché une seule fois alors qu'il est réglé sur 60 s et qu'il fonctionnait à
17:45. Contourné — Pd redemande lui-même son câblage au démarrage — mais **la
cause reste inconnue**, et le timer reste le filet de sécurité pour un
branchement à chaud.

## 6. Le portrait QML ne dessine pas le pédalier

`PedalboardPortrait2D` montre 8 poussoirs assignables, 3 pédales d'expression et
le PK-6 — c'est-à-dire la Petite Boîte et la BOSS, pas le pédalier. Il manque les
ronds 10–17 et la rangée 18–25 ; aucun numéro de CC n'y figure ; et la matrice de
modulation qu'il commande est indexée par pédale physique (0–2) alors qu'elle
attend un `pedalId` 1–8, donc les interrupteurs n'ont aucun effet sur ce qu'elle
affiche.

## 7. `PEDALIER_MAPPING.md` porte deux plages fausses

- Petite Boîte : le tableau « Autres entrées » dit 53–60 ; le patch fait
  `moses 59` puis `- 50`, donc **51–58**, ce que dit l'inventaire.
- Le tableau des LEDs décrit `led.siren.playing` et `led.siren.recording`, deux
  sous-patchs qui **n'existent plus** : `led.clip.state` les remplace, avec
  `+ 26` → 26–32 et `select 1 2` (clignote à l'enregistrement, fixe en lecture).

## 8. Sondes de diagnostic encore en place

`print sonde.pedale.S<n>`, `print sonde.confirme.S<n>` dans `siren-clip-loader`,
et `pd sonde.voices` / `print sonde.etat` dans `pedalier.pd`. À retirer en un
commit quand la campagne de tests sera close.

## 9. Surface non attribuée

Les pédales **23, 24, 25** sont libres depuis la refonte du 2026-08-30, ainsi que
les **cinq touches noires et le Do aigu (38)** du PK-6. La confirmation par appui
long sur `scene write / duplicate` (rond 21) reste à discuter.
