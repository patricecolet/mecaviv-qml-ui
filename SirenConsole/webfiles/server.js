const http = require('http');
const fs = require('fs');
const path = require('path');

// Importer l'API des presets
const presetAPI = require('./api-presets.js');

// Importer l'API MIDI
const midiAPI = require('./api-midi.js');

// Importer le proxy PureData
const PureDataProxy = require('./puredata-proxy.js');

// Importer l'analyseur MIDI
const { analyzeMidiFile, createFileInfoBuffer, createTempoBuffer, createTimeSigBuffer } = require('./midi-analyzer.js');

// Importer le séquenceur MIDI
const MidiSequencer = require('./midi-sequencer.js');

// Importer le moteur de jeu
const GameEngine = require('./game-engine.js');

// Charger la configuration depuis config.json
const { loadConfig } = require('../../config-loader.js');
const config = loadConfig();

// Chemin du répertoire MIDI
const MIDI_REPO_PATH = process.env.MECAVIV_COMPOSITIONS_PATH || config.paths.midiRepository;

// Configuration du serveur
const PORT = 8001; // Port différent de SirenePupitre (8000)
const HOST = '0.0.0.0';

// Initialiser le proxy PureData, le séquenceur, et le moteur de jeu
let pureDataProxy = null;
let midiSequencer = null;
let gameEngine = null;

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
    // Logs uniquement pour les requêtes intéressantes (pas les GET polling)
    if (request.method !== 'GET' || !request.url.includes('/api/puredata/playback')) {
        console.log('📥 Requête:', request.method, request.url);
    }
    
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
                
                // Traiter les commandes MIDI
                let success = false;
                let message = '';
                
                if (command.type === 'MIDI_FILE_LOAD' && command.path) {
                    console.log('📁 MIDI_FILE_LOAD:', command.path);
                    
                    // Construire le chemin complet
                    const fullPath = path.resolve(MIDI_REPO_PATH, command.path);
                    
                    // Analyser le fichier MIDI
                    const midiInfo = analyzeMidiFile(fullPath);
                    
                    // Charger dans le séquenceur
                    success = midiSequencer.loadFile(fullPath);
                    
                    if (success) {
                        // Mettre à jour le playbackState
                        pureDataProxy.updatePlaybackFile(command.path);
                        
                        // Envoyer les infos binaires
                        const fileInfoBuffer = createFileInfoBuffer(midiInfo.duration, midiInfo.totalBeats);
                        pureDataProxy.broadcastBinaryToClients(fileInfoBuffer);
                        
                        const tempoBuffer = createTempoBuffer(midiInfo.tempo);
                        pureDataProxy.broadcastBinaryToClients(tempoBuffer);
                        
                        const timeSigBuffer = createTimeSigBuffer(midiInfo.timeSignature.numerator, midiInfo.timeSignature.denominator);
                        pureDataProxy.broadcastBinaryToClients(timeSigBuffer);
                        
                        console.log('✅ Fichier MIDI chargé et métadonnées envoyées');
                        message = 'Fichier chargé';
                    } else {
                        message = 'Erreur chargement fichier';
                    }
                    
                } else if (command.type === 'MIDI_TRANSPORT') {
                    console.log('🎵 MIDI_TRANSPORT:', command.action);
                    
                    switch (command.action) {
                        case 'play':
                            success = midiSequencer.play();
                            message = success ? 'Lecture démarrée' : 'Impossible de démarrer';
                            break;
                        case 'pause':
                            success = midiSequencer.pause();
                            message = 'Pause';
                            break;
                        case 'stop':
                            success = midiSequencer.stop();
                            message = 'Stop';
                            break;
                        default:
                            message = 'Action inconnue: ' + command.action;
                    }
                    
                    // Envoyer aussi à PureData pour synchronisation
                    if (success) {
                        pureDataProxy.sendCommand(command);
                        console.log('📤 Transport envoyé à PureData:', command.action);
                    }
                    
                } else if (command.type === 'MIDI_SEEK' && command.position !== undefined) {
                    console.log('⏩ MIDI_SEEK:', command.position, 'ms');
                    success = midiSequencer.seek(command.position);
                    
                    // Envoyer aussi à PureData
                    if (success) {
                        pureDataProxy.sendCommand(command);
                        console.log('📤 Seek envoyé à PureData:', command.position, 'ms');
                    }
                    
                    message = 'Position mise à jour';
                    
                } else if (command.type === 'TEMPO_CHANGE' && command.tempo) {
                    console.log('🎼 TEMPO_CHANGE:', command.tempo, 'BPM');
                    success = midiSequencer.setTempo(command.tempo);
                    
                    // Envoyer aussi à PureData pour qu'il soit au courant
                    pureDataProxy.sendCommand(command);
                    console.log('📤 Tempo envoyé à PureData:', command.tempo, 'BPM');
                    
                    message = 'Tempo changé';
                    
                } else {
                    // Commande inconnue, envoyer à PureData
                    success = pureDataProxy.sendCommand(command);
                    message = success ? 'Commande envoyée à PureData' : 'PureData non connecté';
                }
                
                response.writeHead(success ? 200 : 400, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ success, message }));
            } catch (e) {
                console.error('❌ Erreur traitement commande:', e);
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
    
    // Routes API Mode Jeu
    if (request.url === '/api/game/start' && request.method === 'POST') {
        let body = '';
        request.on('data', chunk => { body += chunk; });
        request.on('end', () => {
            try {
                const options = JSON.parse(body);
                const result = gameEngine.startGame(options);
                response.writeHead(200, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify(result));
            } catch (error) {
                console.error('❌ Erreur GAME_START:', error);
                response.writeHead(500, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ success: false, error: error.message }));
            }
        });
        return;
    }
    
    if (request.url === '/api/game/state' && request.method === 'GET') {
        const state = gameEngine.getGameState();
        response.writeHead(200, { 'Content-Type': 'application/json' });
        response.end(JSON.stringify(state));
        return;
    }
    
    if (request.url === '/api/game/pause' && request.method === 'POST') {
        let body = '';
        request.on('data', chunk => { body += chunk; });
        request.on('end', () => {
            try {
                const data = JSON.parse(body);
                const paused = data.paused !== undefined ? data.paused : true;
                const result = gameEngine.pauseGame(paused);
                response.writeHead(200, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify(result));
            } catch (error) {
                console.error('❌ Erreur GAME_PAUSE:', error);
                response.writeHead(500, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ success: false, error: error.message }));
            }
        });
        return;
    }
    
    if (request.url === '/api/game/abort' && request.method === 'POST') {
        let body = '';
        request.on('data', chunk => { body += chunk; });
        request.on('end', () => {
            try {
                const data = body ? JSON.parse(body) : {};
                const reason = data.reason || 'Aborted by user';
                const result = gameEngine.abortGame(reason);
                response.writeHead(200, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify(result));
            } catch (error) {
                console.error('❌ Erreur GAME_ABORT:', error);
                response.writeHead(500, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ success: false, error: error.message }));
            }
        });
        return;
    }
    
    if (request.url === '/api/game/end' && request.method === 'POST') {
        const result = gameEngine.endGame();
        response.writeHead(200, { 'Content-Type': 'application/json' });
        response.end(JSON.stringify(result));
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
    
    // Initialiser le séquenceur MIDI
    midiSequencer = new MidiSequencer(pureDataProxy);
    
    // Initialiser le moteur de jeu
    gameEngine = new GameEngine(pureDataProxy);
    
    // Injecter GameEngine dans PureDataProxy pour router les messages
    pureDataProxy.setGameEngine(gameEngine);
    
    server.listen(PORT, HOST, () => {
        console.log(`🚀 Serveur SirenConsole démarré sur http://${HOST}:${PORT}`);
        console.log(`🌐 Application principale sur http://localhost:${PORT}/appSirenConsole.html`);
        console.log(`🔌 Proxy WebSocket PureData: ${config.servers.websocketUrl}`);
        console.log(`📊 Console de contrôle des pupitres`);
        console.log(`💾 API Presets disponible sur http://localhost:${PORT}/api/presets`);
        console.log(`🎵 API MIDI disponible sur http://localhost:${PORT}/api/midi/files`);
        console.log(`🔀 API PureData Proxy sur http://localhost:${PORT}/api/puredata/*`);
        console.log(`🎮 API Mode Jeu sur http://localhost:${PORT}/api/game/*`);
    });
}).catch((error) => {
    console.error('❌ Erreur initialisation:', error);
    process.exit(1);
});