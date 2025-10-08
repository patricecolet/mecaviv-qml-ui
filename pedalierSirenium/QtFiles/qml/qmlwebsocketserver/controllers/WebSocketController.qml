import QtQuick
import QtWebSockets
import QtNetwork
import "../config.js" as Config  // ← Import simple !

Item {
    id: root
    
    property var logger  // Logger passé depuis main
    property var mainWindow  // Référence vers la fenêtre principale
    property var midiMonitorController // Référence directe (évite l'accès via id)
    property string serverUrl: Config.websocketUrl  // ← Directement depuis config
    property bool isConnected: socket.status === WebSocket.Open
    property string connectionStatus: root.getStatusText()
    property color statusColor: root.getStatusColor()
    
    // Comptage des messages WebSocket
    property int wsMessageCount: 0
    property int wsMessagesPerSecond: 0
    
    // Parser de messages
    property alias messageParser: parser
    
    // Signaux - déclarés UNE SEULE FOIS
    signal messageReceived(var message)  // Pour compatibilité
    signal pathMessageReceived(var path, var value)
    signal socketStatusChanged(int status, string errorString)
    signal configurationChanged(string newUrl)
    signal batchReceived(string batchType, var data)  // ← Une seule déclaration ici
    
    MessageParser {
        id: parser
        logger: root.logger  // Passer le logger au parser
    }
    
    // Timer pour calculer les messages par seconde
    Timer {
        id: wsMessageTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            wsMessagesPerSecond = wsMessageCount
            wsMessageCount = 0
        }
    }
    
    Component.onCompleted: {
        setupMessageRoutes();
    }
    
    // Configuration des routes de messages
    function setupMessageRoutes() {
        // SIREN_LOOPER - Voices
        parser.createRouteGroup("device.SIREN_LOOPER.voices.[index]", {
            "channel": function(value, path, index) {
                root.pathMessageReceived(["voice", index, "channel"], value);
            },
            "enable": function(value, path, index) {
                root.pathMessageReceived(["voice", index, "enable"], value);
            },
            "pedal": function(value, path, index) {
                root.pathMessageReceived(["voice", index, "pedal"], value);
            }
        });
        
        // SIREN_LOOPER - Clock
        parser.createRouteGroup("device.SIREN_LOOPER.clock", {
            "bpm": function(value) {
                root.pathMessageReceived(["clock", "bpm"], value);
            },
            "beat": function(value) {
                root.pathMessageReceived(["clock", "beat"], value);
            },
            "bar": function(value) {
                root.pathMessageReceived(["clock", "bar"], value);
            }
        });
        
        // SIREN_LOOPER - Loops
        parser.registerRoute("device.SIREN_LOOPER.loops.[index].position", 
            function(value, path, index) {
                root.pathMessageReceived(["loop", index, "position"], value);
            }
        );
        
        parser.registerRoute("device.SIREN_LOOPER.loops.[index].size", 
            function(value, path, index) {
                root.pathMessageReceived(["loop", index, "size"], value);
            }
        );
        
        // SIREN_PEDALS - Presets
        parser.registerRoute("device.SIREN_PEDALS.presetList", 
            function(value) {
                root.pathMessageReceived(["presets", "list"], value);
            }
        );
        
        parser.registerRoute("device.SIREN_PEDALS.action", 
            function(value, path) {
                root.pathMessageReceived(["action"], value);
            }
        );
        
        parser.registerRoute("device.SIREN_PEDALS.name", 
            function(value) {
                root.pathMessageReceived(["preset", "name"], value);
            }
        );
        
        // SIREN_PEDALS - Configuration des pédales
        parser.registerRoute("device.SIREN_PEDALS.pedals", 
            function(value) {
                root.pathMessageReceived(["preset", "data"], value);
            }
        );
    }
    
    function getStatusText() {
        switch(socket.status) {
            case WebSocket.Connecting: return "Connexion en cours...";
            case WebSocket.Open: return "Connecté";
            case WebSocket.Closing: return "Fermeture de la connexion...";
            case WebSocket.Closed: return "Déconnecté";
            case WebSocket.Error: return "Erreur: " + socket.errorString;
            default: return "État inconnu";
        }
    }
    
    function getStatusColor() {
        switch(socket.status) {
            case WebSocket.Open: return "lime";
            case WebSocket.Connecting: return "yellow";
            case WebSocket.Error:
            case WebSocket.Closed: return "red";
            default: return "white";
        }
    }
    
    WebSocket {
        id: socket
        url: root.serverUrl
        active: true
        
        // Réception binaire: événements MIDI temps réel (1–3 octets)
        onBinaryMessageReceived: function(message) {
            // message est un ArrayBuffer
            try {
                const bytes = new Uint8Array(message);
                if (root.logger && bytes && bytes.length > 0 && root.logger.levelWebSocket >= root.logger.level_trace) {
                    const hex = Array.from(bytes).map(function(b){ return b.toString(16).padStart(2, "0"); }).join(" ");
                    root.logger.trace("WEBSOCKET", "binaire (len=" + bytes.length + "):", hex);
                }
                if (root.midiMonitorController && bytes.length > 0) {
                    root.midiMonitorController.applyExternalMidiBytes(bytes);
                }
            } catch (e) {
                if (root.logger) root.logger.error("WEBSOCKET", "Erreur binaire:", e.message);
            }
        }

        onTextMessageReceived: function(message) {
            // Incrémenter le compteur de messages
            wsMessageCount++
            
            if (root.logger) root.logger.debug("WEBSOCKET", "Message texte reçu:", message);
            try {
                let json = JSON.parse(message);
                
                // Log spécifique pour LOOPER_SCENES
                if (json.device === "LOOPER_SCENES") {
                    if (root.logger) root.logger.info("WEBSOCKET", "🎭 Message LOOPER_SCENES reçu:", JSON.stringify(json));
                }
                
                let isInitialLoad = json.device && 
                                   json.voices && 
                                   json.voices.length > 0 &&
                                   json.loops;
                
                root.messageReceived(json);
                
                // Traiter directement sans aplatir
                if (json.device === "SIREN_LOOPER") {
                    if (json.voices) {
                        root.batchReceived("voices", json.voices);
                    }
                    if (json.clock) {
                        root.batchReceived("clock", json.clock);
                    }
                    if (json.loops) {
                        root.batchReceived("loops", json.loops);
                    }
                } else if (json.device === "SIREN_PEDALS") {
                    if (json.presetList) {
                        root.batchReceived("presetList", json.presetList);
                    }
                    if (json.name && json.pedals) {
                        // Preset complet (getCurrentPreset ou loadPreset)
                        root.batchReceived("currentPreset", json);
                    } else if (json.pedals) {
                        // Données de preset sans nom (ancien format)
                        root.batchReceived("presets", { pedals: json.pedals });
                    }
                } else if (json.device === "LOOPER_SCENES") {
                    if (json.batch === "scenesList" && json.scenes) {
                        if (root.logger) root.logger.info("WEBSOCKET", "📋 ScenesList reçu avec", json.scenes.length, "scènes");
                        root.batchReceived("scenesList", json.scenes);
                    }
                    if (json.batch === "sceneLoaded") {
                        if (root.logger) root.logger.info("WEBSOCKET", "🎵 SceneLoaded reçu");
                        root.batchReceived("sceneLoaded", json);
                    }
                    if (json.batch === "sceneSaved") {
                        if (root.logger) root.logger.info("WEBSOCKET", "💾 SceneSaved reçu");
                        root.batchReceived("sceneSaved", json);
                    }
                    // Traitement des messages sans batch (comme loadScene)
                    if (json.action && !json.batch) {
                        if (root.logger) root.logger.info("WEBSOCKET", "🎭 Message LOOPER_SCENES sans batch reçu:", JSON.stringify(json));
                        if (messageRouter) {
                            messageRouter.routeSceneMessage(json);
                        } else {
                            if (root.logger) root.logger.error("WEBSOCKET", "❌ MessageRouter non disponible");
                        }
                    }
                }

                // Monitoring générique: sirenPings / sirenStates / performance
                if (json.sirenPings || json.sirenStates || json.performance || json.temperature || json.systemInfo) {
                    if (root.logger) root.logger.info("WEBSOCKET", "📊 Monitoring JSON reçu");
                    root.monitoringDataReceived(json);
                }

                
            } catch (e) {
                if (root.logger) root.logger.error("WEBSOCKET", "Erreur de parsing JSON:", e.message);
                logger.error("WEBSOCKET", "Erreur de parsing JSON:", e.message);
            }
        }

        property var clockBuffer: ({})
        property var voiceBuffer: ({})
        
        onStatusChanged: {
            root.connectionStatus = root.getStatusText();
            root.statusColor = root.getStatusColor();
            root.socketStatusChanged(socket.status, socket.errorString);
            
            if (root.logger) {
                if (socket.status === WebSocket.Open) {
                    root.logger.info("WEBSOCKET", "Connecté à", root.serverUrl);
                    // Demander le preset courant dès la connexion
                    root.requestCurrentPreset();
                    // Demander la liste des scènes dès la connexion
                    root.requestScenesList();
                } else if (socket.status === WebSocket.Error) {
                    root.logger.error("WEBSOCKET", "Erreur:", socket.errorString);
                } else if (socket.status === WebSocket.Closed) {
                    root.logger.warn("WEBSOCKET", "Déconnecté");
                }
            }
        }
    }
    
    // Connecter le signal batchReady
    Connections {
        target: parser
        function onBatchReady(batchType, data) {
            if (root.logger) {
                root.logger.info("BATCH", "Batch reçu:", batchType, "avec", Object.keys(data).length, "éléments");
                root.logger.debug("BATCH", "Batch prêt:", batchType, "avec", Object.keys(data).length, "éléments");
            }
            root.batchReceived(batchType, data);  // Utilise le signal déclaré en haut
        }
    }
    
    // PAS de deuxième déclaration de signal ici!
    
    // Surveiller les changements de serverUrl
    onServerUrlChanged: {
        if (socket.url !== serverUrl) {
            socket.url = serverUrl;
        }
    }
    
    function sendMessage(message) {
        if (socket.status === WebSocket.Open) {
            let jsonString = JSON.stringify(message);
            if (root.logger) root.logger.info("WEBSOCKET", "Envoi message:", jsonString);
            
            // Vérifier que tous les caractères sont ASCII (optionnel)
            for (let i = 0; i < jsonString.length; i++) {
                if (jsonString.charCodeAt(i) > 127) {
                    logger.warn("WEBSOCKET", "Caractère non-ASCII détecté:", jsonString[i]);
                }
            }
            
// @CRITICAL: Ne pas changer - binaire requis
            socket.sendBinaryMessage(jsonString);
            return true;
        } else {
            if (root.logger) {
                root.logger.error("WEBSOCKET", "Non connecté, impossible d'envoyer le message");
            }
            return false;
        }
    }
    
    function sendPedalConfig(pedalId, sirenId, controllerType) {
        let configMessage = {
            device: "SIREN_LOOPER",
            pedalConfig: {
                pedalId: pedalId,
                sirenId: sirenId,
                controllerType: controllerType
            }
        };
        return sendMessage(configMessage);
    }
    
    function reconnect() {
        if (root.logger) {
            root.logger.info("WEBSOCKET", "Reconnexion vers:", serverUrl);
        }
        var reconnectTimer = Qt.createQmlObject('import QtQuick; Timer {interval: 100; repeat: false; running: true}',
                                               root, 'dynamicTimer');
        socket.active = false;
        reconnectTimer.triggered.connect(function() {
            socket.active = true;
            reconnectTimer.destroy();
        });
    }
    
    function sendTempoChange(newTempo) {
        return sendMessage({
            device: "SIREN_LOOPER",
            clock: {
                bpm: newTempo
            }
        });
    }
    
    // Fonction utilitaire pour recharger la configuration manuellement
    function reloadConfiguration() {
        configLoaded = false;
        loadConfiguration();
    }
    
    function savePreset(name, data) {
        return sendMessage({
            device: "SIREN_PEDALS",
            action: "savePreset",
            presetName: name
        });
    }

    function loadPreset(name) {
        return sendMessage({
            device: "SIREN_PEDALS",
            action: "loadPreset",
            presetName: name
        });
    }

    function requestPresetList() {
        return sendMessage({
            device: "SIREN_PEDALS",
            action: "getPresetList"
        });
    }

    function deletePreset(presetName) {
        if (root.logger) {
            root.logger.info("PRESET", "Suppression du preset:", presetName);
        }
        return sendMessage({
            device: "SIREN_PEDALS",
            action: "deletePreset",
            presetName: presetName
        });
    }

    function requestCurrentPreset() {
        if (logger) logger.info("PRESET", "🌐 Envoi de getCurrentPreset");
        return sendMessage({
            device: "SIREN_PEDALS",
            action: "getCurrentPreset"
        });
    }

    // Nouvelle fonction pour demander la liste des scènes
    function requestScenesList() {
        if (logger) logger.info("SCENES", "🌐 Envoi de getScenesList");
        return sendMessage({
            device: "LOOPER_SCENES",
            action: "getScenesList"
        });
    }

    // Nouvelles fonctions de monitoring
    function enableMonitoring(types, frequency) {
        if (!types || types.length === 0) {
            types = ["sirenStates", "performance", "temperature"]
        }
        if (!frequency) frequency = 100
        
        var message = {
            device: "SIREN_PEDALS",
            action: "enableMonitoring",
            types: types,
            frequency: frequency
        }
        
        logger.log("WEBSOCKET", "INFO", "🔔 Activation monitoring: " + JSON.stringify(types) + " (" + frequency + "ms)")
        sendMessage(message)
    }
    
    function disableMonitoring() {
        var message = {
            device: "SIREN_PEDALS", 
            action: "disableMonitoring"
        }
        
        logger.log("WEBSOCKET", "INFO", "🔕 Désactivation monitoring")
        sendMessage(message)
    }
    
    // Signal pour notifier les composants de monitoring
    signal monitoringDataReceived(var data)
}
