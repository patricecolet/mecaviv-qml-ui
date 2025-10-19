import QtQuick
import QtWebSockets

Item {
    id: controller
    
    // Flag de debug
    property bool debugMode: false
    
    // WebSocket
    property string serverUrl: "ws://127.0.0.1:10002"
    property alias active: socket.active
    property alias status: socket.status
    property bool connected: socket.status === WebSocket.Open
    // Priorité console
    property bool consoleConnected: false
    
    // Statistiques
    property int messageCount: 0
    property string lastMessageTime: ""
    
    // Signal émis quand on reçoit des données
    signal dataReceived(var data)
    signal configReceived(var config)
    signal controlChangeReceived(int ccNumber, int ccValue)  // Signal pour les CC MIDI
    property var configController: null
    
    // Propriétés pour la réception binaire
    property var binaryBuffer: null      // Buffer pour stocker les bytes
    property int expectedSize: 0         // Taille totale attendue
    property int receivedBytes: 0        // Nombre de bytes déjà reçus
    
    WebSocket {
        id: socket
        url: controller.serverUrl
        active: false
        
        onBinaryMessageReceived: function(message) {
            try {
                var bytes = new Uint8Array(message);
                
                // Format binaire pour CONTROLLERS (type 0x02, 16 bytes) - CONTRÔLEURS PHYSIQUES
                if (bytes.length === 16 && bytes[0] === 0x02) {
                    // Décoder les données
                    // Volant position (uint16, déjà en degrés 0-360)
                    var wheelPos = bytes[1] | (bytes[2] << 8);
                    
                    // Pads (2 pads distincts)
                    var pad1After = bytes[3];
                    var pad1Vel = bytes[4];
                    var pad2After = bytes[5];
                    var pad2Vel = bytes[6];
                    
                    // Joystick (int8 signés)
                    var joyX = bytes[7];
                    if (joyX > 127) joyX -= 256;
                    var joyY = bytes[8];
                    if (joyY > 127) joyY -= 256;
                    var joyZ = bytes[9];
                    if (joyZ > 127) joyZ -= 256;
                    
                    // Joystick bouton
                    var joyBtn = bytes[10] > 0 ? 1 : 0;
                    
                    // Sélecteur 5 vitesses (0-4)
                    var selector = bytes[11];
                    
                    // Fader et pédale
                    var fader = bytes[12];
                    var pedal = bytes[13];
                    
                    // Boutons supplémentaires
                    var btn1 = bytes[14] > 0 ? 1 : 0;
                    var btn2 = bytes[15] > 0 ? 1 : 0;
                    
                    // Mapper le mode GearShift (5 positions)
                    var gearModeNames = ["SEMITONE", "THIRD", "MINOR_SIXTH", "OCTAVE", "DOUBLE_OCTAVE"];
                    var gearModeName = gearModeNames[selector] || "SEMITONE";
                    
                    // Créer l'objet contrôleurs
                    var controllers = {
                        wheel: {
                            position: wheelPos,  // 0-360 degrés (déjà converti par PureData)
                            velocity: 0  // Non disponible dans ce format
                        },
                        joystick: {
                            x: joyX,
                            y: joyY,
                            z: joyZ,
                            button: joyBtn === 1
                        },
                        gearShift: {
                            position: selector,      // 0-4 (5 vitesses)
                            mode: gearModeName
                        },
                        fader: {
                            value: fader
                        },
                        modPedal: {
                            value: pedal,
                            percent: (pedal / 127.0) * 100.0
                        },
                        pad1: {
                            velocity: pad1Vel,
                            aftertouch: pad1After,
                            active: pad1Vel > 0
                        },
                        pad2: {
                            velocity: pad2Vel,
                            aftertouch: pad2After,
                            active: pad2Vel > 0
                        },
                        buttons: {
                            button1: btn1 === 1,
                            button2: btn2 === 1
                        }
                    };
                    
                    // Émettre via dataReceived avec un flag
                    controller.dataReceived({
                        controllers: controllers,
                        isControllersOnly: true,  // Flag pour identifier ce type de message
                        timestamp: Date.now()
                    });
                    
                    return;
                }
                
                // Format binaire pour Control Change (3 bytes) - CC MIDI SÉQUENCE
                if (bytes.length === 3 && bytes[0] === 0x05) {
                    // Format: [0x05, CC_number, value]
                    var ccNumber = bytes[1];
                    var ccValue = bytes[2];  // 0-127
                    
                    // Émettre un signal pour les CC de séquence
                    controller.controlChangeReceived(ccNumber, ccValue);
                    return;
                }
                
                // Format binaire optimisé pour les notes MIDI avec durée (5 bytes)
                if (bytes.length === 5 && bytes[0] === 0x04) {
                    // Format: [0x04, note, velocity, duration_lsb, duration_msb]
                    var note = bytes[1];
                    var velocity = bytes[2];
                    var duration = bytes[3] + (bytes[4] << 8);  // Durée en ms (16 bits, max 65535ms = 65.5s)
                    
                    // Créer l'objet événement avec durée
                    var event = {
                        midiNote: note,
                        note: note,
                        velocity: velocity,
                        duration: duration,
                        timestamp: Date.now(),
                        controllers: {},
                        isSequence: true  // Flag pour différencier séquence/contrôleurs
                    };
                    
                    // Transmettre l'événement
                    controller.dataReceived(event);
                    return;
                }
                
                // Format binaire config (8+ bytes)
                if (bytes.length < 8) {
                    return;
                }
                
                // Décoder les métadonnées (toujours présentes)
                var totalSize = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
                var position = bytes[4] | (bytes[5] << 8) | (bytes[6] << 16) | (bytes[7] << 24);
                
                // Les données commencent à l'index 8
                var dataLength = bytes.length - 8;
                
                // Initialiser le buffer si nécessaire
                if (!controller.binaryBuffer || controller.expectedSize !== totalSize) {
                    controller.binaryBuffer = new Array(totalSize);
                    controller.expectedSize = totalSize;
                    controller.receivedBytes = 0;
                }
                
                // Copier les données à la bonne position
                for (var i = 0; i < dataLength; i++) {
                    controller.binaryBuffer[position + i] = bytes[8 + i];
                }
                controller.receivedBytes += dataLength;
                
                // Vérifier si on a tout reçu
                if (controller.receivedBytes >= totalSize) {
                    
                    // Reconstruire le JSON
                    var jsonString = "";
                    for (var j = 0; j < totalSize; j++) {
                        jsonString += String.fromCharCode(controller.binaryBuffer[j]);
                    }
                    
                    var jsonData = JSON.parse(jsonString);
                    if (jsonData.type === "CONFIG_FULL" && controller.configController) {
                        controller.configController.updateFullConfig(jsonData.config);
                    }
                    
                    // Réinitialiser
                    controller.binaryBuffer = null;
                    controller.expectedSize = 0;
                    controller.receivedBytes = 0;
                }
            } catch (e) {
            }
        }
        
        // Alternative plus simple si PureData envoie en texte les métadonnées
        onTextMessageReceived: function(message) {
            try {
                // Logs désactivés pour performance
                
                // Gérer les messages de contrôle binaire
                if (message === "BINARY_END") {
                    if (controller.receivingBinary && controller.binaryBuffer.length > 0) {
                        // Forcer le traitement même si incomplet
                        var jsonString = "";
                        for (var i = 0; i < controller.binaryBuffer.length; i++) {
                            jsonString += String.fromCharCode(controller.binaryBuffer[i]);
                        }
                        
                        var jsonData = JSON.parse(jsonString);
                        if (jsonData.type === "CONFIG_FULL") {
                            if (controller.configController && jsonData.config) {
                                controller.configController.updateFullConfig(jsonData.config);
                            }
                        }
                        
                        controller.receivingBinary = false;
                        controller.binaryBuffer = [];
                    }
                    return;
                }
                
                // Gérer BINARY_START si envoyé en texte
                if (message.startsWith("BINARY_START")) {
                    var parts = message.split(" ");
                    if (parts.length >= 3) {
                        controller.expectedSize = parseInt(parts[1]);
                        controller.chunkSize = parseInt(parts[2]);
                        controller.binaryBuffer = [];
                        controller.receivingBinary = true;
                    }
                    return;
                }
                
                var data = JSON.parse(message);
                // Logs désactivés pour performance
                
                // Mettre à jour les statistiques
                controller.messageCount++
                var now = new Date()
                controller.lastMessageTime = now.toLocaleTimeString()
                
                // Logs désactivés pour performance
                
                // Gestion de la présence de la console
                if (data.type === "CONSOLE_CONNECT") {
                    consoleConnected = true
                    if (controller.configController) controller.configController.consoleConnected = true
                    return
                }
                if (data.type === "CONSOLE_DISCONNECT") {
                    consoleConnected = false
                    if (controller.configController) controller.configController.consoleConnected = false
                    return
                }

                // AJOUTER : Traiter PARAM_UPDATE
                if (data.type === "PARAM_UPDATE") {
                    
                    if (!controller.configController) {
                        return;
                    }
                    
                    if (!data.path || !Array.isArray(data.path)) {
                        return;
                    }
                    
                    if (data.value === undefined) {
                        return;
                    }
                    
                    // Afficher le chemin complet pour debug
                    
                    // Appeler setValueAtPath et logger le résultat
                    try {
                        // Transmettre la source pour éviter les renvois inutiles
                        var result = controller.configController.setValueAtPath(data.path, data.value, data.source || "console");
                        
                        // Vérifier la valeur après modification
                        var newValue = controller.configController.getValueAtPath(data.path);
                        
                        if (newValue !== data.value && typeof newValue !== typeof data.value) {
                        }
                    } catch (e) {
                    }
                    
                    return;
                }
                
                // Après le bloc PARAM_UPDATE
                if (data.type === "CONFIG_FULL") {
                    if (controller.configController && data.config) {
                        controller.configController.updateFullConfig(data.config);
                    }
                    return;
                }
                
                // Code existant pour MUSIC_VISUALIZER
                if (data.device === "MUSIC_VISUALIZER") {
                    // Logs désactivés pour performance
                    if (data.config) {
                        controller.configReceived(data.config);
                    } else {
                        controller.dataReceived(data);
                    }
                } else {
                    // Logs désactivés pour performance
                    // Essayer de traiter comme données musicales par défaut
                    if (data.midiNote !== undefined || data.controllers) {
                        controller.dataReceived(data);
                    }
                }
            } catch (e) {
            }
        }
        
        onStatusChanged: function(status) {
            if (controller.debugMode || status === WebSocket.Error) { // Toujours logger les erreurs
                switch(status) {
                    case WebSocket.Error:
                        break;
                    case WebSocket.Open:
                        // Demander la configuration complète à PureData
                        controller.sendBinaryMessage({
                            type: "REQUEST_CONFIG"
                        });
                        break;
                    case WebSocket.Closed:
                        break;
                }
            }
        }
    }
    
    // Auto-connexion au démarrage
    Component.onCompleted: {
        connect();
    }
    
    // Fonctions de contrôle
    function connect() {
        socket.active = true;
    }
    
    function disconnect() {
        socket.active = false;
    }
    
    function reconnect() {
        socket.active = false;
        socket.active = true;
    }
    
    function sendBinaryMessage(message) {
        if (socket.status === WebSocket.Open) {
            if (controller.debugMode) {
            }
            // Convertir le JSON en string puis en binaire
            var jsonString = JSON.stringify(message);
            socket.sendBinaryMessage(jsonString);
        }
    }

    // Garder sendMessage pour compatibilité si besoin
    function sendMessage(message) {
        // Utiliser sendBinaryMessage par défaut maintenant
        sendBinaryMessage(message);
    }
}
