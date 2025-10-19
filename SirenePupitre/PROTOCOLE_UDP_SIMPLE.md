# Protocole UDP Simple - TinyYellowBird

## Vue d'ensemble

Le protocole UDP Simple est un système de communication réseau développé pour le contrôle à distance des périphériques TinyYellowBird. Il permet de contrôler les LEDs et les sliders via des commandes UDP binaires et ASCII.

## Architecture

### Port de communication
- **Port UDP** : 5000
- **Protocole** : UDP/IP
- **Authentification** : Requise pour toutes les commandes

### Structure des pairs
- **Maximum** : 10 pairs connectés simultanément
- **Gestion** : Table des pairs avec timestamp de dernière activité
- **Nettoyage** : Pairs inactifs remplacés automatiquement

## Authentification

### Format ASCII
```
AUTH:KRAKEN
```

### Format Test (mode développement)
```
TESTPUPITRE
```

### Réponse
```
AUTH:OK
```

## Commandes disponibles

### 1. Commande SET (Format binaire)

#### Format
```
SET[LED1][LED2][SLIDER1][RFU]
```

#### Description
Commande binaire compacte pour contrôler simultanément tous les périphériques.

#### Paramètres
- **LED1** (1 octet) : État de la LED 1 (0 = OFF, 1 = ON)
- **LED2** (1 octet) : État de la LED 2 (0 = OFF, 1 = ON)
- **SLIDER1** (1 octet) : Position du slider 1 (0-127)
- **RFU** (1 octet) : Réservé pour usage futur (0-255)

#### Exemple
```hex
SET 01 00 64 FF
```
- LED1 = ON
- LED2 = OFF
- SLIDER1 = Position 100
- RFU = 255

#### Réponse
```
SET:OK:1:0:100:255
```

### 2. Commande LED (Format ASCII)

#### Format
```
LED:x:y
```

#### Description
Contrôle individuel des LEDs.

#### Paramètres
- **x** : Numéro de LED (1 ou 2)
- **y** : État (0 = OFF, 1 = ON)

#### Exemples
```
LED:1:1    # Allumer LED 1
LED:2:0    # Éteindre LED 2
```

#### Réponse
```
LED:OK:1:1
```

### 3. Commande SLIDER (Format ASCII)

#### Format
```
SLIDER:xxx
```

#### Description
Contrôle individuel du slider.

#### Paramètres
- **xxx** : Position cible (0-127)

#### Exemples
```
SLIDER:64    # Position centrale
SLIDER:0     # Position minimale
SLIDER:127   # Position maximale
```

#### Réponse
```
SLIDER:OK:64
```

## Gestion des erreurs

### Erreurs de format
```
SET:ERROR:Invalid format (expected SET + 4 bytes)
LED:ERROR:Invalid format (use LED:1:1 or LED:2:0)
SLIDER:ERROR:Invalid position 150 (0-127)
```

### Erreurs de validation
```
SET:ERROR:Invalid LED state (must be 0 or 1)
SET:ERROR:Invalid slider position (must be 0-127)
LED:ERROR:Invalid LED number 3 (1 or 2)
LED:ERROR:Invalid state 2 (0 or 1)
```

## Format des données de capteurs

### Format ASCII
```
DATA:P[123]|D1[045]|D2[067]|Eev[089;12]|Jxyzb[123;456;789;1]|S[2]|F1[234]|F2[567]
```

### Format binaire
- **Structure** : `sensors_values_t` + 1B taille structure

```C
// Structure pour stocker les valeurs des capteurs
typedef  struct __attribute__((packed)) {
	uint32_t 	absolute_encoder;
    int16_t 	encoder;
    int16_t 	velocity;
	uint16_t 	absolute_force1;  // Force continue actuelle drum 1 (0-127)
	uint16_t 	absolute_force2;  // Force continue actuelle drum 2 (0-127)
	uint8_t 	drum1;          // Force de frappe détectée drum 1 (0-127)
	uint8_t 	drum2;          // Force de frappe détectée drum 2 (0-127)
    int8_t 		joystick_x;
    int8_t 		joystick_y;
    int8_t 		joystick_z;
    uint8_t 	joystick_button;
    uint8_t 	selecter;
	int16_t 	ext_adc0;
	int16_t 	ext_adc1;
	uint8_t 	ext_button1;  // Bouton 1 d'extension (0=relâché, 1=appuyé)
	uint8_t 	ext_button2;  // Bouton 2 d'extension (0=relâché, 1=appuyé)
} sensors_values_t;
```


- **Avantage** : Plus compact, moins de traitement

## Exemples d'utilisation

### Client Python (exemple)
```python
import socket

# Connexion
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

# Authentification
sock.sendto(b"AUTH:KRAKEN", ("192.168.1.100", 5000))
response = sock.recv(1024)
print(f"Auth: {response.decode()}")

# Commande SET binaire
set_command = b"SET" + bytes([1, 0, 64, 0])  # LED1=ON, LED2=OFF, SLIDER=64, RFU=0
sock.sendto(set_command, ("192.168.1.100", 5000))
response = sock.recv(1024)
print(f"SET: {response.decode()}")

# Commande LED ASCII
sock.sendto(b"LED:1:1", ("192.168.1.100", 5000))
response = sock.recv(1024)
print(f"LED: {response.decode()}")

# Commande SLIDER ASCII
sock.sendto(b"SLIDER:100", ("192.168.1.100", 5000))
response = sock.recv(1024)
print(f"SLIDER: {response.decode()}")
```

### Client JavaScript (exemple)
```javascript
const dgram = require('dgram');
const client = dgram.createSocket('udp4');

// Authentification
client.send('AUTH:KRAKEN', 5000, '192.168.1.100');

// Commande SET binaire
const setCommand = Buffer.concat([
    Buffer.from('SET'),
    Buffer.from([1, 0, 64, 0])
]);
client.send(setCommand, 5000, '192.168.1.100');

// Commande LED ASCII
client.send('LED:1:1', 5000, '192.168.1.100');

// Commande SLIDER ASCII
client.send('SLIDER:100', 5000, '192.168.1.100');
```

## Spécifications techniques

### Buffers
- **Réception** : 512 octets maximum
- **Envoi** : 256 octets maximum
- **Pairs** : 10 maximum

### Timeouts
- **Dernière activité** : Géré par `HAL_GetTick()`
- **Nettoyage** : Automatique des pairs inactifs

### Performance
- **Envoi simultané** : Protection contre les envois concurrents
- **Optimisation** : `__attribute__((optimize("O0")))` pour la fonction d'envoi

## Sécurité

### Authentification
- **Clé** : "KRAKEN" (en dur)
- **Mode test** : "TESTPUPITRE" (désactive certaines validations)

### Validation
- **Format** : Vérification stricte des commandes
- **Valeurs** : Validation des plages de valeurs
- **Taille** : Vérification de la taille des paquets

## Dépannage

### Problèmes courants
1. **Authentification échouée** : Vérifier la clé "KRAKEN"
2. **Commande ignorée** : Vérifier le format exact
3. **Pas de réponse** : Vérifier la connectivité réseau
4. **Paquet trop grand** : Réduire la taille des données

### Logs de débogage
```
Communication UDP simple initialisée sur le port 5000
Nouveau pair ajouté: 192.168.1.100:5000
Commande SET reçue: LED1=1, LED2=0, SLIDER1=64, RFU=0
SET command executed: LED1=1, LED2=0, SLIDER1=64, RFU=0
```

## Évolutions futures

### RFU (Reserved For Future Use)
Le quatrième octet de la commande SET est réservé pour :
- Nouveaux périphériques
- Paramètres additionnels
- Fonctionnalités étendues

## Références

- **Code source** : `Appli/Core/Src/simple_udp.c`
- **En-têtes** : `Appli/Core/Inc/simple_udp.h`
- **Implémentation** : `Appli/Core/Src/main.c`
- **LWIP** : Stack réseau utilisée
- **STM32H7RSxx** : Microcontrôleur cible
