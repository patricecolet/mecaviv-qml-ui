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
        
        console.log('🎛️ PureDataProxy initialisé, URL:', this.pureDataUrl);
        
        this.connect();
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
        console.log('📥 Message de PureData:', message.substring(0, 100));
        
        try {
            const data = JSON.parse(message);
            
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

