const WebSocket = require('ws');

// Proxy WebSocket vers PureData
class PureDataProxy {
    constructor(config) {
        this.config = config;
        // Construire l'URL depuis la nouvelle structure config.json
        const host = config.servers?.websocket?.host || 'localhost';
        const port = config.servers?.websocket?.port || 10002;
        this.pureDataUrl = `ws://${host}:${port}`;
        this.ws = null;
        this.connected = false;
        this.reconnectInterval = 3000;
        this.reconnectTimer = null;
        this.eventBuffer = []; // Buffer pour événements temps réel
        this.maxBufferSize = 100;
        this.playbackState = null; // État de lecture MIDI
        this.gameEngine = null; // Moteur de jeu (injecté après construction)
        
        console.log('🎛️ PureDataProxy initialisé, URL:', this.pureDataUrl);
        
        this.connect();
    }
    
    // Injecter le moteur de jeu (appelé après construction depuis server.js)
    setGameEngine(gameEngine) {
        this.gameEngine = gameEngine;
        console.log('🎮 GameEngine injecté dans PureDataProxy');
    }
    
    // Connexion au WebSocket PureData
    connect() {
        console.log('🔌 Connexion à PureData:', this.pureDataUrl);
        
        try {
            // Options pour compatibilité avec PureData
            const options = {
                perMessageDeflate: false,
                handshakeTimeout: 5000,
                protocolVersion: 13,
                origin: 'http://localhost:8001'
            };
            
            this.ws = new WebSocket(this.pureDataUrl, options);
            
            this.ws.on('open', () => {
                this.connected = true;
                console.log('✅ Connecté à PureData');
                
                if (this.reconnectTimer) {
                    clearTimeout(this.reconnectTimer);
                    this.reconnectTimer = null;
                }
            });
            
            this.ws.on('close', () => {
                this.connected = false;
                console.log('❌ Déconnecté de PureData');
                this.scheduleReconnect();
            });
            
            this.ws.on('error', (error) => {
                console.error('❌ Erreur WebSocket PureData:', error.message);
                this.connected = false;
            });
            
            this.ws.on('message', (data) => {
                this.handleMessage(data.toString());
            });
            
        } catch (error) {
            console.error('❌ Exception connexion PureData:', error);
            this.scheduleReconnect();
        }
    }
    
    // Gérer les messages de PureData
    handleMessage(message) {
        // Détecter si binaire (Buffer) ou texte (string)
        if (Buffer.isBuffer(message)) {
            this.handleBinaryMessage(message);
        } else {
            console.log('📥 Message JSON de PureData:', message.substring(0, 100));
            
            try {
                const data = JSON.parse(message);
                
                // Router les messages de jeu vers GameEngine
                if (data.type === 'GAME_END' && this.gameEngine) {
                    this.gameEngine.handleJsonGameMessage(data);
                }
                
                // Traiter les messages d'état de lecture MIDI
                if (data.type === 'MIDI_PLAYBACK_STATE') {
                    this.playbackState = data;
                    console.log('🎵 État lecture MIDI mis à jour:', data.playing ? 'PLAY' : 'STOP', '- Position:', data.position, 'ms');
                }
                
                // Ajouter au buffer pour polling
                this.eventBuffer.push({
                    timestamp: Date.now(),
                    data: data
                });
                
                // Limiter la taille du buffer
                if (this.eventBuffer.length > this.maxBufferSize) {
                    this.eventBuffer.shift();
                }
                
            } catch (e) {
                console.error('❌ Erreur parsing message PureData:', e);
            }
        }
    }
    
    // Décoder messages binaires multi-types
    handleBinaryMessage(buffer) {
        const messageType = buffer.readUInt8(0);
        
        // Router les messages de jeu (0x10-0x1F) vers GameEngine
        if (messageType >= 0x10 && messageType <= 0x1F) {
            if (this.gameEngine) {
                this.gameEngine.handleBinaryGameMessage(buffer);
            } else {
                console.warn('⚠️ Message de jeu reçu mais GameEngine non initialisé:', '0x' + messageType.toString(16).padStart(2, '0'));
            }
            return;
        }
        
        // Initialiser playbackState si nécessaire
        if (!this.playbackState) {
            this.playbackState = {
                type: 'MIDI_PLAYBACK_STATE',
                playing: false,
                position: 0,
                beat: 0,
                tempo: 120,
                timeSignature: { numerator: 4, denominator: 4 },
                duration: 0,
                totalBeats: 0,
                file: ""
            };
        }
        
        switch (messageType) {
            case 0x01: // POSITION (10 bytes, 50ms)
                if (buffer.length < 10) {
                    console.error('❌ POSITION trop court:', buffer.length, 'bytes (attendu 10)');
                    return;
                }
                const flags = buffer.readUInt8(1);
                this.playbackState.playing = (flags & 0x01) !== 0;
                const barNumber = buffer.readUInt16LE(2);
                const beatInBar = buffer.readUInt16LE(4);
                this.playbackState.beat = buffer.readFloatLE(6);
                
                // Calculer position en ms (beat * 60000 / tempo)
                const bpm = this.playbackState.tempo || 120;
                this.playbackState.position = Math.floor((this.playbackState.beat / bpm) * 60000);
                
                // Stocker bar/beat pour l'API
                this.playbackState.bar = barNumber;
                this.playbackState.beatInBar = beatInBar;
                
                // Log compact (max 1/sec)
                if (!this.lastPosLogTime || Date.now() - this.lastPosLogTime > 1000) {
                    console.log('🎵 POSITION (10B):', this.playbackState.playing ? 'PLAY' : 'STOP', 
                               '- Bar:', barNumber, 'Beat:', beatInBar, '/', this.playbackState.timeSignature?.numerator || 4,
                               '- Total:', this.playbackState.beat.toFixed(1));
                    this.lastPosLogTime = Date.now();
                }
                break;
                
            case 0x02: // FILE_INFO (10 bytes, au load)
                if (buffer.length < 10) {
                    console.error('❌ FILE_INFO trop court:', buffer.length, 'bytes (attendu 10)');
                    return;
                }
                this.playbackState.duration = buffer.readUInt32LE(2);
                this.playbackState.totalBeats = buffer.readUInt32LE(6);
                console.log('📁 FILE_INFO (10B): Durée:', this.playbackState.duration, 'ms - Total beats:', this.playbackState.totalBeats);
                break;
                
            case 0x03: // TEMPO (3 bytes, quand change)
                if (buffer.length < 3) {
                    console.error('❌ TEMPO trop court:', buffer.length, 'bytes (attendu 3)');
                    return;
                }
                this.playbackState.tempo = buffer.readUInt16LE(1);
                console.log('🎼 TEMPO (3B):', this.playbackState.tempo, 'BPM');
                break;
                
            case 0x04: // TIMESIG (3 bytes, quand change)
                if (buffer.length < 3) {
                    console.error('❌ TIMESIG trop court:', buffer.length, 'bytes (attendu 3)');
                    return;
                }
                this.playbackState.timeSignature.numerator = buffer.readUInt8(1);
                this.playbackState.timeSignature.denominator = buffer.readUInt8(2);
                console.log('🎵 TIMESIG (3B):', 
                           this.playbackState.timeSignature.numerator + '/' + 
                           this.playbackState.timeSignature.denominator);
                break;
                
            default:
                console.warn('⚠️ Type message binaire inconnu:', '0x' + messageType.toString(16).padStart(2, '0'));
        }
    }
    
    // Envoyer une commande à PureData
    sendCommand(command) {
        if (!this.connected || !this.ws) {
            console.error('❌ PureData non connecté');
            return false;
        }
        
        try {
            const message = JSON.stringify(command);
            console.log('📤 Envoi à PureData:', message.substring(0, 100));
            
            // Envoyer en mode binaire comme SirenePupitre
            // Convertir la string JSON en Buffer
            const buffer = Buffer.from(message, 'utf8');
            this.ws.send(buffer);
            
            return true;
        } catch (error) {
            console.error('❌ Erreur envoi PureData:', error);
            return false;
        }
    }
    
    // Récupérer les événements depuis le buffer
    getEvents(since = 0) {
        return this.eventBuffer.filter(event => event.timestamp > since);
    }
    
    // Vider le buffer
    clearEvents() {
        this.eventBuffer = [];
    }
    
    // Obtenir le statut de la connexion
    getStatus() {
        return {
            connected: this.connected,
            url: this.pureDataUrl,
            bufferSize: this.eventBuffer.length
        };
    }
    
    // Obtenir l'état de lecture MIDI
    getPlaybackState() {
        return this.playbackState || {
            playing: false,
            position: 0,
            beat: 0,
            tempo: 120,
            timeSignature: { numerator: 4, denominator: 4 },
            duration: 0,
            totalBeats: 0,
            file: ""
        };
    }
    
    // Mettre à jour le nom du fichier dans playbackState
    updatePlaybackFile(filePath) {
        if (!this.playbackState) {
            this.playbackState = this.getPlaybackState();
        }
        this.playbackState.file = filePath;
        console.log('📁 Fichier MIDI mis à jour:', filePath);
    }
    
    // Broadcaster un buffer binaire directement (utilisé pour FILE_INFO, TEMPO, TIMESIG depuis server.js)
    broadcastBinaryToClients(buffer) {
        // Pour l'instant, on stocke juste dans playbackState
        // Le broadcast réel se fera via le polling HTTP des clients
        // (car on n'a pas de connexion WebSocket directe clients ↔ server.js)
        
        // Décoder le buffer pour mettre à jour playbackState
        this.handleBinaryMessage(buffer);
    }
    
    // Planifier une reconnexion
    scheduleReconnect() {
        if (this.reconnectTimer) return;
        
        console.log('🔄 Reconnexion dans', this.reconnectInterval, 'ms');
        this.reconnectTimer = setTimeout(() => {
            this.reconnectTimer = null;
            this.connect();
        }, this.reconnectInterval);
    }
    
    // Fermer la connexion
    close() {
        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
            this.reconnectTimer = null;
        }
        
        if (this.ws) {
            this.ws.close();
            this.ws = null;
        }
        
        this.connected = false;
    }
}

module.exports = PureDataProxy;

