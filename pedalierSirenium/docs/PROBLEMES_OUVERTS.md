# Problèmes ouverts — pédalier Sirenium

Tenu à jour au fil des campagnes de test. Dernière mise à plat : **2026-08-31**, après une nuit de
correctifs sur le Raspberry.

Deux règles de lecture. **« Corrigé » ne veut pas dire « validé »** : la plupart des correctifs
ci-dessous ont été mesurés par injection MIDI et lecture d'écran, pas éprouvés au pied — la
distinction est portée par le tableau en tête. Et **la doc n'est jamais la source** : quand elle
contredit une mesure, c'est elle qui a tort, plusieurs sections ci-dessous en témoignent.

---

## État de validation au 2026-08-31

| Corrigé et **validé par Patrice** | Corrigé, **attend son pied** |
|---|---|
| une boucle arrêtée reste la référence | le tempo dans le `.mid` et le `.json` du clip |
| l'origine de grille repart avec l'horloge | **l'ancrage de la grille sur le décalage de la référence** (§17) |
| le changement de scène du petit boîtier, à la mesure | |
| l'héritage du tempo par une scène neuve | |
| une scène neuve ne ressuscite plus les boucles | |
| la note affichée aux anneaux (sous réserve accordeur) | |
| le clavier de renommage de scène | |
| la mire pendant l'enregistrement | |
| le tap tempo | |
| supprimer une scène supprime ses clips | |
| le nommage numéroté des scènes | |
| l'effacement d'une boucle | |
| le garde-fou « fichier absent » | |

---

## 1. Le flux vers les sirènes se dégrade avec le temps

**À surveiller** — décidé le 2026-08-31.

**Symptôme, rapporté le 2026-08-30 après une heure de jeu** — et déjà rencontré la veille : les
informations venant du sirénium arrivent de plus en plus tronquées, des notes ne se déclenchent
pas. Ça empire à mesure que la session dure. Un **redémarrage rétablit** le fonctionnement normal,
sans couper le courant.

**Ce que le symptôme dit déjà** : les notes qui ne sonnent pas **apparaissent à l'écran**. Pd les
reçoit donc. La perte est en aval de la captation.

### Mesure du 2026-08-30 à 20:47, machine franchement dégradée

| | dégradé | après un simple redémarrage de Pd |
|---|---|---|
| CPU de Pd | **95 %** | 20,2 % stable |
| RSS | **1,15 Go, +2,4 Mo/s** | 872 Mo stable |
| `watchdog: signaling pd` | toutes les 2 s | zéro |
| déconnexions websocket | toutes les 2 s | zéro |

Le chien de garde de Pd se déclenche quand son fil temps réel n'est plus servi à l'heure. À 95 % de
CPU, le MIDI part en retard ou se perd : **c'est très probablement la cause directe des notes
tronquées.**

### Corrigé le 2026-08-30 : la cadence de reconnexion

Le serveur plafonne à **24 clients simultanés** — écrit en dur dans le patch vendorisé
(`websockets-list` → `list length` → `< 24`), confirmé au banc sur le Mac : la 25ᵉ connexion
simultanée est refusée. Les places sont bien rendues quand un client meurt (`pd remove_socket`),
donc rien ne fuit. Mais à 2 s fixes et sans relâche, une page qui n'arrive pas à se connecter ouvre
**30 connexions par minute** : un refus passager suffit à remplir la table, le serveur refuse alors
tout, et la page reboucle de plus belle.

Le délai part maintenant de 1 s, double à chaque échec, plafonne à 15 s, et repart à sa base dès que
la socket s'ouvre. Mesuré sur le Mac, page servie sans PD : 2, 4, 8, 15, 15 s — sept tentatives en
75 s là où l'ancienne cadence en faisait trente-sept.

**Reste à vérifier en session longue.** Si la dégradation d'une heure revient malgré cet espacement,
c'est qu'une autre source remplit la table : chercher les connexions à demi mortes que PD ne réape
pas, et non une fuite.

### Écarté par la mesure, ne pas refaire

Une fuite mémoire de Pd **au repos** (872 Mo stables sur plusieurs minutes, deux fois vérifié) ;
l'accumulation dans les 9 sockets UDP de Pd (files 0/0) ; toute file UDP de la machine ; un
gonflement de `rtpmidid` (5,8 Mo, 0,1 % de CPU après 71 minutes).

> Une conclusion antérieure de cette fiche disait « ce n'est pas une fuite ». Elle était fausse
> parce que mesurée au repos : la consommation ne monte que quand la tempête tourne. **Mesurer un
> régime, pas un instant.**

Hors de ce cadre, toujours ouvert : `rtpmidid` répète `[ERROR] Bad CK count. Ignoring.` toutes les
25 secondes en annonçant une latence de 0,20 ms.

## 2. La carte Artila de S6 a planté

**À surveiller**, et **une session complète y sera consacrée** : logger `dmesg` en continu et
essayer de provoquer le bug. Décidé le 2026-08-31.

**Constaté le 2026-08-30 en fin de soirée.** La sirène 6 a cessé de répondre en pleine session. Un
`reset` envoyé depuis le Mac n'a rien donné. Elle est revenue seule, après un délai qui correspond
au **temps de redémarrage d'une Artila** : elle a donc très probablement redémarré d'elle-même.
Cause inconnue. C'est la même famille que le blocage de file de réception déjà connu sur ces cartes.

**Ce que ça change pour le point 1.** Une carte qui tombe est une autre explication des « notes qui
ne se déclenchent pas » : côté pédalier tout est correct — Pd reçoit la note, l'affiche, l'envoie —
et pourtant rien ne sonne. **Avant de creuser encore le chemin Pd → sirènes, vérifier d'abord que
les sept cartes répondent**, et le noter dans le compte rendu. Un `ping` par sirène pendant la
dégradation suffirait à trancher.

## 3. Un `.last` qui désigne une composition disparue — CORRIGÉ le 2026-08-30

**Mesuré** : après avoir vidé la racine des compositions, le patch partait en `error: stack
overflow` en rafale au démarrage et n'ouvrait rien. `.last` nommait encore la composition partie,
le patch tentait de l'ouvrir, et tournait en rond.

Une première tentative (`7c1bd7f`) a été **annulée** : le garde-fou testait
`<racine>/<nom>/composition.json` avec `file isfile` et retombait sur `compo.defaut` — il récupérait
bien, mais **saturait Pd** (79 % de CPU, 1,2 Go, watchdog en rafale) parce qu'il bouclait entre
`pd open` et `compo.defaut`.

La version retenue (`b6b6b88`) ajoute un **verrou** : le repli ne peut se déclencher qu'une fois, le
`spigot` se referme derrière lui et se réarme au succès suivant. La machine reste saine.

*(`file isdir` n'existe pas dans ce Pd ; `file stat` est l'autre voie.)*

## 4. Affichage pendant l'enregistrement — VALIDÉ le 2026-08-31

Le curseur ne défile plus pendant la prise, la boucle part bien au début, et le compteur de mesures
compte la prise en cours. Deux correctifs distincts ont dû tomber avant que ça marche : l'ancrage du
curseur sur sa boucle, et l'origine de grille (§12).

## 5. Les clips effacés restent sur le disque

**Reporté après les compositions**, avec sans doute **une page de maintenance dédiée** — décidé le
2026-08-31. C'est aussi là qu'on affichera le **tempo d'origine d'un clip**, désormais écrit dans
son `.mid` et son `.json` (§13).

L'effacement d'une boucle vide le loader et remet sa cellule à `empty`, mais ne supprime ni le
`.mid` ni le `.json`. Les orphelins s'accumulent. La commande `clean` est spécifiée depuis le
2026-08-22, jamais construite.

*(Supprimer une **scène** supprime bien ses clips depuis le 2026-08-30, `3e2e19f` — c'est
l'effacement d'une **boucle** seule qui laisse des traces.)*

## 6. LEDs — trois défauts

**Patrice les a marqués corrigés le 2026-08-31.** Non revérifiés dans le patch depuis. Ce qui avait
été constaté :

- **`led.pedal.preselection` allume le mauvais rond** : `+ 9` sur le numéro de **voix**, alors que
  `led.siren.selected` convertit voix → **sirène** avant son `+ 9`. C'est `led.siren.selected` qui a
  raison : la LED est sur le rond, et les ronds sont numérotés par sirène.
- **`led.pedal.selection` est mort** : il écoute `voice.update.value` **sans `$0`**, un nom global
  qu'aucune abstraction instanciée n'émet.
- **`initLED` éteint 18–24** à chaque scène chargée : son `+ 17` visait la rangée « sirène en
  lecture », supprimée le 2026-08-01.

Corrigé et mesuré le 2026-08-31 (`5bd660f`) : le retour LED du **petit boîtier** n'éteignait que les
boutons 1 à 7, donc le 8 restait allumé une fois qu'on y était passé et le boîtier montrait deux
scènes courantes.

## 7. Le câblage MIDI au démarrage

**À optimiser** — décidé le 2026-08-31.

Deux choses distinctes :

- **Le timer s'est tu pendant dix-neuf minutes.** Le 2026-08-30, entre 18:17 et 18:36,
  `pedalier-midi-connect.timer` n'a pas déclenché une seule fois alors qu'il est réglé sur 60 s et
  qu'il fonctionnait à 17:45. Contourné — Pd redemande son câblage au démarrage — mais **la cause
  reste inconnue**, et le timer reste le filet de sécurité pour un branchement à chaud.
- **Le rebranchement prend jusqu'à 40 s après un redémarrage de Pd**, le temps que le client ALSA
  « Pure Data » apparaisse. Piège de test mesuré plusieurs fois cette nuit : une injection MIDI
  lancée trop tôt part dans le vide et **ressemble à un correctif qui ne marche pas**. Toujours
  vérifier `aconnect -l` avant de conclure.

## 8. Le portrait QML ne dessine pas le pédalier

**Reporté, à faire avec les compositions** — c'est lié — décidé le 2026-08-31.

`PedalboardPortrait2D` montre 8 poussoirs assignables, 3 pédales d'expression et le PK-6 —
c'est-à-dire la Petite Boîte et la BOSS, pas le pédalier. Il manque les ronds 10–17 et la rangée
18–25 ; aucun numéro de CC n'y figure ; et la matrice de modulation qu'il commande est indexée par
pédale physique (0–2) alors qu'elle attend un `pedalId` 1–8, donc les interrupteurs n'ont aucun
effet sur ce qu'elle affiche.

## 9. `PEDALIER_MAPPING.md` — CORRIGÉ le 2026-08-31

Le tableau « Autres entrées » annonçait les boutons du petit boîtier en **53–60** alors que le patch
fait `moses 59` puis `- 50`, soit **51–58** — l'inventaire disait juste, le tableau mentait, et le
commentaire à l'intérieur du sous-patch répétait la même erreur (corrigé aussi). Le tableau des LEDs
décrivait `led.siren.playing` et `led.siren.recording`, deux sous-patchs qui n'existent plus :
`led.clip.state` les remplace.

## 10. Sondes de diagnostic — RETIRÉES le 2026-08-30

Elles sortaient **14 lignes par seconde** : `$0.loader.state` est réémis deux fois par seconde et par
loader même quand rien ne change. Retrait mesuré : 280 lignes de journal par 20 s → 1. Le CPU de Pd
n'en bouge pas — elles coûtaient du disque et de la lisibilité, pas du calcul.

Deux choses à retenir de cette campagne. Le **gros consommateur de cette machine est le kiosque
Chromium, à 46 %**, contre 22 % pour Pd : si l'interface paraît molle, c'est là qu'il faut chercher,
et la page anime ses anneaux en continu même quand rien ne bouge. Et **relancer Pd jette tout ce qui
est dans les loaders et n'a pas été écrit** — ne pas le faire pendant que quelqu'un joue.

## 11. Surface non attribuée

- **Pédale 23** : Patrice propose un `scene delete` qui **libère un emplacement**, ce qui implique
  deux choses — **à discuter avant de construire**, annoncé le 2026-08-31.
- **Pédales 24 et 25** : libres depuis la refonte du 2026-08-30.
- **Les cinq touches noires et le do aigu (38) du PK-6** : libres. Reporté après les pédales.

## 12. Le tempo d'une scène est écrit, jamais relu

**Trouvé le 2026-08-31, non corrigé.**

Chaque scène porte un champ `tempo` : le gabarit d'une scène neuve **hérite du tempo courant**
(`993c8b6`) et `scene write` y consigne le tempo au moment de l'écriture (`4fff7d8`). Mesuré : tap
tempo à 117 → `scene_6.json` porte `"tempo":117`.

**Mais personne ne relit ce champ.** Mesuré deux fois : six changements de scène d'affilée en
passant par des scènes à 117 et d'autres à 120 → l'horloge reste à 120 du début à la fin ; et après
un redémarrage complet de Pd, la scène courante portant 117, l'écran affiche 120.

La plomberie existe pourtant de bout en bout : `pd scene` lit le fichier et le `dump`, le dump sort
par la 2ᵉ sortie de `composition-io` et atterrit sur `$0.scene.broadcast`, où `pd midiclock` écoute
`route tempo signature`. Restent deux causes possibles, que **la lecture du patch ne départage
pas** : soit le `dump` de pdjson n'émet pas ce champ sous la forme attendue, soit il l'émet avant
que l'horloge ne soit prête et un 120 d'initialisation passe derrière.

**Prochain geste : une sonde sur `$0.scene.broadcast` au chargement d'une scène.** Pas une relecture
de plus.

## 13. Le `+1` d'affichage reste à vérifier à l'accordeur

**Demandé par Patrice le 2026-08-31.**

`$0.to.sirens` ne porte pas des notes musicales : `pd transposeQuarterTune` y écrit
`note = floor($f1 - 0.5 + $f2/8192)` avec `bend = fmod($f2 + 4096, 8192)`, soit **59 + bend 4096
pour un do**. Le commentaire du patch l'assume — « the tune is scaled 1/4 tone lower » — et
`composeSiren~` connaît la convention, donc le son est juste. C'est l'affichage qui lisait ce nombre
comme une hauteur MIDI, d'où « Si » pour un do joué.

`pd midi.binary` ajoute donc 1 avant d'émettre (`273e6db`). **L'harmoniseur n'est pas touché**,
consigne explicite. Deux réserves :

- **le `+1` corrige l'affichage, il ne prouve rien sur la fréquence réellement émise** — d'où la
  vérification à l'accordeur ;
- il est exact tant que le bend d'entrée est neutre, c'est-à-dire une note jouée. Sous un bend
  franc, la note du fil dérive jusqu'à un demi-ton. Le rendre exact demanderait de faire passer le
  bend sur le canal binaire et de recomposer `note + bend/8192 + 0.5` — le canal ne porte
  aujourd'hui que les notes.

## 14. Limite de méthode : les injections MIDI n'atteignent pas la captation

**Mesuré le 2026-08-31.** Injecter des notes avec `amidi -p hw:0,0 -S "90 3C 64"` crée bien le
fichier de clip et sa longueur, mais le `.mid` sort **sans une seule note** — la captation écoute
`$3.to.sirens`, en aval de l'harmoniseur, pas l'entrée brute.

Conséquence pratique : **« une prise enregistre vraiment les notes » ne peut être validé qu'au
pied.** Les pédales, elles, s'injectent parfaitement (`amidi -p hw:0,0 -S "B8 <cc> 7F"`, status B8 =
CC canal 9) et c'est ainsi que tout le reste a été mesuré cette nuit.

## 15. `lua: error in dispatcher` à chaque démarrage de Pd

Sans conséquence visible, cause inconnue, présent avant cette session. Noté pour qu'on cesse de le
redécouvrir à chaque lecture de journal.

## 16. Docs qui restent périmées

`docs/MIDI_CONFIGURATION.md` décrit un onglet « MIDI » du Debug Panel pour choisir les ports ; le
panneau **et** l'onglet ont été supprimés. Le fichier porte une bannière de péremption — la garder,
ne pas agir sur ses instructions.

## 17. L'ancrage de la grille sur la référence — corrigé, **pas validé**

**En suspens au 2026-09-01.** Corrigé, déployé, mesuré par moi ; Patrice n'a pas pu l'éprouver.

**Symptôme.** Une boucle rappelée jouait une mesure en retard sur le métronome. Mesuré sur une
boucle de 4 mesures : mesure globale 1, 2, 3, 4 → mesure de la boucle 1/4, 1/4, 2/4, 3/4. Son cycle
ne coïncidait plus avec la grille, donc au moment où elle rebouclait, l'écran était encore sur la
mesure d'avant.

**Cause.** `startBar = mainloop-startbar + offset_ticks/1920`, et `offset_ticks` vient du fichier du
clip : c'est le décalage capté quand ce clip a été enregistré, dans une session dont la grille
n'existe plus. On l'appliquait par-dessus l'origine remise à zéro au départ du transport.

**Correctif retenu, choisi par Patrice** : garder les décalages relatifs entre boucles, ancrés sur
celui de la référence — l'origine se pose à **l'opposé** du décalage de la référence, puisque chaque
loader calcule déjà `origine + son propre décalage`. Le nombre remonte par un cinquième champ de
`$0.loopstates`. Détail dans `LOOPER_STATE_MACHINE.md` §3quater.

**Mesure après correction** : mesure globale 1, 2, 3 → 1/4, 2/4, 3/4. Pd à 22 %, zéro erreur au
chargement.

**Ce qui reste à éprouver au pied** : qu'une boucle enregistrée en cours de session, elle, garde
bien son décalage voulu — je n'ai mesuré que le cas du rappel, et je ne peux pas enregistrer de
notes moi-même (§14).

## 18. Deux hauteurs hors de toute plage MIDI

**Vu une fois le 2026-08-31, non reproduit, non expliqué.** Sur une capture d'écran, S3 affichait
« Mi 18 » et le sirénium « Do -2 » — soit des notes autour de 244 et de 0, impossibles pour du MIDI.
Les autres sirènes affichaient des valeurs saines (Ré 3, Do 2, Do 5) au même instant.

Ça peut n'être qu'un résidu de mes injections MIDI de la nuit. Mais si ça réapparaît en jouant,
c'est une piste sérieuse : la formule d'affichage est la même des deux côtés
(`_names[note % 12]` + `floor(note/12) − 2`), donc une valeur aberrante à l'écran vient d'une valeur
aberrante sur le fil, pas du calcul.
