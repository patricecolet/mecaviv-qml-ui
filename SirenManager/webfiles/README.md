# SirenManager - Fichiers WebAssembly

Fichiers compilés pour WebAssembly de SirenManager.

## Démarrage du serveur

```bash
npm install
node server.js
```

Puis ouvrez dans votre navigateur :
- http://localhost:8080/appSirenManager.html

## Backend SSH

Pour utiliser les fonctionnalités SSH (maintenance système), démarrez aussi le backend :

```bash
cd ../backend
npm install
node server.js
```

Le backend écoute sur :
- HTTP: http://localhost:8005
- WebSocket: ws://localhost:8006

## Fichiers

- `appSirenManager.html` - Page HTML principale
- `appSirenManager.js` - JavaScript généré
- `appSirenManager.wasm` - Module WebAssembly
- `qtloader.js` - Chargeur Qt pour WebAssembly
- `server.js` - Serveur de développement Node.js


