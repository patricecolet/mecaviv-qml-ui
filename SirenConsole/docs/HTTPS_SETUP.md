# Configuration HTTPS pour SirenConsole

## 🔒 Options de certificats SSL

### Option 1 : mkcert (Recommandé pour localhost)

**mkcert** génère des certificats reconnus localement par votre navigateur (pas d'avertissement).

#### Installation sur macOS
```bash
brew install mkcert
brew install nss  # Pour Firefox
```

#### Configuration
```bash
# Créer une autorité de certification locale
mkcert -install

# Générer les certificats pour localhost
cd SirenConsole/webfiles/ssl
mkcert localhost 127.0.0.1 ::1

# Renommer les fichiers générés
mv localhost+2.pem cert.pem
mv localhost+2-key.pem key.pem
```

#### Avantages
- ✅ Pas d'avertissement dans le navigateur
- ✅ Fonctionne avec tous les navigateurs
- ✅ Simple à configurer
- ✅ Idéal pour le développement local

---

### Option 2 : Let's Encrypt (Pour production avec nom de domaine)

**Let's Encrypt** nécessite :
- Un nom de domaine public (ex: `sirenconsole.example.com`)
- Le serveur accessible depuis Internet
- Port 80 ouvert pour la validation

#### Installation de certbot
```bash
# macOS
brew install certbot

# Linux (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install certbot
```

#### Configuration avec certbot (mode standalone)
```bash
# Arrêter le serveur SirenConsole temporairement
# Certbot a besoin du port 80

# Obtenir le certificat
sudo certbot certonly --standalone -d sirenconsole.example.com

# Les certificats seront dans :
# /etc/letsencrypt/live/sirenconsole.example.com/fullchain.pem
# /etc/letsencrypt/live/sirenconsole.example.com/privkey.pem
```

#### Configuration dans server.js
```bash
export SSL_CERT_PATH=/etc/letsencrypt/live/sirenconsole.example.com/fullchain.pem
export SSL_KEY_PATH=/etc/letsencrypt/live/sirenconsole.example.com/privkey.pem
export USE_HTTPS=true
```

#### Renouvellement automatique
```bash
# Tester le renouvellement
sudo certbot renew --dry-run

# Ajouter au crontab pour renouvellement automatique
sudo crontab -e
# Ajouter :
0 0 * * * certbot renew --quiet && systemctl reload sirenconsole
```

#### Avantages
- ✅ Certificat signé par une autorité reconnue
- ✅ Gratuit
- ✅ Pas d'avertissement dans les navigateurs
- ✅ Idéal pour la production

#### Limitations
- ❌ Nécessite un nom de domaine public
- ❌ Nécessite un accès Internet
- ❌ Ne fonctionne pas pour localhost ou IPs privées

---

### Option 3 : Certificat auto-signé (Actuel)

Le certificat auto-signé actuel fonctionne mais affiche un avertissement.

#### Configuration pour accès local ET distant

Le certificat actuel est configuré pour fonctionner avec :
- `localhost` (accès local)
- `127.0.0.1` (accès local)
- `192.168.1.190` (accès distant via IP)
- Hostname de la machine (`patmac`)

#### Régénérer le certificat avec votre IP

Si votre IP change ou pour ajouter d'autres IPs :

```bash
cd SirenConsole/webfiles/ssl

# Récupérer votre IP locale
MY_IP=$(ipconfig getifaddr en0 2>/dev/null || ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
MY_HOSTNAME=$(hostname)

# Régénérer le certificat
rm -f key.pem cert.pem
openssl req -x509 -newkey rsa:4096 \
  -keyout key.pem \
  -out cert.pem \
  -days 365 \
  -nodes \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,DNS:${MY_HOSTNAME},IP:127.0.0.1,IP:${MY_IP}"

# Redémarrer le serveur
```

#### Avantages
- ✅ Simple (déjà configuré)
- ✅ Fonctionne immédiatement
- ✅ Fonctionne en local ET distant
- ✅ Pas de dépendances externes

#### Inconvénients
- ❌ Avertissement dans le navigateur (normal pour certificat auto-signé)
- ❌ Nécessite d'accepter l'exception manuellement sur chaque machine

---

## 🔧 Configuration actuelle

Le serveur utilise par défaut les certificats dans `SirenConsole/webfiles/ssl/` :
- `key.pem` : Clé privée
- `cert.pem` : Certificat

### Variables d'environnement

```bash
# Activer/désactiver HTTPS
export USE_HTTPS=true   # Par défaut activé
export USE_HTTPS=false  # Désactiver (HTTP)

# Chemins personnalisés
export SSL_KEY_PATH=/chemin/vers/key.pem
export SSL_CERT_PATH=/chemin/vers/cert.pem
```

---

## 📝 Recommandations

### Pour le développement local uniquement
👉 Utilisez **mkcert** (Option 1) pour éviter les avertissements

### Pour l'accès local ET distant (réseau local)
👉 Utilisez le **certificat auto-signé** (Option 3) avec votre IP locale
   - Le certificat actuel inclut déjà `localhost`, `127.0.0.1` et votre IP locale
   - Fonctionne sur `https://localhost:8001` ET `https://192.168.1.190:8001`

### Pour la production avec nom de domaine public
👉 Utilisez **Let's Encrypt** (Option 2) pour un certificat reconnu

### Pour les tests rapides
👉 Gardez le certificat auto-signé actuel (Option 3)

---

## 🚀 Migration vers mkcert (Recommandé)

```bash
# 1. Installer mkcert
brew install mkcert
brew install nss

# 2. Créer l'autorité locale
mkcert -install

# 3. Générer les nouveaux certificats
cd SirenConsole/webfiles/ssl
rm key.pem cert.pem  # Supprimer les anciens
mkcert localhost 127.0.0.1 ::1
mv localhost+2.pem cert.pem
mv localhost+2-key.pem key.pem

# 4. Redémarrer le serveur
# Plus besoin d'accepter l'avertissement !
```

