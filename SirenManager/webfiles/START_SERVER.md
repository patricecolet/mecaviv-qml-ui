# Démarrage du Serveur SirenManager

## Instructions rapides

### 1. Démarrer le serveur

```bash
cd /Users/patricecolet/repo/mecaviv-qml-ui/SirenManager/webfiles
node server.js
```

Le serveur utilisera le port **8081** par défaut (ou un autre si configuré).

**Pour utiliser un port différent :**
```bash
PORT=8082 node server.js
# ou
node server.js 8082
```

### 2. Ouvrir dans Firefox

**URL correcte (port par défaut : 8081) :**
```
http://localhost:8081/
```

ou directement :

```
http://localhost:8081/appSirenManager.html
```

## Problèmes courants

### "Click" s'affiche mais rien ne se charge

- Vérifiez que le serveur Node.js est bien démarré
- Vérifiez la console du navigateur (F12) pour les erreurs
- Assurez-vous d'utiliser le bon port : **8081** (ou celui indiqué par le serveur)
- Le port 8080 peut être déjà utilisé - le serveur utilise 8081 par défaut

### Erreur 404

- Vérifiez que vous utilisez l'URL complète : `http://localhost:8081/appSirenManager.html`
- Le nom de fichier est **appSirenManager.html** (pas "sirrenmanager.html")

### L'application ne se charge pas

- Ouvrez la console du navigateur (F12 → Console)
- Vérifiez les erreurs JavaScript
- Vérifiez que tous les fichiers sont présents dans webfiles/

## Fichiers nécessaires

- `appSirenManager.html` - Page HTML principale
- `appSirenManager.js` - JavaScript (492K)
- `appSirenManager.wasm` - WebAssembly (29M)
- `qtloader.js` - Chargeur Qt (16K)
- `qtlogo.svg` - Logo Qt

