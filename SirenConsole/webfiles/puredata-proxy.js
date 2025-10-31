const WebSocket = require('ws');

// Proxy WebSocket vers PureData - Gestion des connexions multiples
class PureDataProxy {
    constructor(config, server = null, broadcastToClients = null, handleParamChanged = null, handlePupitreConfig = null) {
        this.config = config;
        this.server = server; // Référence au serveur pour diffusion
        this.broadcastToClients = broadcastToClients; // Fonction de diffusion directe
        this.handleParamChanged = handleParamChanged; // Callback pour PARAM_CHANGED depuis pupitres
        this.handlePupitreConfig = handlePupitreConfig; // Callback pour configuration complète depuis pupitres
        this.connections = new Map(); // Map des connexions par pupitre
        this.eventBuffer = []; // Buffer global pour événements temps réel
        this.maxBufferSize = 100;
        this.playbackStates = new Map(); // États de lecture par pupitre
        this.reconnectInterval = 1000; // 1 seconde pour une reconnexion rapide
        this.reconnectTimers = new Map(); // Timers de reconnexion par pupitre
        this.sequencerPlayback = null; // État global fourni par le séquenceur Node (pour l'UI)
        this.binaryChunkStates = new Map(); // Accumulation binaire (format SirenePupitre) par pupitre
        
        // console.log('🎛️ PureDataProxy initialisé pour connexions multiples');
        
        // Initialiser les connexions vers tous les pupitres (via PureData qui fait le routage)
        this.initializeConnections();
        
        // Vérifier périodiquement l'état des connexions
        setInterval(() => {
            this.checkConnectionsHealth();
        }, 2000); // Vérifier toutes les 2 secondes
    }

    // Mettre à jour l'état de lecture depuis le séquenceur (sans envoyer aux pupitres)
    updatePlaybackFromSequencer(playback) {
        // playback: { playing, bar, beatInBar, beat }
        // Mettre à jour un état global séquenceur
        this.sequencerPlayback = {
            type: 'MIDI_PLAYBACK_STATE',
            playing: !!playback.playing,
            bar: playback.bar || 0,
            beatInBar: playback.beatInBar || 0,
            beat: playback.beat || 0,
        };

        // Mettre à jour toutes les entrées playbackStates existantes (pour API / UI)
        for (const [pupitreId, state] of this.playbackStates) {
            state.playing = this.sequencerPlayback.playing;
            state.bar = this.sequencerPlayback.bar;
            state.beatInBar = this.sequencerPlayback.beatInBar;
            state.beat = this.sequencerPlayback.beat;
            // position (ms) dérivée si tempo connu
            const bpm = state.tempo || 120;
            state.position = Math.floor((state.beat / bpm) * 60000);
            this.playbackStates.set(pupitreId, state);
        }
    }
    
    // Convertir config PureData vers format pupitre pour le preset
    convertPureDataConfigToPupitreConfig(pureDataConfig, pupitreId) {
        const config = {
            assignedSirenes: [],
            vstEnabled: false,
            udpEnabled: false,
            rtpMidiEnabled: false,
            controllerMapping: {},
            sirens: []
        };
        
        // Extraire assignedSirenes depuis sirenConfig
        if (pureDataConfig.sirenConfig && pureDataConfig.sirenConfig.assignedSirenes) {
            config.assignedSirenes = Array.isArray(pureDataConfig.sirenConfig.assignedSirenes) 
                ? pureDataConfig.sirenConfig.assignedSirenes 
                : [];
        }
        // NEW: si currentSirens présent, l'utiliser comme source des assignedSirenes
        if (pureDataConfig.sirenConfig && Array.isArray(pureDataConfig.sirenConfig.currentSirens)) {
            config.assignedSirenes = pureDataConfig.sirenConfig.currentSirens
                .map(v => (typeof v === 'string' ? parseInt(v, 10) : v))
                .filter(v => !isNaN(v));
        }
        
        // Extraire sirens
        if (pureDataConfig.sirenConfig && Array.isArray(pureDataConfig.sirenConfig.sirens)) {
            config.sirens = pureDataConfig.sirenConfig.sirens;
        }
        
        // Extraire outputConfig
        if (pureDataConfig.outputConfig) {
            config.vstEnabled = !!pureDataConfig.outputConfig.vstEnabled;
            config.udpEnabled = !!pureDataConfig.outputConfig.udpEnabled;
            config.rtpMidiEnabled = !!pureDataConfig.outputConfig.rtpMidiEnabled;
        }
        
        // Extraire controllerMapping
        if (pureDataConfig.controllerMapping) {
            config.controllerMapping = pureDataConfig.controllerMapping;
        }
        
        return config;
    }
    
    // Envoyer REQUEST_PUPITRE_CONFIG à PureData via sendCommand (routage via pupitre)
    // PureData doit intercepter ce message et répondre avec CONFIG_FULL
    requestPupitreConfig(pupitreId) {
        console.log(`📤 requestPupitreConfig appelé pour ${pupitreId}`);
        // Envoyer via sendCommand - PureData fera le routage
        const result = this.sendCommand({
            type: "REQUEST_CONFIG",
            pupitreId: pupitreId,
            source: "console"
        }, pupitreId);
        console.log(`📤 requestPupitreConfig résultat pour ${pupitreId}:`, result);
        return result;
    }
    
    // Initialiser les connexions vers tous les pupitres
    initializeConnections() {
        if (!this.config.pupitres || !Array.isArray(this.config.pupitres)) {
            console.error('❌ Configuration pupitres manquante');
            return;
        }
        
        // console.log('🔌 Initialisation des connexions vers', this.config.pupitres.length, 'pupitres');
        
        this.config.pupitres.forEach(pupitre => {
            if (pupitre.enabled) {
                this.connectToPupitre(pupitre);
            }
        });
    }
    
    // Connexion à un pupitre spécifique
    connectToPupitre(pupitre) {
        const pupitreId = pupitre.id;
        const host = pupitre.host;
        const port = pupitre.websocketPort || 10002;
        const url = `ws://${host}:${port}`;
        
        // console.log(`🔌 Connexion à ${pupitre.name} (${pupitreId}): ${url}`);
        
        try {
            // Options pour compatibilité avec PureData
            const options = {
                perMessageDeflate: false,
                handshakeTimeout: 5000,
                protocolVersion: 13,
                origin: 'http://localhost:8001'
            };
            
            const ws = new WebSocket(url, options);
            
            // Stocker la connexion
            this.connections.set(pupitreId, {
                websocket: ws,
                pupitre: pupitre,
                url: url,
                connected: false,
                lastSeen: null
            });
            
            // Gestionnaires d'événements
            ws.on('open', () => {
                // console.log(`✅ Connecté à ${pupitre.name} (${pupitreId})`);
                
                const connection = this.connections.get(pupitreId);
                if (connection) {
                    connection.connected = true;
                    connection.lastSeen = new Date();
                }
                
                // Nettoyer le timer de reconnexion
                if (this.reconnectTimers.has(pupitreId)) {
                    clearTimeout(this.reconnectTimers.get(pupitreId));
                    this.reconnectTimers.delete(pupitreId);
                }
            });
            
            ws.on('close', (code, reason) => {
                // console.log(`❌ Déconnecté de ${pupitre.name} (${pupitreId}) - Code: ${code}, Raison: ${reason}`);
                
                const connection = this.connections.get(pupitreId);
                if (connection) {
                    connection.connected = false;
                    connection.lastSeen = null;
                    // console.log(`📊 Statut mis à jour: ${pupitreId} = disconnected`);
                }
                
                // Reconnexion immédiate pour les déconnexions inattendues
                this.scheduleReconnect(pupitreId);
            });
            
            ws.on('error', (error) => {
                console.error(`❌ Erreur WebSocket ${pupitre.name} (${pupitreId}):`, error.message);
                
                const connection = this.connections.get(pupitreId);
                if (connection) {
                    connection.connected = false;
                    connection.lastSeen = null;
                    // console.log(`📊 Statut mis à jour: ${pupitreId} = disconnected (erreur)`);
                }
            });
            
            ws.on('message', (data) => {
                this.handleMessage(pupitreId, data);
            });
            
        } catch (error) {
            console.error(`❌ Exception connexion ${pupitre.name} (${pupitreId}):`, error);
            this.scheduleReconnect(pupitreId);
        }
    }
    
    // Gérer les messages d'un pupitre spécifique
    handleMessage(pupitreId, message) {
        const connection = this.connections.get(pupitreId);
        if (!connection) return;
        
        // Détecter si binaire (Buffer) ou texte (string)
        if (Buffer.isBuffer(message)) {
            try {
                console.log(`📦 Binaire reçu de ${connection.pupitre.name} (${pupitreId}), taille=${message.length} bytes`);
            } catch (_) {}
            this.handleBinaryMessage(pupitreId, message);
        } else {
            // console.log(`📥 Message JSON de ${connection.pupitre.name} (${pupitreId}):`, message.substring(0, 100));
            
            try {
                const data = JSON.parse(message);
                
                // Log tous les messages reçus pour debug (limité aux types importants)
                if (data.type === 'CONFIG_FULL' || data.type === 'PUPITRE_STATUS' || data.type === 'REQUEST_PUPITRE_CONFIG') {
                    console.log(`📥 Message reçu de ${connection.pupitre.name} (${pupitreId}):`, {
                        type: data.type,
                        hasConfig: !!data.config,
                        hasData: !!data.data,
                        pupitreId: data.pupitreId || pupitreId
                    });
                }
                
                // Traiter PARAM_CHANGED depuis pupitres (source: "pupitre")
                if (data.type === 'PARAM_CHANGED' && data.source === 'pupitre' && this.handleParamChanged) {
                    this.handleParamChanged(pupitreId, data.path, data.value);
                }
                
                // Traiter CONFIG_FULL depuis PureData (réponse à REQUEST_PUPITRE_CONFIG)
                // PureData envoie CONFIG_FULL via la connexion pupitre avec pupitreId
                if (data.type === 'CONFIG_FULL') {
                    console.log(`📥 CONFIG_FULL reçu depuis PureData pour ${pupitreId}, config:`, !!data.config, 'pupitreId dans message:', data.pupitreId);
                    if (data.config && this.handlePupitreConfig) {
                        // Convertir format PureData vers format attendu
                        const configData = this.convertPureDataConfigToPupitreConfig(data.config, data.pupitreId || pupitreId);
                        this.handlePupitreConfig(data.pupitreId || pupitreId, configData, true); // Toujours traiter comme demandé
                    } else {
                        console.warn(`⚠️ CONFIG_FULL reçu mais config manquant ou handlePupitreConfig non défini`);
                    }
                }
                
                // Traiter PUPITRE_STATUS qui contient la configuration complète du pupitre
                // Seulement si c'est une réponse à une demande (flag isRequested)
                if (data.type === 'PUPITRE_STATUS' && data.data && this.handlePupitreConfig) {
                    // isRequested = true si c'est une réponse explicite, false si c'est juste un heartbeat
                    const isRequested = data.isRequested || false;
                    this.handlePupitreConfig(pupitreId, data.data, isRequested);
                }
                
                // Traiter les messages d'état de lecture MIDI
                if (data.type === 'MIDI_PLAYBACK_STATE') {
                    this.playbackStates.set(pupitreId, data);
                    // console.log(`🎵 État lecture MIDI ${connection.pupitre.name}:`, data.playing ? 'PLAY' : 'STOP', '- Position:', data.position, 'ms');
                }
                
                // Ajouter au buffer global avec info pupitre
                this.eventBuffer.push({
                    timestamp: Date.now(),
                    pupitreId: pupitreId,
                    pupitreName: connection.pupitre.name,
                    data: data
                });
                
                // Limiter la taille du buffer
                if (this.eventBuffer.length > this.maxBufferSize) {
                    this.eventBuffer.shift();
                }
                
            } catch (e) {
                console.error(`❌ Erreur parsing message ${connection.pupitre.name} (${pupitreId}):`, e);
            }
        }
    }
    
    // Décoder messages binaires pour un pupitre spécifique
    handleBinaryMessage(pupitreId, buffer) {
        const connection = this.connections.get(pupitreId);
        if (!connection) return;
        
        // Vérifier si c'est un message VOLANT_STATE (7 bytes avec magic "SS")
        if (buffer.length === 7) {
            const magic1 = buffer.readUInt8(0);
            const magic2 = buffer.readUInt8(1);
            
            if (magic1 === 0x53 && magic2 === 0x53) { // Magic "SS"
                const type = buffer.readUInt8(2);
                const note = buffer.readUInt8(3);
                const velocity = buffer.readUInt8(4);
                const pitchbend = buffer.readUInt16BE(5);
                
                // console.log(`🎹 VOLANT_STATE ${connection.pupitre.name}: Type=${type}, Note=${note}, Velocity=${velocity}, Pitchbend=${pitchbend}`);
                
                if (type === 0x01) { // VOLANT_STATE
                    // Convertir note MIDI → fréquence → RPM (S3: transposition +1 octave, 8 sorties)
                    const frequency = this.midiToFrequency(note, pitchbend, 1); // +1 octave pour S3
                    const rpm = this.frequencyToRpm(frequency, 8); // 8 sorties pour S3
                    
                    // console.log(`🎹 Volant ${connection.pupitre.name}: Note=${note}, Velocity=${velocity}, Pitchbend=${pitchbend}, Freq=${frequency.toFixed(2)}Hz, RPM=${rpm.toFixed(1)}`);
                    
                    // Diffuser aux clients UI via le serveur
                    this.broadcastVolantData(pupitreId, note, velocity, pitchbend, frequency, rpm);
                }
                return;
            }
        }
        
        // Support JSON binaire brut (sans octet de type): commence par '{' (0x7B)
        if (buffer[0] === 0x7B) {
            try {
                const jsonStr = buffer.toString('utf8');
                const json = JSON.parse(jsonStr);
                // Accepter soit un wrapper CONFIG_FULL, soit la config directe
                const hasWrapper = json && (json.type === 'CONFIG_FULL' || json.config);
                const configPayload = hasWrapper ? (json.config || {}) : json;
                if (this.handlePupitreConfig && configPayload) {
                    console.log(`📥 CONFIG (binaire JSON brut) reçu pour ${connection.pupitre.name} (${pupitreId})`);
                    const configData = this.convertPureDataConfigToPupitreConfig(configPayload, pupitreId);
                    this.handlePupitreConfig(pupitreId, configData, true);
                    return;
                }
            } catch (e) {
                // Laisser continuer le traitement si ce n'est pas du JSON valide
            }
        }

        // Protocole strict SirenePupitre: header 8 octets (LE) + payload JSON chunk
        if (buffer.length >= 8) {
            const totalSize = buffer.readUInt32LE(0);
            const position  = buffer.readUInt32LE(4);
            const payload   = buffer.slice(8);
            if (totalSize > 0 && totalSize <= 10 * 1024 * 1024 && position >= 0 && position < totalSize) {
                let state = this.binaryChunkStates.get(pupitreId);
                if (!state || state.expectedSize !== totalSize) {
                    state = { expectedSize: totalSize, receivedBytes: 0, buffer: Buffer.allocUnsafe(totalSize) };
                    this.binaryChunkStates.set(pupitreId, state);
                }
                payload.copy(state.buffer, position);
                state.receivedBytes += payload.length;
                try { console.log(`🔹 Chunk SP ${connection.pupitre.name} (${pupitreId}): +${payload.length} @${position}, total=${state.receivedBytes}/${state.expectedSize}`); } catch (_) {}
                if (state.receivedBytes >= state.expectedSize) {
                    try {
                        const jsonString = state.buffer.toString('utf8');
                        const jsonData = JSON.parse(jsonString);
                        const hasWrapper = jsonData && (jsonData.type === 'CONFIG_FULL' || jsonData.config);
                        const configPayload = hasWrapper ? (jsonData.config || {}) : jsonData;
                        if (this.handlePupitreConfig && configPayload) {
                            const configData = this.convertPureDataConfigToPupitreConfig(configPayload, pupitreId);
                            this.handlePupitreConfig(pupitreId, configData, true);
                        }
                    } catch (e) {
                        console.error(`❌ Erreur parsing CONFIG_FULL (SP) ${connection.pupitre.name} (${pupitreId}):`, e);
                    } finally {
                        this.binaryChunkStates.delete(pupitreId);
                    }
                    return;
                }
                return;
            }
        }

        const messageType = buffer.readUInt8(0);
        
        // Initialiser playbackState pour ce pupitre si nécessaire
        if (!this.playbackStates.has(pupitreId)) {
            this.playbackStates.set(pupitreId, {
                type: 'MIDI_PLAYBACK_STATE',
                playing: false,
                position: 0,
                beat: 0,
                tempo: 120,
                timeSignature: { numerator: 4, denominator: 4 },
                duration: 0,
                totalBeats: 0,
                file: ""
            });
        }
        
        const playbackState = this.playbackStates.get(pupitreId);
        
        switch (messageType) {
            // case 0x00: // Désactivé: on n'utilise plus le type 0x00 pour CONFIG, on suit le protocole SP
            case 0x01: // POSITION (10 bytes, 50ms)
                if (buffer.length < 10) {
                    console.error(`❌ POSITION trop court ${connection.pupitre.name}:`, buffer.length, 'bytes (attendu 10)');
                    return;
                }
                const flags = buffer.readUInt8(1);
                playbackState.playing = (flags & 0x01) !== 0;
                const barNumber = buffer.readUInt16LE(2);
                const beatInBar = buffer.readUInt16LE(4);
                playbackState.beat = buffer.readFloatLE(6);
                
                // Calculer position en ms (beat * 60000 / tempo)
                const bpm = playbackState.tempo || 120;
                playbackState.position = Math.floor((playbackState.beat / bpm) * 60000);
                
                // Stocker bar/beat pour l'API
                playbackState.bar = barNumber;
                playbackState.beatInBar = beatInBar;
                
                // Log compact (max 1/sec par pupitre)
                const logKey = `pos_${pupitreId}`;
                if (!this[logKey] || Date.now() - this[logKey] > 1000) {
                    // console.log(`🎵 POSITION ${connection.pupitre.name} (10B):`, playbackState.playing ? 'PLAY' : 'STOP', 
                    //            '- Bar:', barNumber, 'Beat:', beatInBar, '/', playbackState.timeSignature?.numerator || 4,
                    //            '- Total:', playbackState.beat.toFixed(1));
                    this[logKey] = Date.now();
                }
                break;
                
            case 0x02: // FILE_INFO (10 bytes, au load)
                if (buffer.length < 10) {
                    console.error(`❌ FILE_INFO trop court ${connection.pupitre.name}:`, buffer.length, 'bytes (attendu 10)');
                    return;
                }
                playbackState.duration = buffer.readUInt32LE(2);
                playbackState.totalBeats = buffer.readUInt32LE(6);
                // console.log(`📁 FILE_INFO ${connection.pupitre.name} (10B): Durée:`, playbackState.duration, 'ms - Total beats:', playbackState.totalBeats);
                break;
                
            case 0x03: // TEMPO (3 bytes, quand change)
                if (buffer.length < 3) {
                    console.error(`❌ TEMPO trop court ${connection.pupitre.name}:`, buffer.length, 'bytes (attendu 3)');
                    return;
                }
                playbackState.tempo = buffer.readUInt16LE(1);
                // console.log(`🎼 TEMPO ${connection.pupitre.name} (3B):`, playbackState.tempo, 'BPM');
                break;
                
            case 0x04: // TIMESIG (3 bytes, quand change)
                // Attention: certains flux utilisent 0x04 sur 5 octets (note+duration) → ignorer
                if (buffer.length !== 3) {
                    // Ignorer formats inattendus pour éviter de corrompre l'UI
                    return;
                }
                playbackState.timeSignature.numerator = buffer.readUInt8(1);
                playbackState.timeSignature.denominator = buffer.readUInt8(2);
                // console.log(`🎵 TIMESIG ${connection.pupitre.name} (3B):`, 
                //           playbackState.timeSignature.numerator + '/' + 
                //           playbackState.timeSignature.denominator);
                break;
                
            case 0x06: // TICK_POSITION (6 ou 8 bytes) - Position en ticks pour PureData
                if (buffer.length < 6) {
                    console.error(`❌ TICK_POSITION trop court ${connection.pupitre.name}:`, buffer.length, 'bytes (attendu 6/8)');
                    return;
                }
                const tickFlags = buffer.readUInt8(1);
                playbackState.playing = (tickFlags & 0x01) !== 0;
                const tickPosition = buffer.readUInt32LE(2);
                // ppq optionnel (ancien format 8 octets). Ignoré si absent
                const tickPpq = buffer.length >= 8 ? buffer.readUInt16LE(6) : (playbackState.ppq || 480);
                
                // Stocker la position en ticks pour PureData
                playbackState.tick = tickPosition;
                playbackState.ppq = tickPpq;
                
                // Log compact (max 1/sec par pupitre)
                const tickLogKey = `tick_${pupitreId}`;
                if (!this[tickLogKey] || Date.now() - this[tickLogKey] > 1000) {
                    // console.log(`⏱️ TICK_POSITION ${connection.pupitre.name} (8B):`, playbackState.playing ? 'PLAY' : 'STOP', 
                    //            '- Tick:', tickPosition, '- PPQ:', tickPpq);
                    this[tickLogKey] = Date.now();
                }
                break;
                
            default:
                // console.warn(`⚠️ Type message binaire inconnu ${connection.pupitre.name}:`, '0x' + messageType.toString(16).padStart(2, '0'));
        }
        
        // Mettre à jour l'état
        this.playbackStates.set(pupitreId, playbackState);
    }
    
    // Convertir note MIDI → fréquence avec pitchbend et transposition
    midiToFrequency(note, pitchbend, transposition = 0) {
        // Appliquer la transposition (en octaves)
        const transposedNote = note + (transposition * 12);
        
        // Formule MIDI standard : f = 440 * 2^((note - 69) / 12)
        const baseFrequency = 440 * Math.pow(2, (transposedNote - 69) / 12);
        
        // Appliquer le pitchbend (0-16383, centre = 8192)
        const pitchbendFactor = (pitchbend - 8192) / 8192; // -1 à +1
        // Utiliser une échelle ±1 demi-ton pour cohérence UI
        const pitchbendSemitones = pitchbendFactor * 1.0; // ±1.0 demi-ton
        
        return baseFrequency * Math.pow(2, pitchbendSemitones / 12);
    }
    
    // Convertir fréquence → RPM pour chaque sirène
    frequencyToRpm(frequency, outputs) {
        return frequency * 60 / outputs;
    }
    
    // Diffuser les données du volant aux clients UI
    broadcastVolantData(pupitreId, note, velocity, pitchbend, frequency, rpm) {
        // Utiliser la fonction de diffusion directe
        if (this.broadcastToClients) {
            var continuousNote = note + ((pitchbend - 8192) / 8192);

            this.broadcastToClients({
                type: 'VOLANT_DATA',
                pupitreId: pupitreId,
                noteFloat: continuousNote,
                velocity: velocity,
                frequency: Math.round(frequency) | 0,
                rpm: Math.round(rpm) | 0,
                timestamp: Date.now()
            });
            // console.log(`📡 Diffusion terminée`);
        } else {
            // console.log(`❌ Impossible de diffuser: broadcastToClients=${!!this.broadcastToClients}`);
        }
    }
    
    // Envoyer une commande à un pupitre spécifique
    sendCommand(command, pupitreId = null) {
        console.log(`📤 sendCommand appelé - type: ${command.type}, pupitreId: ${pupitreId || 'all'}`);
        
        // Si pupitreId spécifié, envoyer à ce pupitre uniquement
        if (pupitreId) {
            const connection = this.connections.get(pupitreId);
            if (!connection || !connection.connected || !connection.websocket) {
                console.error(`❌ Pupitre ${pupitreId} non connecté - connection: ${!!connection}, connected: ${connection?.connected}, websocket: ${!!connection?.websocket}`);
                return false;
            }
            
            console.log(`📤 Envoi via sendToPupitre pour ${pupitreId}`);
            return this.sendToPupitre(pupitreId, command);
        }
        
        // Sinon, envoyer à tous les pupitres connectés
        let successCount = 0;
        let totalCount = 0;
        
        for (const [id, connection] of this.connections) {
            if (connection.connected && connection.websocket) {
                totalCount++;
                if (this.sendToPupitre(id, command)) {
                    successCount++;
                }
            }
        }
        
        // console.log(`📤 Commande envoyée à ${successCount}/${totalCount} pupitres`);
        return successCount > 0;
    }
    
    // Envoyer une commande à un pupitre spécifique
    sendToPupitre(pupitreId, command) {
        const connection = this.connections.get(pupitreId);
        if (!connection || !connection.connected || !connection.websocket) {
            console.error(`❌ sendToPupitre échoué pour ${pupitreId} - connection: ${!!connection}, connected: ${connection?.connected}, websocket: ${!!connection?.websocket}`);
            return false;
        }
        
        try {
            const message = JSON.stringify(command);
            console.log(`📤 Envoi à ${connection.pupitre.name} (${pupitreId}):`, message);
            
            // Envoyer en mode binaire comme SirenePupitre
            const buffer = Buffer.from(message, 'utf8');
            connection.websocket.send(buffer);
            
            console.log(`✅ Message envoyé avec succès à ${pupitreId}`);
            return true;
        } catch (error) {
            console.error(`❌ Erreur envoi ${connection.pupitre.name} (${pupitreId}):`, error);
            return false;
        }
    }
    
    // Récupérer les événements depuis le buffer
    getEvents(since = 0, pupitreId = null) {
        let events = this.eventBuffer.filter(event => event.timestamp > since);
        
        if (pupitreId) {
            events = events.filter(event => event.pupitreId === pupitreId);
        }
        
        return events;
    }
    
    // Vider le buffer
    clearEvents(pupitreId = null) {
        if (pupitreId) {
            this.eventBuffer = this.eventBuffer.filter(event => event.pupitreId !== pupitreId);
        } else {
            this.eventBuffer = [];
        }
    }
    
    // Obtenir le statut de toutes les connexions
    getStatus() {
        const status = {
            totalConnections: this.connections.size,
            connectedCount: 0,
            connections: []
        };
        
        for (const [pupitreId, connection] of this.connections) {
            const pupitreStatus = {
                pupitreId: pupitreId,
                pupitreName: connection.pupitre.name,
                connected: connection.connected,
                url: connection.url,
                lastSeen: connection.lastSeen
            };
            
            status.connections.push(pupitreStatus);
            
            if (connection.connected) {
                status.connectedCount++;
            }
        }
        
        return status;
    }
    
    // Obtenir l'état de lecture MIDI pour un pupitre ou global
    getPlaybackState(pupitreId = null) {
        if (pupitreId) {
            return this.playbackStates.get(pupitreId) || {
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
        
        // Retourner l'état global (moyenne de tous les pupitres)
        const states = Array.from(this.playbackStates.values());
        if (states.length === 0) {
            // Si aucun état pupitre, retourner l'état du séquenceur si disponible
            if (this.sequencerPlayback) {
                return {
                    playing: this.sequencerPlayback.playing,
                    position: 0,
                    beat: this.sequencerPlayback.beat,
                    tempo: 120,
                    timeSignature: { numerator: 4, denominator: 4 },
                    duration: 0,
                    totalBeats: 0,
                    file: "",
                    bar: this.sequencerPlayback.bar,
                    beatInBar: this.sequencerPlayback.beatInBar,
                };
            }
            return {
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
        
        // Calculer la moyenne des états
        const avgState = {
            playing: states.some(s => s.playing),
            position: Math.round(states.reduce((sum, s) => sum + s.position, 0) / states.length),
            beat: states.reduce((sum, s) => sum + s.beat, 0) / states.length,
            tempo: Math.round(states.reduce((sum, s) => sum + s.tempo, 0) / states.length),
            timeSignature: states[0].timeSignature, // Prendre le premier
            duration: Math.max(...states.map(s => s.duration)),
            totalBeats: Math.max(...states.map(s => s.totalBeats)),
            file: states[0].file // Prendre le premier
        };
        
        // Si un état séquenceur est disponible, forcer bar/beat globaux cohérents
        if (this.sequencerPlayback) {
            avgState.bar = this.sequencerPlayback.bar;
            avgState.beatInBar = this.sequencerPlayback.beatInBar;
            avgState.beat = this.sequencerPlayback.beat;
        }
        return avgState;
    }
    
    // Mettre à jour le nom du fichier dans playbackState
    updatePlaybackFile(filePath, pupitreId = null) {
        if (pupitreId) {
            const playbackState = this.playbackStates.get(pupitreId);
            if (playbackState) {
                playbackState.file = filePath;
                // console.log(`📁 Fichier MIDI mis à jour ${pupitreId}:`, filePath);
            }
        } else {
            // Mettre à jour tous les pupitres
            for (const [id, playbackState] of this.playbackStates) {
                playbackState.file = filePath;
            }
            // console.log('📁 Fichier MIDI mis à jour pour tous les pupitres:', filePath);
        }
    }
    
    // Broadcaster un buffer binaire directement
    broadcastBinaryToClients(buffer, pupitreId = null) {
        if (pupitreId) {
            // Envoyer à un pupitre spécifique
            const connection = this.connections.get(pupitreId);
            if (connection && connection.connected && connection.websocket) {
                try {
                    connection.websocket.send(buffer);
                    // Traiter localement aussi pour mettre à jour l'état
                    this.handleBinaryMessage(pupitreId, buffer);
                } catch (error) {
                    console.error(`❌ Erreur envoi binaire ${connection.pupitre.name} (${pupitreId}):`, error);
                }
            }
        } else {
            // Broadcaster à tous les pupitres connectés
            for (const [id, connection] of this.connections) {
                if (connection.connected && connection.websocket) {
                    try {
                        connection.websocket.send(buffer);
                        // Traiter localement aussi pour mettre à jour l'état
                        this.handleBinaryMessage(id, buffer);
                    } catch (error) {
                        console.error(`❌ Erreur envoi binaire ${connection.pupitre.name} (${id}):`, error);
                    }
                }
            }
        }
    }
    
    // Planifier une reconnexion pour un pupitre
    scheduleReconnect(pupitreId) {
        if (this.reconnectTimers.has(pupitreId)) return;
        
        const connection = this.connections.get(pupitreId);
        if (!connection) return;
        
        // console.log(`🔄 Reconnexion ${connection.pupitre.name} (${pupitreId}) dans`, this.reconnectInterval, 'ms');
        
        const timer = setTimeout(() => {
            this.reconnectTimers.delete(pupitreId);
            this.connectToPupitre(connection.pupitre);
        }, this.reconnectInterval);
        
        this.reconnectTimers.set(pupitreId, timer);
    }
    
    // Fermer toutes les connexions
    close() {
        // console.log('🔌 Fermeture de toutes les connexions');
        
        // Nettoyer les timers
        for (const timer of this.reconnectTimers.values()) {
            clearTimeout(timer);
        }
        this.reconnectTimers.clear();
        
        // Fermer les connexions
        for (const [pupitreId, connection] of this.connections) {
            if (connection.websocket) {
                connection.websocket.close();
            }
        }
        
        this.connections.clear();
    }
    
    // Gérer une connexion entrante d'un pupitre
    handleIncomingConnection(ws, pupitreId, pupitreInfo) {
        // console.log(`🔌 Connexion entrante du pupitre ${pupitreId}`);
        
        // Stocker la connexion
        this.connections.set(pupitreId, {
            websocket: ws,
            pupitre: pupitreInfo,
            url: `ws://incoming:${pupitreId}`,
            connected: true,
            lastSeen: new Date()
        });
        
        // Gestionnaires d'événements
        ws.on('close', () => {
            // console.log(`❌ Pupitre ${pupitreId} déconnecté`);
            const connection = this.connections.get(pupitreId);
            if (connection) {
                connection.connected = false;
                connection.lastSeen = null;
            }
        });
        
        ws.on('error', (error) => {
            console.error(`❌ Erreur WebSocket pupitre ${pupitreId}:`, error);
            const connection = this.connections.get(pupitreId);
            if (connection) {
                connection.connected = false;
                connection.lastSeen = null;
            }
        });
        
        ws.on('message', (data) => {
            this.handleMessage(pupitreId, data);
        });
    }
    
    // Vérifier la santé des connexions
    checkConnectionsHealth() {
        for (const [pupitreId, connection] of this.connections) {
            if (connection.connected && connection.websocket) {
                // Vérifier si la connexion WebSocket est toujours ouverte
                if (connection.websocket.readyState === WebSocket.CLOSED || 
                    connection.websocket.readyState === WebSocket.CLOSING) {
                    // console.log(`❌ Connexion ${pupitreId} fermée détectée`);
                    connection.connected = false;
                    connection.lastSeen = null;
                    
                    // Programmer une reconnexion
                    this.scheduleReconnect(pupitreId);
                } else if (connection.websocket.readyState === WebSocket.OPEN) {
                    // Envoyer un ping pour vérifier que la connexion est vivante
                    try {
                        connection.websocket.ping();
                        // Ping envoyé (log supprimé pour éviter le spam)
                    } catch (error) {
                        // console.log(`❌ Erreur ping ${pupitreId}:`, error.message);
                        connection.connected = false;
                        connection.lastSeen = null;
                        this.scheduleReconnect(pupitreId);
                    }
                } else {
                    // console.log(`⚠️ Connexion ${pupitreId} dans un état inattendu:`, connection.websocket.readyState);
                }
            }
        }
    }
    
    // Obtenir les pupitres connectés
    getConnectedPupitres() {
        const connected = [];
        for (const [pupitreId, connection] of this.connections) {
            if (connection.connected) {
                connected.push({
                    id: pupitreId,
                    name: connection.pupitre.name,
                    host: connection.pupitre.host,
                    lastSeen: connection.lastSeen
                });
            }
        }
        return connected;
    }
}

module.exports = PureDataProxy;