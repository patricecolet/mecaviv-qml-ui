# Carte radio ATIM ARM-Nano 08/2014 RPI 1.3

Guide pour faire fonctionner la carte radio ATIM ARM-Nano sur le Raspberry Pi du projet SirenePupitre.

## Vue d'ensemble

La **carte ATIM ARM-Nano** est une carte d'extension radio pour Raspberry Pi permettant :
- **Réseau local** : communication point-à-point 868 MHz (LoRa-like) entre pupitres
- **Sigfox** : envoi de données vers le cloud Sigfox (si module Sigfox)

Variantes possibles (selon votre module soudé) :
- **N4** : 433 MHz
- **N8LP** : 868 MHz faible puissance (Sigfox compatible)
- **N8LD** : 868 MHz longue distance (500 mW)
- **N8LW** : 868 MHz LoRaWAN

L'interface utilise **UART** (série) pour communiquer avec le module.

---

## 1. Connexion matérielle

La carte se fixe sur les GPIO du Raspberry Pi. Référence : [pi_arm_nano.pdf](https://github.com/atim-radiocommunications/rpi-nano/blob/master/hw/pi_arm_nano.pdf)

| RPi GPIO | Fonction ATIM |
|----------|---------------|
| Pin 8 (GPIO 14) | UART TX → RX module |
| Pin 10 (GPIO 15) | UART RX ← TX module |
| Pin 6 | GND |
| Pin 1 (3.3V) | VCC (3.3V uniquement) |
| Autre | Reset (GPIO, géré par la lib) |

**Important** : Vérifiez l'orientation de la carte. La documentation ATIM (PDF hw/) indique les broches exactes.

---

## 2. Activation de l'UART sur Raspberry Pi

### Raspberry Pi 4 / 5

Le port série principal est sur `/dev/ttyS0` (mini UART) ou `/dev/ttyAMA0` selon la config.

Éditer `/boot/firmware/config.txt` (ou `/boot/config.txt` sur anciennes versions) :

```ini
# Activer l'UART
enable_uart=1

# Optionnel : forcer le UART principal sur les pins 8/10 (PL011)
# dtoverlay=disable-bt
# Sur Pi 4/5, le UART par défaut peut être ttyS0
```

Désactiver la console série si elle utilise l'UART (pour libérer le port) :

```bash
# Vérifier si getty utilise ttyS0 ou ttyAMA0
sudo raspi-config
# Interface Options → Serial Port
# - Enable serial port hardware : Yes
# - Login over serial : No  (important : libérer l'UART pour l'application)
```

Ou manuellement :

```bash
# Désactiver la console sur le port série
sudo systemctl disable serial-getty@ttyS0.service
sudo systemctl disable serial-getty@ttyAMA0.service
```

Redémarrer : `sudo reboot`

### Vérifier le port UART

Sur le Raspberry Pi, après redémarrage :

```bash
ls -la /dev/tty*
# Rechercher ttyAMA0, ttyS0, ou ttyUSB0 (si adaptateur USB-série)
```

Sur **Raspberry Pi 3/4/5**, l’UART principal est souvent `/dev/ttyS0`. La lib rpi-nano utilise par défaut `/dev/ttyAMA0` — si votre Pi n’a que `ttyS0`, il faudra passer ce chemin à `rpi_nano_init()`.

---

## 3. Permissions

L’utilisateur doit pouvoir accéder au port série :

```bash
# Option 1 : ajouter l’utilisateur au groupe dialout
sudo usermod -aG dialout $USER

# Option 2 : règle udev pour un accès direct
echo 'KERNEL=="ttyAMA[0-9]*", MODE="0666"' | sudo tee /etc/udev/rules.d/99-tty.rules
echo 'KERNEL=="ttyS[0-9]*", MODE="0666"' | sudo tee -a /etc/udev/rules.d/99-tty.rules
sudo udevadm control --reload-rules

# Se déconnecter/reconnecter (ou reboot) pour appliquer le groupe
```

---

## 4. Logiciel : bibliothèque rpi-nano

ATIM fournit une lib C : [rpi-nano](https://github.com/atim-radiocommunications/rpi-nano).

**Note** : Le README recommande **armapi** pour les modules plus récents (N8-LW, N8-LD, N8-LP). Pour une carte 2014 avec ARM-Nano 1.3, **rpi-nano** est adapté.

### Installation sur le Raspberry Pi

```bash
cd /home/sirenateur
git clone https://github.com/atim-radiocommunications/rpi-nano.git
cd rpi-nano
make
```

Le `makefile` fourni compile les exemples. Vérifier les chemins UART dans le code si besoin (`/dev/ttyAMA0` vs `/dev/ttyS0`).

---

## 5. Script de diagnostic

Un script `SirenePupitre/scripts/atim-diagnostic.sh` est fourni pour vérifier :

- Présence de `/dev/ttyAMA0`, `/dev/ttyS0`, `/dev/ttyUSB0`
- Droit d’accès au port série
- Activation de l’UART dans la config du boot
- Présence de la lib rpi-nano

**Exécution** (depuis le Pi ou via SSH) :

```bash
cd /home/sirenateur/dev/src/mecaviv/mecaviv-qml-ui/SirenePupitre
./scripts/atim-diagnostic.sh
```

---

## 6. Test minimal avec rpi-nano

Sur le Raspberry Pi, avec la carte ATIM branchée :

```bash
cd ~/rpi-nano
# Adapter le device dans les exemples si ttyS0 au lieu de ttyAMA0
make
./exemples/bin/example_get_version
```

Si le module répond, vous verrez la version (N4, N8LP, N8LD).

### Test Ping-Pong (2 cartes)

Pour tester la liaison radio entre deux pupitres :

1. Configurer les deux cartes sur le même canal.
2. Une en mode Master, l’autre en Slave.
3. Lancer le test ping-pong fourni dans les exemples rpi-nano.

---

## 7. Intégration SirenePupitre (piste)

Cas d’usage possible : communication radio entre pupitres quand Ethernet/WiFi n’est pas disponible.

Options d’intégration :

1. **Service Node.js** : petit processus qui utilise la lib C via `child_process` ou un binaire natif (binding N-API / FFI).
2. **Exécutable C** : démon qui lit l’UART, envoie les trames reçues en UDP/localhost au serveur Node existant.
3. **PureData** : abstraction PureData communiquant avec un exécutable ou un FIFO.

Le protocole actuel (WebSocket binaire 0x01, 0x02, etc.) pourrait être encapsulé dans les paquets radio (avec CRC, séquence, etc.).

---

## 8. Dépannage

| Problème | Piste de résolution |
|----------|---------------------|
| Permission denied sur /dev/tty* | `usermod -aG dialout` ou règle udev |
| Device not found | Vérifier `enable_uart=1`, désactiver console série |
| Pas de réponse du module | Vérifier alimentation 3.3V, câblage TX/RX, orientation de la carte |
| Mauvais device | Tester avec `ttyS0` au lieu de `ttyAMA0` dans le code |
| ARMv7l / 32-bit | Rpi-nano est en C, compatible ARMv7. Pas de souci lié à Cursor. |

---

## Références

- [rpi-nano GitHub](https://github.com/atim-radiocommunications/rpi-nano)
- [armapi GitHub](https://github.com/atim-radiocommunications/armapi) (modules plus récents)
- [ATIM ARM-Nano](https://www.atim.com/en/radio-modules-extension-cards/)
- [Documentation hw pi_arm_nano](https://github.com/atim-radiocommunications/rpi-nano/blob/master/hw/pi_arm_nano.pdf)
