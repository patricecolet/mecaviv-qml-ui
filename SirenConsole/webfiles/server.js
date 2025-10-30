const http = require('http');
const fs = require('fs');
const path = require('path');
const WebSocket = require('ws');

// Importer l'API des presets
const presetAPI = require('./api-presets.js');
let currentPresetId = null;

// Importer l'API MIDI
const midiAPI = require('./api-midi.js');

// Importer le proxy PureData
const PureDataProxy = require('./puredata-proxy.js');

// Importer l'analyseur MIDI
const { analyzeMidiFile, createFileInfoBuffer, createTempoBuffer, createTimeSigBuffer } = require('./midi-analyzer.js');

// Importer le séquenceur MIDI
const MidiSequencer = require('./midi-sequencer.js');

// Variables globales
let lastVolantData = null; // Stocker les dernières données du volant

// Charger la configuration depuis config.json
const { loadConfig } = require('../../config-loader.js');
const config = loadConfig();

// Charger aussi la configuration SirenConsole pour les pupitres
const sirenConsoleConfig = require('../config.js');

// Chemin du répertoire MIDI
const MIDI_REPO_PATH = process.env.MECAVIV_COMPOSITIONS_PATH || config.paths.midiRepository;

// Configuration du serveur
const PORT = 8001; // Port différent de SirenePupitre (8000)
const HOST = '0.0.0.0';

// Initialiser le proxy PureData et le séquenceur
let pureDataProxy = null;
let midiSequencer = null;

// Serveur WebSocket pour les connexions clients
let wss = null;
let connectedClients = new Set();

// Middleware pour les headers CORS et sécurité
function setSecurityHeaders(response) {
    // Headers CORS basiques
    response.setHeader('Access-Control-Allow-Origin', '*');
    response.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
    response.setHeader('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization, Sec-WebSocket-Protocol, Sec-WebSocket-Version');
    response.setHeader('Vary', 'Origin');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    
    // Headers spécifiques pour WebSocket
    response.setHeader('Sec-WebSocket-Protocol', 'websocket');
    response.setHeader('Sec-WebSocket-Version', '13');
}

// Fonctions pour gérer les WebSockets
function broadcastToClients(message) {
    const messageStr = typeof message === 'string' ? message : JSON.stringify(message);
    connectedClients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            try {
                client.send(messageStr);
            } catch (error) {
                console.error('❌ Erreur envoi WebSocket client:', error);
                connectedClients.delete(client);
            }
        }
    });
}

// Convertir note MIDI + pitchbend → fréquence (Hz)
function midiToFrequency(note, pitchbend, transposition = 0) {
    // Appliquer la transposition (octaves)
    const transposedNote = note + (transposition * 12)
    
    // Formule MIDI standard : f = 440 * 2^((note - 69) / 12)
    const baseFrequency = 440 * Math.pow(2, (transposedNote - 69) / 12)
    
    // Appliquer le pitchbend (0-16383, centre = 8192)
    const pitchbendFactor = (pitchbend - 8192) / 8192 // -1 à +1
    const pitchbendSemitones = pitchbendFactor * 0.5 // ±0.5 demi-ton max
    
    return baseFrequency * Math.pow(2, pitchbendSemitones / 12)
}

// Convertir fréquence → RPM pour chaque sirène
function frequencyToRpm(frequency, outputs) {
    // RPM = Fréquence × 60 / Nombre de sorties
    return frequency * 60 / outputs
}

function handleWebSocketConnection(ws, request) {
    // console.log('🔌 Nouvelle connexion WebSocket'); // Désactivé pour éviter le spam
    
    // Attendre un message d'identification pour déterminer le type de client
    ws.on('message', (message) => {
        // Vérifier si c'est un message binaire
        if (Buffer.isBuffer(message)) {
            // Essayer de convertir en string pour voir si c'est du JSON
            try {
                const text = message.toString('utf8')
                const data = JSON.parse(text)
                
                // Traiter comme un message JSON
                if (data.type === 'PING') {
                    // PING reçu, renvoyer PONG (sans log pour éviter le spam)
                    ws.send(JSON.stringify({ 
                        type: 'PONG', 
                        source: 'SERVER_NODEJS',
                        timestamp: Date.now() 
                    }))
                } else if (data.type === 'SIRENCONSOLE_IDENTIFICATION') {
                    // console.log('🔑 Client SirenConsole QML identifié');
                    // Ajouter le client à la liste des clients connectés
                    connectedClients.add(ws);
                    
                    // Envoyer le statut initial
                    if (pureDataProxy) {
                        const status = pureDataProxy.getStatus();
                        ws.send(JSON.stringify({
                            type: 'INITIAL_STATUS',
                            data: status
                        }));
                    }
                }
            } catch (e) {
                // Ignorer les messages binaires qui ne sont pas du JSON
            }
            
            if (message.length === 8) {
                const magic = message.readUInt16BE(0)
                
                if (magic === 0x5353) { // Magic "SS"
                    const type = message.readUInt8(2)
                    const pupitreId = message.readUInt8(3)
                    const note = message.readUInt8(4)
                    const velocity = message.readUInt8(5)
                    const pitchbend = message.readUInt16BE(6)
                    
                    if (type === 0x01 && pupitreId === 3) { // VOLANT_STATE pour P3
                        // Convertir note MIDI → fréquence → RPM (S3: transposition +1 octave, 8 sorties)
                        const frequency = midiToFrequency(note, pitchbend, 1) // +1 octave pour S3
                        const rpm = frequencyToRpm(frequency, 8) // 8 sorties pour S3
                        
                        // Stocker les dernières données du volant
                        lastVolantData = {
                            pupitreId: pupitreId,
                            note: note,
                            velocity: velocity,
                            pitchbend: pitchbend,
                            frequency: frequency,
                            rpm: rpm,
                            timestamp: Date.now()
                        };
                        
                        // Diffuser aux clients UI
                        broadcastToClients({
                            type: 'VOLANT_DATA',
                            pupitreId: pupitreId,
                            note: note,
                            velocity: velocity,
                            pitchbend: pitchbend,
                            frequency: frequency,
                            rpm: rpm,
                            timestamp: Date.now()
                        })
                    }
                }
            }
            return
        }
        
        try {
            const data = JSON.parse(message);
            // console.log('📥 Message WebSocket reçu:', data.type); // Désactivé pour éviter le spam
            
            // Vérifier si c'est un pupitre qui se connecte
            if (data.type === 'PUPITRE_IDENTIFICATION' && data.pupitreId) {
                // console.log(`🎛️ Pupitre ${data.pupitreId} identifié`); // Désactivé pour éviter le spam
                
                // Gérer la connexion du pupitre via le proxy PureData
                if (pureDataProxy) {
                    const pupitreInfo = {
                        id: data.pupitreId,
                        name: data.pupitreName || `Pupitre ${data.pupitreId}`,
                        host: request.socket.remoteAddress,
                        port: 8000,
                        websocketPort: 10002,
                        enabled: true
                    };
                    
                    pureDataProxy.handleIncomingConnection(ws, data.pupitreId, pupitreInfo);
                }
                
                // Envoyer confirmation au pupitre
                ws.send(JSON.stringify({
                    type: 'PUPITRE_CONNECTED',
                    pupitreId: data.pupitreId,
                    timestamp: Date.now()
                }));
                
            } else {
                // C'est un client SirenConsole (interface web)
                // console.log('🌐 Client SirenConsole connecté'); // Désactivé pour éviter le spam
                
                // Traiter les messages des clients SirenConsole
                ws.on('message', (message) => {
                    try {
                        const data = JSON.parse(message);
                        // console.log('📥 Message SirenConsole reçu:', data.type); // Désactivé pour éviter le spam
                        
                        switch (data.type) {
                            case 'PING':
                                // PING reçu, renvoyer PONG (sans log pour éviter le spam)
                                ws.send(JSON.stringify({ 
                                    type: 'PONG', 
                                    source: 'SERVER_NODEJS',
                                    timestamp: Date.now() 
                                }));
                                break;
                            case 'SIRENCONSOLE_IDENTIFICATION':
                                // console.log('🔑 Client SirenConsole QML identifié');
                                // Ajouter le client à la liste des clients connectés
                                connectedClients.add(ws);
                                
                                // Envoyer le statut initial
                                if (pureDataProxy) {
                                    const status = pureDataProxy.getStatus();
                                    ws.send(JSON.stringify({
                                        type: 'INITIAL_STATUS',
                                        data: status
                                    }));
                                }
                                break;
                            default:
                                // console.log('⚠️ Type message SirenConsole inconnu:', data.type);
                        }
                    } catch (error) {
                        console.error('❌ Erreur parsing message SirenConsole:', error);
                    }
                });
                
                // Les messages sont maintenant traités par le gestionnaire ws.on('message') ci-dessus
            }
        } catch (error) {
            console.error('❌ Erreur parsing message WebSocket:', error);
        }
    });
    
    ws.on('close', (code, reason) => {
        // console.log('❌ WebSocket déconnecté:', code, reason.toString());
        connectedClients.delete(ws);
    });
    
    ws.on('error', (error) => {
        console.error('❌ Erreur WebSocket:', error);
        connectedClients.delete(ws);
    });
}

// Gestion des requêtes
const server = http.createServer(function (request, response) {
    // Logs uniquement pour les requêtes intéressantes (pas les GET polling)
    if (request.method !== 'GET' || !request.url.includes('/api/puredata/playback')) {
        // Requête reçue
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
    
    // Route pour config.js (dans le répertoire parent)
    if (request.url === '/config.js') {
        filePath = '../config.js';
    }
    
    // --- Current preset endpoints ---
    if (request.url === '/api/presets/current' || (request.url.startsWith('/api/presets/current') && request.method === 'GET')) {
        (async () => {
            try {
                const data = await presetAPI.readPresets();
                let preset = null;
                if (currentPresetId) preset = data.presets.find(p => p.id === currentPresetId) || null;
                if (!preset) {
                    preset = data.presets[0] || null;
                    currentPresetId = preset ? preset.id : null;
                }
                response.writeHead(200, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ preset, currentId: currentPresetId }));
            } catch (e) {
                response.writeHead(500, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ error: e.message }));
            }
        })();
        return;
    }
    
    // Routes API pour les presets (générique) - exclure explicitement /api/presets/current...
    if (request.url.startsWith('/api/presets')
        && !request.url.startsWith('/api/presets/current')) {
        // Rediriger vers l'API des presets
        presetAPI.app(request, response);
        return;
    }
    if ((request.url === '/api/presets/current' || request.url.startsWith('/api/presets/current')) && request.method === 'PUT') {
        let body = '';
        request.on('data', chunk => body += chunk);
        request.on('end', async () => {
            try {
                const updatedPreset = JSON.parse(body);
                const data = await presetAPI.readPresets();
                const idx = data.presets.findIndex(p => p.id === updatedPreset.id);
                if (idx === -1) data.presets.push(updatedPreset); else data.presets[idx] = updatedPreset;
                currentPresetId = updatedPreset.id;
                await presetAPI.writePresets(data);
                response.writeHead(200, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ preset: updatedPreset, currentId: currentPresetId }));
            } catch (e) {
                response.writeHead(400, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ error: e.message }));
            }
        });
        return;
    }
    if ((request.url === '/api/presets/current/assigned-sirenes' || request.url.startsWith('/api/presets/current/assigned-sirenes')) && request.method === 'PATCH') {
        let body = '';
        request.on('data', chunk => body += chunk);
        request.on('end', async () => {
            try {
                const { pupitreId, assignedSirenes } = JSON.parse(body);
                const data = await presetAPI.readPresets();
                let preset = currentPresetId ? data.presets.find(p => p.id === currentPresetId) : data.presets[0];
                if (!preset) throw new Error('No current preset');
                if (!preset.config) preset.config = {};
                if (!preset.config.pupitres) preset.config.pupitres = [];
                const list = preset.config.pupitres;
                const p = list.find(x => x.id === pupitreId);
                if (!p) throw new Error('Pupitre not found');
                p.assignedSirenes = Array.isArray(assignedSirenes) ? assignedSirenes : [];
                await presetAPI.writePresets(data);
                response.writeHead(200, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ success: true, presetId: preset.id, pupitreId, assignedSirenes: p.assignedSirenes }));
            } catch (e) {
                response.writeHead(400, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ success: false, error: e.message }));
            }
        });
        return;
    }
    if ((request.url === '/api/presets/current/sirene-config' || request.url.startsWith('/api/presets/current/sirene-config')) && request.method === 'PATCH') {
        let body = '';
        request.on('data', chunk => body += chunk);
        request.on('end', async () => {
            try {
                const { pupitreId, sireneId, changes } = JSON.parse(body);
                const data = await presetAPI.readPresets();
                let preset = currentPresetId ? data.presets.find(p => p.id === currentPresetId) : data.presets[0];
                if (!preset) throw new Error('No current preset');
                if (!preset.config) preset.config = {};
                if (!preset.config.pupitres) preset.config.pupitres = [];
                const list = preset.config.pupitres;
                const p = list.find(x => x.id === pupitreId);
                if (!p) throw new Error('Pupitre not found');
                if (!p.sirenes) p.sirenes = {};
                const key = 'sirene' + (typeof sireneId === 'number' ? sireneId : parseInt(sireneId, 10));
                if (!p.sirenes[key]) p.sirenes[key] = { ambitusRestricted: false, frettedMode: false };
                const ch = changes || {};
                Object.keys(ch).forEach(k => { p.sirenes[key][k] = ch[k]; });
                await presetAPI.writePresets(data);
                response.writeHead(200, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ success: true, presetId: preset.id, pupitreId, sireneId, sirene: p.sirenes[key] }));
            } catch (e) {
                response.writeHead(400, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ success: false, error: e.message }));
            }
        });
        return;
    }
    if ((request.url === '/api/presets/current/outputs' || request.url.startsWith('/api/presets/current/outputs')) && request.method === 'PATCH') {
        let body = '';
        request.on('data', chunk => body += chunk);
        request.on('end', async () => {
            try {
                const { pupitreId, changes } = JSON.parse(body);
                const data = await presetAPI.readPresets();
                let preset = currentPresetId ? data.presets.find(p => p.id === currentPresetId) : data.presets[0];
                if (!preset) throw new Error('No current preset');
                if (!preset.config) preset.config = {};
                if (!preset.config.pupitres) preset.config.pupitres = [];
                const list = preset.config.pupitres;
                const p = list.find(x => x.id === pupitreId);
                if (!p) throw new Error('Pupitre not found');
                const ch = changes || {};
                ['vstEnabled','udpEnabled','rtpMidiEnabled'].forEach(k => { if (k in ch) p[k] = !!ch[k]; });
                await presetAPI.writePresets(data);
                response.writeHead(200, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ success: true, presetId: preset.id, pupitreId, outputs: { vstEnabled: p.vstEnabled, udpEnabled: p.udpEnabled, rtpMidiEnabled: p.rtpMidiEnabled } }));
            } catch (e) {
                response.writeHead(400, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ success: false, error: e.message }));
            }
        });
        return;
    }
    if ((request.url === '/api/presets/current/controller-mapping' || request.url.startsWith('/api/presets/current/controller-mapping')) && request.method === 'PATCH') {
        let body = '';
        request.on('data', chunk => body += chunk);
        request.on('end', async () => {
            try {
                const { pupitreId, controller, cc, curve } = JSON.parse(body);
                const data = await presetAPI.readPresets();
                let preset = currentPresetId ? data.presets.find(p => p.id === currentPresetId) : data.presets[0];
                if (!preset) throw new Error('No current preset');
                if (!preset.config) preset.config = {};
                if (!preset.config.pupitres) preset.config.pupitres = [];
                const list = preset.config.pupitres;
                const p = list.find(x => x.id === pupitreId);
                if (!p) throw new Error('Pupitre not found');
                if (!p.controllerMapping) p.controllerMapping = {};
                if (!p.controllerMapping[controller]) p.controllerMapping[controller] = {};
                if (cc !== undefined) p.controllerMapping[controller].cc = parseInt(cc, 10);
                if (curve) p.controllerMapping[controller].curve = String(curve);
                await presetAPI.writePresets(data);
                response.writeHead(200, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ success: true, presetId: preset.id, pupitreId, controller, mapping: p.controllerMapping[controller] }));
            } catch (e) {
                response.writeHead(400, { 'Content-Type': 'application/json' });
                response.end(JSON.stringify({ success: false, error: e.message }));
            }
        });
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
    
    // Route API pour les données du volant
    if (request.url === '/api/volant-data') {
        response.writeHead(200, { 'Content-Type': 'application/json' });
        response.end(JSON.stringify({ volantData: lastVolantData }));
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
                    // console.log('📁 MIDI_FILE_LOAD:', command.path);
                    
                    // Construire le chemin complet
                    const fullPath = path.resolve(MIDI_REPO_PATH, command.path);
                    
                    // Analyser le fichier MIDI
                    const midiInfo = analyzeMidiFile(fullPath);
                    
                    // Charger dans le séquenceur
                    success = midiSequencer.loadFile(fullPath);
                    
                    if (success) {
                        // Mettre à jour le playbackState
                        pureDataProxy.updatePlaybackFile(command.path);
                        
                        // Envoyer le message MIDI_FILE_LOAD à PureData
                        pureDataProxy.sendCommand(command);
                        // console.log('📤 MIDI_FILE_LOAD envoyé à PureData:', command.path);
                        
                        // Pas d'envoi binaire: PureData lit localement; la Console n'envoie que JSON
                        
                        // console.log('✅ Fichier MIDI chargé et métadonnées envoyées');
                        message = 'Fichier chargé';
                    } else {
                        message = 'Erreur chargement fichier';
                    }
                    
                } else if (command.type === 'MIDI_TRANSPORT') {
                    // console.log('🎵 MIDI_TRANSPORT:', command.action);
                    
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
                    
                    // Relayer aussi à PureData en JSON pour synchronisation
                    if (success) {
                        const state = midiSequencer.getState();
                        command.position = Math.floor(state.beat * midiSequencer.ppq);
                        pureDataProxy.sendCommand(command);
                    }
                    
                } else if (command.type === 'MIDI_SEEK' && command.position !== undefined) {
                    // console.log('⏩ MIDI_SEEK:', command.position, 'ms');
                    success = midiSequencer.seek(command.position);
                    
                    // Envoyer aussi à PureData
                    if (success) {
                        pureDataProxy.sendCommand(command);
                        // console.log('📤 Seek envoyé à PureData:', command.position, 'ms');
                    }
                    
                    message = 'Position mise à jour';
                    
                } else if (command.type === 'TEMPO_CHANGE' && command.tempo) {
                    // console.log('🎼 TEMPO_CHANGE:', command.tempo, 'BPM');
                    success = midiSequencer.setTempo(command.tempo);
                    
                    // Envoyer aussi à PureData pour qu'il soit au courant
                    pureDataProxy.sendCommand(command);
                    // console.log('📤 Tempo envoyé à PureData:', command.tempo, 'BPM');
                    
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
    
    // API pour obtenir le statut des pupitres (pour les LEDs)
    if (request.url === '/api/pupitres/status') {
        const status = pureDataProxy.getStatus();
        response.writeHead(200, { 'Content-Type': 'application/json' });
        response.end(JSON.stringify(status));
        return;
    }
    
    // API pour obtenir le statut d'un pupitre spécifique
    if (request.url.startsWith('/api/pupitres/') && request.url.endsWith('/status')) {
        const pupitreId = request.url.split('/')[3];
        const status = pureDataProxy.getStatus();
        const pupitreStatus = status.connections.find(conn => conn.pupitreId === pupitreId);
        
        if (pupitreStatus) {
            response.writeHead(200, { 'Content-Type': 'application/json' });
            response.end(JSON.stringify(pupitreStatus));
        } else {
            response.writeHead(404, { 'Content-Type': 'application/json' });
            response.end(JSON.stringify({ error: 'Pupitre non trouvé' }));
        }
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
            // console.log('✅ Fichier servi:', filePath);
            response.writeHead(200, { 'Content-Type': contentType });
            response.end(content, 'utf-8');
        }
    });
});

// Initialiser l'API des presets et démarrer le serveur
presetAPI.initializePresetAPI().then(() => {
    // Initialiser le proxy PureData avec la configuration SirenConsole
    pureDataProxy = new PureDataProxy(sirenConsoleConfig, this, broadcastToClients);
    
    // Initialiser le séquenceur MIDI
    midiSequencer = new MidiSequencer(pureDataProxy);
    
    // Créer le serveur WebSocket
    wss = new WebSocket.Server({ 
        server: server,
        path: '/ws',
        perMessageDeflate: false
    });
    
    // Gérer les connexions WebSocket
    wss.on('connection', handleWebSocketConnection);
    
    // Intégrer avec le proxy PureData pour diffuser les événements
    if (pureDataProxy) {
        // Écouter les changements de statut des pupitres
           setInterval(() => {
               const status = pureDataProxy.getStatus();
               // console.log("📊 Envoi statut aux clients:", connectedClients.size, "clients connectés");
               broadcastToClients({
                   type: 'PUPITRE_STATUS_UPDATE',
                   data: status,
                   timestamp: Date.now()
               });
           }, 1000); // Diffuser toutes les secondes
        
        // Le proxy PureData gère les connexions vers les pupitres
        // Désactiver tous les logs du proxy pour éviter le spam
        // pureDataProxy.setLogLevel('ERROR'); // Cette méthode n'existe pas
        
        // Rediriger tous les logs du proxy vers /dev/null
        const originalConsoleLog = console.log;
        const originalConsoleError = console.error;
        
        console.log = (...args) => {
            // Ignorer TOUS les logs du proxy sauf les connexions réussies
            if (args[0] && typeof args[0] === 'string') {
                // Ignorer tous les logs de connexion, erreur, statut, reconnexion
                if (args[0].includes('🔌 Connexion à') ||
                    args[0].includes('❌ Erreur WebSocket') ||
                    args[0].includes('📊 Statut mis à jour') ||
                    args[0].includes('❌ Déconnecté de') ||
                    args[0].includes('🔄 Reconnexion') ||
                    args[0].includes('Statut') ||
                    args[0].includes('Reconnexion') ||
                    args[0].includes('Erreur WebSocket')) {
                    return; // Ignorer ces logs
                }
                // GARDER SEULEMENT le log "Connecté à"
                if (args[0].includes('✅ Connecté à')) {
                    originalConsoleLog.apply(console, args);
                    return;
                }
            }
            originalConsoleLog.apply(console, args);
        };
       
        console.error = (...args) => {
            // Ignorer TOUS les logs d'erreur du proxy
            if (args[0] && typeof args[0] === 'string') {
                if (args[0].includes('🔌 Connexion à') ||
                    args[0].includes('❌ Erreur WebSocket') ||
                    args[0].includes('📊 Statut mis à jour') ||
                    args[0].includes('❌ Déconnecté de') ||
                    args[0].includes('🔄 Reconnexion') ||
                    args[0].includes('Statut') ||
                    args[0].includes('Reconnexion') ||
                    args[0].includes('Erreur WebSocket')) {
                    return; // Ignorer ces logs
                }
                // GARDER SEULEMENT le log "Connecté à"
                if (args[0].includes('✅ Connecté à')) {
                    originalConsoleError.apply(console, args);
                    return;
                }
            }
            originalConsoleError.apply(console, args);
        };
    }
    
    server.listen(PORT, HOST, () => {
        // console.log(`🚀 Serveur SirenConsole démarré sur http://${HOST}:${PORT}`);
        // console.log(`🌐 Application principale sur http://localhost:${PORT}/appSirenConsole.html`);
        // console.log(`🔌 WebSocket serveur sur ws://localhost:${PORT}/ws`);
        // console.log(`📝 Logs désactivés pour éviter le spam`);
        // console.log(`🎯 Lancez maintenant SirenConsole Qt6 pour tester WebSocket`);
        // Tous les autres logs désactivés
    });
}).catch((error) => {
    console.error('❌ Erreur initialisation:', error);
    process.exit(1);
});