# Déploiement du pédalier

Deux scripts, une seule logique : **le Pi va chercher le code lui-même par git**,
le Mac ne pousse que ce que git ne transporte pas (les artefacts du build Qt,
dont le wasm de 40 Mo) et pilote le reste à distance.

```
Mac                                    Raspberry (sirenateur@192.168.1.21)
pedalier-deploy.sh ──ssh──► /tmp/pedalier-deploy.<epoch>/pedalier-ctl.sh
                   └─rsync─► webfiles/  (wasm, glue JS, page, module QML)
                                        └─ git clone/pull ──► GitHub
```

## Usage courant

```bash
./deploy/pedalier-deploy.sh                  # mise à jour complète
./deploy/pedalier-deploy.sh --build          # reconstruit le wasm d'abord
./deploy/pedalier-deploy.sh build            # pousse seulement les artefacts
./deploy/pedalier-deploy.sh doctor           # diagnostic
./deploy/pedalier-deploy.sh logs             # journal de Pure Data en direct
./deploy/pedalier-deploy.sh --dry-run bootstrap   # simulation, des deux côtés
```

Sur la machine elle-même (`pedalier-deploy.sh shell`) :

```bash
~/dev/src/mecaviv-qml-ui/pedalierSirenium/deploy/pedalier-ctl.sh doctor
pedalier-ctl.sh restart | status | logs | songs list
```

## Ce que fait un bootstrap

`preflight` → sauvegarde des morceaux → `deps` → `repos` → `migrate` →
`pd-build` → `externals` → `web` → `midi` → `autostart` → démarrage.

Chaque phase vérifie l'état avant d'agir : rejouer la commande sur une machine à
jour ne modifie rien et prend une quinzaine de secondes. `--dry-run` affiche
l'intégralité de ce qui serait fait sans rien exécuter, `--only <phase>` et
`--skip <phase>` isolent une étape.

## Ce qui tourne sur la machine

Backend en **systemd `--user`** (`pedalier.target` : rtpmidid → Pure Data → node
→ câblage ALSA), avec `enable-linger` pour qu'il démarre au boot **sans session
graphique** : écran débranché, le pédalier répond quand même en MIDI et en
WebSocket.

Kiosque Chromium en **autostart XDG** (`~/.config/autostart/pedalier-kiosk.desktop`).
Surtout pas `~/.config/labwc/autostart` : un fichier utilisateur y remplacerait
l'autostart système du Pi (bureau, panneau, et le lancement des `.desktop`).

Configuration : `~/.config/pedalier/env`, créé au bootstrap et jamais écrasé
ensuite (les nouveautés du modèle arrivent en `env.new` avec un avertissement).

## Points à connaître

**Le script distant tourne depuis `/tmp`, pas depuis le dépôt cloné.** Bash lit
un script par blocs à la demande : si un `git merge` réécrit le fichier en cours
d'exécution, le shell se met à lire du charabia.

**pdjson a besoin du lien à plat `~/pd-externals/pdjson.pd_lua`.** Aucune version
de Pd testée (0.53 comme 0.55) n'applique la convention de dossier aux `.pd_lua` :
elles cherchent `pdjson/pdjson.pd_linux` et `pdjson/pdjson.pd`, jamais
`pdjson/pdjson.pd_lua`. Le lien est posé par la phase `externals`.

**Les morceaux sont écrits par Pd dans l'arbre git de `puredata-abstractions`.**
La phase `repos` les met en `skip-worktree` pour que les mises à jour cessent de
leur passer dessus, et `songs save` archive tout avant la moindre opération git.

**`apt install npm` est simulé avant d'être exécuté** : le paquet Debian peut
vouloir aligner `nodejs` sur la version de la distribution, ce qui casserait le
node 18 en place. En cas de refus, `pedalier-deploy.sh node-modules` pousse
`node_modules/` depuis le Mac (express est du JS pur, portable vers aarch64).

**Pd ouvre sa sortie audio une seule fois, au chargement du patch.** Si aucune
sortie réelle n'existe à cet instant — le casque Bluetooth met quelques secondes
à être joint au démarrage à froid — il boucle sur
`alsa xrun recovery apparently failed` et cette boucle le monopolise : il cesse
de répondre au WebSocket, et le pédalier entier devient inutilisable, pas
seulement muet. `wait-audio.sh`, en `ExecStartPre`, attend un sink PipeWire
pendant 30 s au plus, puis laisse Pd démarrer de toute façon — le MIDI et le
WebSocket, eux, ne dépendent pas du son. Même contrat que `wait-network.sh`,
qui attend l'adresse IP pour la même raison : les sockets UDP vers les sirènes
sont ouvertes une fois pour toutes.

**Pas de montage audio intermédiaire.** Un sink null permanent doublé d'un
`module-loopback` vers le casque a été essayé pour que Pd ait toujours une
cible : ni le `target.object` du loopback ni le `playback_node` d'un
`~/.asoundrc` n'ont été honorés par wireplumber, qui a rebranché la capture sur
le *monitor* du casque — donc un larsen. Pd écrit directement sur `default`,
c'est-à-dire la sortie du moment.

**Pure Data 0.55.2 est compilé dans `/usr/local`**, le 0.53 de Debian reste en
`/usr/bin/pd`. Repli d'une ligne dans `~/.config/pedalier/env` :
`PEDALIER_PD_BIN=/usr/bin/pd`.
