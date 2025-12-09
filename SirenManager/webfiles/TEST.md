# Guide de dépannage SirenManager

## Problème : Vous voyez juste "click" ou une page blanche

### Étapes de diagnostic

1. **Vérifier que le serveur est démarré**
   ```bash
   cd /Users/patricecolet/repo/mecaviv-qml-ui/SirenManager/webfiles
   node server.js
   ```
   Vous devriez voir :
   ```
   🚀 SirenManager - Serveur de développement
   📡 HTTP: http://localhost:8080/
   ```

2. **Ouvrir la console du navigateur (IMPORTANT)**
   - Dans Firefox : `F12` ou `Cmd+Option+K` (Mac)
   - Allez dans l'onglet "Console"
   - Rechargez la page (`Cmd+R` ou `F5`)
   - Notez toutes les erreurs affichées

3. **Vérifier l'URL exacte**
   - ✅ CORRECT : `http://localhost:8080/appSirenManager.html`
   - ✅ CORRECT : `http://localhost:8080/` (redirige vers l'app)
   - ❌ INCORRECT : `localhost:8080` (sans http://)
   - ❌ INCORRECT : `localhost/sirrenmanager.html` (mauvais port, mauvais nom)

4. **Vérifier que tous les fichiers sont présents**
   ```bash
   cd /Users/patricecolet/repo/mecaviv-qml-ui/SirenManager/webfiles
   ls -lh *.html *.js *.wasm
   ```
   
   Vous devriez voir :
   - `appSirenManager.html` (~3KB)
   - `appSirenManager.js` (~500KB)
   - `appSirenManager.wasm` (~30MB)
   - `qtloader.js` (~12KB)
   - `qtlogo.svg` (si présent)

### Erreurs courantes

#### Erreur : "qtLoad is not defined"
- **Cause** : `qtloader.js` n'est pas chargé correctement
- **Solution** : Vérifiez que `qtloader.js` est présent dans webfiles/

#### Erreur : "appSirenManager_entry is not defined"
- **Cause** : `appSirenManager.js` n'est pas chargé
- **Solution** : Vérifiez que le fichier existe et que le serveur le sert correctement

#### Erreur : "Failed to fetch wasm"
- **Cause** : Le fichier `.wasm` n'est pas accessible
- **Solution** : Vérifiez que `appSirenManager.wasm` existe (30MB)

#### Erreur : "Cross-Origin" ou CORS
- **Cause** : Headers CORS manquants
- **Solution** : Le serveur devrait déjà gérer cela, mais vérifiez server.js

#### L'application reste sur "Loading..."
- **Cause** : Erreur silencieuse lors du chargement QML
- **Solution** : Vérifiez la console pour les erreurs QML

### Test rapide

Ouvrez cette URL dans votre navigateur :
```
http://localhost:8080/appSirenManager.html
```

Puis ouvrez la console (F12) et vérifiez :
1. Des messages de chargement apparaissent
2. Les fichiers `.js` et `.wasm` sont chargés (onglet Réseau)
3. Pas d'erreurs en rouge dans la console

### Si rien ne fonctionne

1. **Nettoyer et reconstruire** :
   ```bash
   cd /Users/patricecolet/repo/mecaviv-qml-ui/SirenManager
   ./scripts/build.sh
   ```

2. **Vérifier les logs du serveur** :
   Le serveur affiche chaque requête. Vérifiez qu'il répond bien.

3. **Tester avec un autre navigateur** :
   - Chrome/Chromium
   - Safari
   - Edge


