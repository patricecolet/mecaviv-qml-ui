const http = require('http');
const fs = require('fs');
const path = require('path');

// Importer l'API des presets
const presetAPI = require('./api-presets.js');

// Importer l'API MIDI
const midiAPI = require('./api-midi.js');

// Importer le proxy PureData
const PureDataProxy = require('./puredata-proxy.js');

// Charger la configuration depuis config.json
const { loadConfig } = require('../../config-loader.js');
const config = loadConfig();

// Configuration du serveur
const PORT = 8001; // Port différent de SirenePupitre (8000)
const HOST = '0.0.0.0';

// Initialiser le proxy PureData
let pureDataProxy = null;

// Middleware pour les headers CORS et sécurité
function setSecurityHeaders(response) {
    // Headers CORS basiques
    response.setHeader('Access-Control-Allow-Origin', '*');
    response.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    response.setHeader('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization, Sec-WebSocket-Protocol, Sec-WebSocket-Version');
    response.setHeader('Vary', 'Origin');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    
    // Headers spécifiques pour WebSocket
    response.setHeader('Sec-WebSocket-Protocol', 'websocket');
    response.setHeader('Sec-WebSocket-Version', '13');
}

// Gestion des requêtes
const server = http.createServer(function (request, response) {
    console.log('📥 Requête:', request.method, request.url);
    
    // Appliquer les headers de sécurité
    setSecurityHeaders(response);
    
    // Gestion des requêtes OPTIONS (CORS preflight)
    if (request.method === 'OPTIONS') {
        response.writeHead(200);
        response.end();
        return;
    }

    // Gestion des routes
    let filePath = '.' + request.url;
    
    // Routes API pour les presets
    if (request.url.startsWith('/api/presets')) {
        // Rediriger vers l'API des presets
        presetAPI.app(request, response);
        return;
    }
    
    // Routes API MIDI
    if (request.url === '/api/midi/files') {
        midiAPI.getMidiFiles(request, response);
        return;
    }
    
    if (request.url === '/api/midi/categories') {
        midiAPI.getMidiCategories(request, response);
        return;
    }
    
    // Routes API PureData Proxy
    if (request.url === '/api/puredata/command' && request.method === 'POST') {
        let body = '';
        request.on('data', chunk => { body += chunk; });
        request.on('end', () => {
            try {
                const command = JSON.parse(body);
                const success = pureDataProxy.sendCommand(command);
                response.writeHead(success ? 200 : 503, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ success, message: success ? 'Commande envoyée' : 'PureData non connecté' }));
            } catch (e) {
                response.writeHead(400, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ success: false, error: e.message }));
            }
        });
        return;
    }
    
    if (request.url === '/api/puredata/status') {
        const status = pureDataProxy.getStatus();
        response.writeHead(200, { 'Content-Type': 'application/json' });
        response.end(JSON.stringify(status));
        return;
    }
    
    if (request.url.startsWith('/api/puredata/events')) {
        const url = new URL(request.url, `http://${request.headers.host}`);
        const since = parseInt(url.searchParams.get('since') || '0');
        const events = pureDataProxy.getEvents(since);
        response.writeHead(200, { 'Content-Type': 'application/json' });
        response.end(JSON.stringify({ events }));
        return;
    }
    
    if (request.url === '/api/puredata/playback') {
        const playbackState = pureDataProxy.getPlaybackState();
        response.writeHead(200, { 'Content-Type': 'application/json' });
        response.end(JSON.stringify(playbackState));
        return;
    }
    
    // Route principale
    if (request.url === '/' || request.url === '') {
        filePath = './appSirenConsole.html';
    }
    
    // Gestion des répertoires
    try {
        const stats = fs.statSync(filePath);
        if (stats.isDirectory()) {
            const indexPath = path.join(filePath, 'index.html');
            if (fs.existsSync(indexPath)) {
                filePath = indexPath;
            } else {
                response.writeHead(403);
                response.end('Directory listing not allowed');
                return;
            }
        }
    } catch (err) {
        // Le fichier/répertoire n'existe pas, continuer avec le traitement normal
    }

    // Types MIME
    const extname = String(path.extname(filePath)).toLowerCase();
    const mimeTypes = {
        '.html': 'text/html',
        '.js': 'text/javascript',
        '.css': 'text/css',
        '.json': 'application/json',
        '.png': 'image/png',
        '.jpg': 'image/jpg',
        '.wasm': 'application/wasm',
        '.svg': 'image/svg+xml'
    };

    const contentType = mimeTypes[extname] || 'application/octet-stream';

    // Lecture et envoi du fichier
    fs.readFile(filePath, function(error, content) {
        if (error) {
            console.error('❌ Erreur:', error.code, filePath);
            if(error.code == 'ENOENT'){
                response.writeHead(404);
                response.end('File Not Found');
            } else {
                response.writeHead(500);
                response.end('Server Error: ' + error.code);
            }
        } else {
            console.log('✅ Fichier servi:', filePath);
            response.writeHead(200, { 'Content-Type': contentType });
            response.end(content, 'utf-8');
        }
    });
});

// Initialiser l'API des presets et démarrer le serveur
presetAPI.initializePresetAPI().then(() => {
    // Initialiser le proxy PureData
    pureDataProxy = new PureDataProxy(config);
    
    server.listen(PORT, HOST, () => {
        console.log(`🚀 Serveur SirenConsole démarré sur http://${HOST}:${PORT}`);
        console.log(`🌐 Application principale sur http://localhost:${PORT}/appSirenConsole.html`);
        console.log(`🔌 Proxy WebSocket PureData: ${config.servers.websocketUrl}`);
        console.log(`📊 Console de contrôle des pupitres`);
        console.log(`💾 API Presets disponible sur http://localhost:${PORT}/api/presets`);
        console.log(`🎵 API MIDI disponible sur http://localhost:${PORT}/api/midi/files`);
        console.log(`🔀 API PureData Proxy sur http://localhost:${PORT}/api/puredata/*`);
    });
}).catch((error) => {
    console.error('❌ Erreur initialisation:', error);
    process.exit(1);
});