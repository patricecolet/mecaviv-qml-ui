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
| `bin/pupitre-test.nvs.bin` | **configuration** du pupitre, `0x9000` (20 Ko) |
| `bin/VERSION` | provenance des binaires ci-dessus |
| `nvs/pupitre-test.csv` | source de l'image NVS |
| `nvs/pins/*.json` | une config par broche, référencée par le CSV |
| `scripts/flash.sh` | flashe firmware + NVS sur la carte |
| `scripts/build-nvs.sh` | régénère `pupitre-test.nvs.bin` depuis le CSV |

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
nvs/pupitre-test.csv + nvs/pins/*.json  ──build-nvs.sh──▶  bin/pupitre-test.nvs.bin (20 Ko)
                                                                      │ flash.sh @0x9000
                                                                      ▼
                                                            carte configurée au 1er boot
```

`build-nvs.sh` s'appuie sur `nvs_partition_gen.py`, fourni par l'**ESP-IDF** (paquet python
`esp_idf_nvs_partition_gen`). C'est la seule dépendance supplémentaire, et elle n'est nécessaire
que pour *régénérer* l'image — pas pour flasher.

### Mapping actuel — **provisoire**

Le câblage ci-dessous est un **jeu de test à confirmer sur la carte réelle** : il couvre les
contrôles du message binaire `0x02 CONTROLLERS` (voir `../STRUCTURE_BINAIRE_0x02.md`), mais les
numéros de broches n'ont pas été relevés sur le pupitre monté.

| Broche | GPIO | Contrôle | Composant NiDMI | MIDI |
|---|---|---|---|---|
| D0 | 1 | Fader | `potentiometer` | CC 7, canal 1 |
| D1 | 2 | Pédale | `potentiometer` | CC 11, canal 1 |
| D2 | 3 | Pad 1 | `velostat` | Note 60 + key pressure |
| D3 | 4 | Pad 2 | `velostat` | Note 62 + key pressure |
| D4 | 5 | Bouton 1 | `button` | Note 36 |
| D8 | 7 | Joystick X (Y=GPIO 8, Z=GPIO 9) | `joystick3` | CC 16 / 17 / 18 |


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
