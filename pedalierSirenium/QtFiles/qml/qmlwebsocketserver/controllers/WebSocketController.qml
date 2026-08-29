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

    // Réassemblage des chunks binaires "dumpBinary" (pdjson cote PD) -- porte de SirenePupitre/QML/controllers/WebSocketController.qml
    property var binaryBuffer: null      // Buffer pour stocker les bytes
    property int expectedSize: 0         // Taille totale attendue
    property int receivedBytes: 0        // Nombre de bytes deja recus
    
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
        resolveServerUrl();
    }

    // L'adresse de config.js est figée au build : elle ne peut pas savoir sur
    // quelle machine la page a été ouverte. On reprend l'hôte de la page, fourni
    // par main.cpp (`pageOrigin`), en gardant le port WebSocket de config.js.
    // Hors navigateur, pageOrigin est vide et config.js fait foi.
    function resolveServerUrl() {
        if (typeof pageOrigin !== "string" || pageOrigin === "") return;
        var host = pageOrigin.replace(/^https?:\/\//, "").split(":")[0];
        if (!host) return;
        var port = (root.serverUrl.split(":")[2] || "10000");
        var url = "ws://" + host + ":" + port;
        if (url === root.serverUrl) return;
        if (root.logger) root.logger.info("WEBSOCKET", "🌐 Serveur repris de l'hôte de la page :", url);
        root.serverUrl = url;   // rompt la liaison à config.js, socket.url suit
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
                // Format binaire config (dumpBinary cote PD): [totalSize:4][offset:4][data...], >= 8 octets.
                // Les messages MIDI bruts font 1-3 octets, donc la longueur suffit a distinguer les deux.
                if (bytes.length >= 8) {
                    const totalSize = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
                    const position = bytes[4] | (bytes[5] << 8) | (bytes[6] << 16) | (bytes[7] << 24);
                    const dataLength = bytes.length - 8;

                    if (!root.binaryBuffer || root.expectedSize !== totalSize) {
                        root.binaryBuffer = new Array(totalSize);
                        root.expectedSize = totalSize;
                        root.receivedBytes = 0;
                    }

                    for (let i = 0; i < dataLength; i++) {
                        root.binaryBuffer[position + i] = bytes[8 + i];
                    }
                    root.receivedBytes += dataLength;

                    if (root.receivedBytes >= totalSize) {
                        let jsonString = "";
                        for (let j = 0; j < totalSize; j++) {
                            jsonString += String.fromCharCode(root.binaryBuffer[j]);
                        }
                        try {
                            const jsonData = JSON.parse(jsonString);
                            if (jsonData.type === "CONFIG_FULL") {
                                root.batchReceived("config", jsonData.config);
                            }
                        } catch (parseErr) {
                            if (root.logger) root.logger.error("WEBSOCKET", "Erreur parsing config binaire:", parseErr.message);
                        }
                        root.binaryBuffer = null;
                        root.expectedSize = 0;
                        root.receivedBytes = 0;
                    }
                    return;
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
                    // Écho de la sortie choisie (v1/v2/dsp). PD la persiste dans
                    // `.sortie`, donc c'est lui qui dit la vérité au démarrage,
                    // pas la dernière valeur cliquée ici.
                    if (json.clic) {
                        root.batchReceived("clic", json.clic);
                    }
                    if (json.output) {
                        root.batchReceived("outputDevice", json.output);
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
                    if (json.composition) {
                        if (root.logger) root.logger.info("WEBSOCKET", "🎼 Composition reçue:", JSON.stringify(json.composition));
                        root.batchReceived("composition", json.composition);
                    }
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

                // SIRENIUM : la note jouée avant harmonisation ($0.harmoniseur.in
                // côté PD). Flux régulier — pas de log par événement.
                if (json.device === "SIRENIUM") {
                    root.batchReceived("sirenium", json);
                }

                // VOICE_SELECT : la sirène que la pédale key a mise en mono
                // ($0.loop.voice.select côté PD). siren 0 = mono désarmé.
                // Événement rare — un log par changement est sans danger.
                if (json.device === "VOICE_SELECT") {
                    if (root.logger) root.logger.debug("WEBSOCKET", "🎯 Mono → sirène", json.siren, "(voix", json.voice + ")");
                    root.batchReceived("voiceSelect", json);
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

            // PD redémarre sous la page à chaque déploiement (restart systemd).
            // Sans retentative la socket reste fermée, et main.qml bascule sur le
            // harnais de simulation : l'écran passe en démo et n'en revient jamais
            // sans recharger la page. On retente tant qu'on n'est pas ouvert.
            reconnectTimer.running = (socket.status !== WebSocket.Open);

            if (root.logger) {
                if (socket.status === WebSocket.Open) {
                    root.logger.info("WEBSOCKET", "Connecté à", root.serverUrl);
                    // Demander le preset courant dès la connexion
                    root.requestCurrentPreset();
                    // Demander la liste des scènes dès la connexion
                    root.requestScenesList();
                    // Et l'état du clic, que PD ne diffuse qu'au changement
                    root.requestClic();
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
    
    // Orchestre virtuel (composeSiren~ cote PD, mode DSP du selecteur
    // V1/V2/DSP existant dans pedalier.pd). "cmd" est deja au format que
    // composeSiren~ attend sur son inlet ("<id> volume|pan|dsp <valeur>") --
    // cote PD, pedalier.pd le renvoie tel quel, sans reconstruction. Un
    // message WebSocket = une commande.
    function sendOrchestraCommand(cmd) {
        return sendMessage({ device: "composeSiren", cmd: cmd });
    }

    function sendOrchestraDsp(voiceId, enabled) {
        return sendOrchestraCommand(voiceId + " dsp " + (enabled ? 1 : 0));
    }

    function sendOrchestraVolume(voiceId, volume) {
        return sendOrchestraCommand(voiceId + " volume " + volume);
    }

    function sendOrchestraPan(voiceId, pan) {
        return sendOrchestraCommand(voiceId + " pan " + pan);
    }

    // Retentative tant que la socket n'est pas ouverte. Se rallume tout seul par
    // onStatusChanged, s'éteint dès que PD répond — et `isConnected` repasse à
    // vrai, ce qui remet main.qml sur LiveState. À la réouverture, onStatusChanged
    // redemande déjà le preset et la liste des scènes : la vue se repeuple seule.
    property int reconnectDelayMs: 2000
    Timer {
        id: reconnectTimer
        interval: root.reconnectDelayMs
        repeat: true
        running: false
        onTriggered: {
            if (socket.status === WebSocket.Open) { running = false; return; }
            root.reconnect();
        }
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

    // Signature rythmique — nouveau message (voir docs/PD_WORK.md §7), PD doit
    // apprendre à le recevoir. Même namespace device/clock que le tempo.
    function sendSignatureChange(newSignature) {
        return sendMessage({
            device: "SIREN_LOOPER",
            clock: {
                signature: newSignature
            }
        });
    }
    
    // Sortie des sirènes : v1 (UDP), v2 (MIDI) ou dsp. PD la reçoit sur
    // `$0.siren.output.device` et la persiste ; il renvoie `output` en écho.
    function sendOutputDevice(dev) {
        if (logger) logger.info("SYSTEM", "🌐 sortie sirènes →", dev);
        return sendMessage({
            device: "SIREN_LOOPER",
            action: "outputDevice",
            output: dev
        });
    }

    // Choix de la sirène au doigt, sur l'écran tactile : exactement ce que fait
    // la touche piano du pédalier. PD reçoit le numéro de sirène (1..7), retrouve
    // sa voix dans `$0.voices` et pousse la ligne sur `$0.loop.voice.select` ;
    // -1 désarme le mono. Comme pour la sortie, l'écran ne décide pas — il
    // demande, et attend l'écho VOICE_SELECT pour se mettre à jour.
    function sendVoiceSelect(siren) {
        if (logger) logger.info("SYSTEM", "👆 sirène choisie →", siren);
        return sendMessage({
            device: "SIREN_LOOPER",
            action: "voiceSelect",
            siren: siren
        });
    }

    // Bascule du transport de scene — le meme geste que l'appui court sur CC 19.
    // PD decide : il lit son propre transport, lance ou coupe, et renvoie l'etat
    // dans le JSON d'horloge. L'ecran ne fait que demander.
    function sendScenePlayStop() {
        if (logger) logger.info("SYSTEM", "\u25B6 bascule transport de scene");
        return sendMessage({
            device: "SIREN_LOOPER",
            action: "scenePlayStop"
        });
    }

    // Les sockets UDP vers les sirenes sont ouvertes au chargement du patch et
    // ne se rouvrent jamais seules : sirenes eteintes a ce moment-la, le mode
    // UDP reste muet jusqu'au redemarrage. Ce verbe rejoue la connexion.
    function sendSirensConnect() {
        if (logger) logger.info("SYSTEM", "\u21BB reconnexion UDP des sirenes");
        return sendMessage({
            device: "SIREN_LOOPER",
            action: "sirensConnect"
        });
    }

    // L'etat du clic n'est diffuse qu'au changement : une page qui se connecte
    // apres le boot ne le connaitrait pas. Elle le demande donc a l'ouverture.
    function requestClic() {
        return sendMessage({ device: "SIREN_LOOPER", action: "clicGet" });
    }

    // Clic audible. PD applique, persiste dans config.json et renvoie l'echo.
    function sendClic(enable, volume) {
        if (logger) logger.info("SYSTEM", "\U0001F514 clic \u2192", enable ? "on" : "off", volume);
        return sendMessage({
            device: "SIREN_LOOPER",
            action: "clic",
            enable: enable ? 1 : 0,
            volume: volume
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

    // --- Gestion des scènes (page tactile → pd looperScenes.get → sceneEdit) ---
    // `n`, `src` et `dst` sont des positions de scène (1..N), pas des index de
    // bouton : la banque est dérivée côté PD. Après chaque édition PD republie
    // `scenesList` tout seul, rien à redemander ici.
    function sceneNew() {
        if (logger) logger.info("SCENES", "🌐 sceneNew");
        return sendMessage({ device: "LOOPER_SCENES", action: "sceneNew" });
    }
    function sceneLoad(n) {
        if (logger) logger.info("SCENES", "🌐 sceneLoad", n);
        return sendMessage({ device: "LOOPER_SCENES", action: "sceneLoad", n: n });
    }
    function sceneDelete(n) {
        if (logger) logger.info("SCENES", "🌐 sceneDelete", n);
        return sendMessage({ device: "LOOPER_SCENES", action: "sceneDelete", n: n });
    }
    // Les espaces passent : vérifié de bout en bout le 2026-07-31, un symbole
    // Pd les garde et le nom revient intact dans scenesList.
    function sceneRename(n, name) {
        var clean = String(name).trim();
        if (logger) logger.info("SCENES", "🌐 sceneRename", n, clean);
        return sendMessage({ device: "LOOPER_SCENES", action: "sceneRename", n: n, name: clean });
    }
    function sceneCopy(src, dst) {
        if (logger) logger.info("SCENES", "🌐 sceneCopy", src, "→", dst);
        return sendMessage({ device: "LOOPER_SCENES", action: "sceneCopy", src: src, dst: dst });
    }
    function sceneCellCopy(src, dst, siren) {
        if (logger) logger.info("SCENES", "🌐 sceneCellCopy", src, "→", dst, "S" + siren);
        return sendMessage({ device: "LOOPER_SCENES", action: "sceneCellCopy",
                             src: src, dst: dst, siren: siren });
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
