# Firmware du pupitre — dépendance à NiDMI

Ce dossier contient de quoi mettre en service la carte **XIAO ESP32-S3** qui lit les contrôles
physiques du pupitre (pads, joystick, fader, pédale, bouton) et les envoie
au reste du système.

Il ne contient **aucun code source** : le firmware est construit dans un autre dépôt,
**[NiDMI](https://github.com/patricecolet/NiDMI)**, et seuls ses binaires sont versionnés ici.
C'est cette dépendance que la section suivante décrit.

## Ce dont ce dossier dépend

**NiDMI** est une bibliothèque Arduino pour ESP32-C3/S3 : elle expose un serveur HTTP+WebSocket
et une interface web de configuration (pins, composants, MIDI, OSC), avec persistance en NVS.
Le pupitre n'en est qu'un *utilisateur* : on y déclare quel capteur est câblé sur quelle broche
et vers quel message MIDI/OSC il part, et NiDMI fait le reste.

Dépôt : <https://github.com/patricecolet/NiDMI> — à cloner en frère de `mecaviv-qml-ui` :

```bash
git clone https://github.com/patricecolet/NiDMI.git ~/repo/NiDMI
```

```
repo/
├── NiDMI/                       ← le firmware (source, build, doc)
└── mecaviv-qml-ui/
    └── SirenePupitre/
        └── firmware/            ← CE DOSSIER : binaires + config + scripts
```

Ce clone n'est nécessaire que **pour reconstruire** un binaire. Pour flasher une carte à partir
de ce qui est déjà versionné ici, il ne l'est pas.

### Variante du firmware : `usbmidi-on + usb-net`

NiDMI se compile en plusieurs variantes ; celle embarquée ici est **USB-MIDI activé + usb-net** :

- l'ESP32-S3 apparaît sur le Mac/Pi comme un **port MIDI USB** *et* comme une **carte réseau USB**
  (CDC-NCM, nommée `nidmi`) ;
- l'interface web est servie **par le câble USB**, à `http://192.168.7.1` — la carte fait le DHCP
  sur ce lien et prend `192.168.7.1`, l'hôte reçoit `192.168.7.2` ;
- il n'y a **plus de port série** tant que ce firmware tourne : l'USB est pris par le MIDI et le
  réseau. C'est le principal effet de bord à connaître (voir *Pièges*).

L'AP Wi-Fi (`192.168.4.1`) reste disponible en parallèle, mais l'intérêt de cette variante est
justement de ne plus en dépendre.

Reconstruire ce binaire depuis le dépôt NiDMI :

```bash
cd ../../../NiDMI
./scripts/nidmi.sh build --board s3 --variant on --usb-net --ota
cp bin/nidmi_basic.ino.bootloader.bin  ../mecaviv-qml-ui/SirenePupitre/firmware/bin/nidmi-s3-usbnet.bootloader.bin
cp bin/nidmi_basic.ino.partitions.bin  ../mecaviv-qml-ui/SirenePupitre/firmware/bin/nidmi-s3-usbnet.partitions.bin
cp bin/nidmi-s3-usbmidi-on-usbnet.bin  ../mecaviv-qml-ui/SirenePupitre/firmware/bin/nidmi-s3-usbnet.app.bin
```

Puis mettre `bin/VERSION` à jour — c'est le seul endroit qui trace quelle version du firmware
est effectivement dans ce dossier.

## Contenu

| Fichier | Rôle |
|---|---|
| `bin/nidmi-s3-usbnet.bootloader.bin` | bootloader, flashé à `0x0` |
| `bin/nidmi-s3-usbnet.partitions.bin` | table de partitions, `0x8000` |
| `bin/nidmi-s3-usbnet.app.bin` | application, `0x10000` (slot `app0`) |
| `bin/gyrophone-pad.nvs.bin` | **configuration** du pupitre, `0x9000` (20 Ko) |
| `bin/VERSION` | provenance des binaires ci-dessus |
| `nvs/gyrophone-pad.csv` | source de l'image NVS |
| `nvs/pins/*.json` | une config par broche, référencée par le CSV |
| `scripts/flash.sh` | flashe firmware + NVS sur la carte |
| `scripts/build-nvs.sh` | régénère `gyrophone-pad.nvs.bin` depuis le CSV |

## Mise en service d'une carte

```bash
./scripts/flash.sh              # firmware + config, carte neuve
./scripts/flash.sh --fw-only    # met à jour le firmware, garde la config de la carte
./scripts/flash.sh --nvs-only   # remet la config du pupitre, garde le firmware
```

Ensuite : `http://192.168.7.1` par le câble (ou `http://pupitre.local`).

## La configuration NVS

La NVS est la mémoire non volatile de l'ESP32 : c'est là que NiDMI range le rôle de chaque
broche, les réglages OSC et le nom réseau. Ici elle n'est pas saisie à la main dans l'interface
web puis oubliée — elle est **décrite dans `nvs/`, versionnée, et régénérable** :

```
nvs/gyrophone-pad.csv + nvs/pins/*.json  ──build-nvs.sh──▶  bin/gyrophone-pad.nvs.bin (20 Ko)
                                                                      │ flash.sh @0x9000
                                                                      ▼
                                                            carte configurée au 1er boot
```

`build-nvs.sh` s'appuie sur `nvs_partition_gen.py`, fourni par l'**ESP-IDF** (paquet python
`esp_idf_nvs_partition_gen`). C'est la seule dépendance supplémentaire, et elle n'est nécessaire
que pour *régénérer* l'image — pas pour flasher.

### Mapping — capturé depuis la carte de référence

Relevé le 2026-08-25 sur la carte du pupitre. `GET /api/pins/list` renvoie les chaînes NVS telles
quelles : les fichiers de `nvs/pins/` en sont la copie exacte, vérifiée à l'octet près.

| Broche | Nom | Composant | MIDI (canal 1) | Adresse OSC | Sens |
|---|---|---|---|---|---|
| `A8` | joystick | `joystick3` | CC 1 / CC 2 / CC 3 (X/Y/Z) | `/joystick` | sortie |
| `A0` | pedale | `potentiometer` | CC 11 | `/pedale` | sortie |
| `A1` | slider | `potentiometer` | CC 7 | `/slider` | sortie |
| `A3` | pad1 | `velostat` | note 61 + key pressure | `/pad1` | sortie |
| `A4` | pad2 | `velostat` | note 62 + key pressure | `/pad2` | sortie |
| `D2` | Bouton 1 | `button` | note 60, vél. 100 | `/joystick/bouton` | sortie |
| `D5` | LED 1 | `led` | note 61 | `/pad1/led` | **entrée** |
| `D7` | LED 2 | `led` | note 62 | `/pad2/led` | **entrée** |

Les LED sont des **entrées** : elles réagissent à ce que Pd leur envoie. Pads et LED partagent
volontairement leurs notes (61, 62), de sorte qu'une frappe allume la LED correspondante — d'où
l'intérêt de piloter les LED en OSC (`/pad1/led`) plutôt qu'en MIDI, pour éviter la boucle.

Le firmware ajoute lui-même le suffixe d'axe aux composants multi-axes : l'adresse `/joystick`
de `A8` produit `/joystick/x`, `/joystick/y` et `/joystick/z`.

`A0` est déclarée mais la pédale n'est pas câblée : le firmware la détecte comme pin flottante et
coupe son envoi MIDI/OSC au démarrage. C'est le comportement attendu, pas une erreur de config.

L'image porte aussi les réglages système de la carte, dont `rt_slice = 8` — le nombre de composants
traités par cycle de la tâche temps réel. Avec ces 8 composants, cela ramène la revisite de chacun
de 20 à 10 ms, soit ~5 ms de moins sur la latence d'une frappe (défaut NiDMI : 4).

Pour changer le mapping : éditer le JSON de la broche dans `nvs/pins/`, relancer
`./scripts/build-nvs.sh`, puis `./scripts/flash.sh --nvs-only`.

L'autre méthode, plus sûre quand on découvre un composant : régler la carte à la main dans
l'interface web, vérifier que ça marche, **puis** reporter le résultat dans `nvs/` pour le figer.

## Pièges

**Une carte qui tourne déjà ce firmware n'a pas de port série.** L'USB est pris par le MIDI et le
réseau. Pour la reflasher il faut la passer en mode téléchargement à la main : maintenir **BOOT**,
appuyer/relâcher **RESET**, relâcher **BOOT**. Une carte neuve, elle, est reconnue directement.

**Flasher la NVS efface la configuration présente sur la carte.** C'est voulu à la mise en service,
mais destructeur sur une carte déjà réglée par quelqu'un. Pour une simple mise à jour de firmware :
`--fw-only`, ou l'OTA (voir ci-dessous).

**L'OTA ne peut pas transporter la configuration.** La mise à jour par Wi-Fi n'écrit que la
partition applicative — par construction elle ne touche jamais la NVS. Donc : **câble** pour la
mise en service d'une carte neuve, **OTA** pour les mises à jour ensuite.

**Le nom réseau est dans l'image.** `mdns_name` / `rtp_name` valent `pupitre` dans le CSV : deux
cartes flashées avec cette image seraient toutes deux `pupitre.local`. Sans conséquence par USB —
chaque carte est son propre réseau `192.168.7.1` — mais elles se collisionneraient sur le Wi-Fi.
Pour une flotte, retirer ces clés du CSV et laisser NiDMI dériver un nom par défaut, ou produire
une image par carte.

**Les offsets sont dupliqués.** `scripts/flash.sh` code en dur `0x0 / 0x8000 / 0x9000 / 0x10000`,
qui viennent de `NiDMI/tools/nidmi_s3_ota_dual_littlefs.csv`. Si cette table change côté NiDMI,
il faut les reporter ici — rien ne le détecte automatiquement.
