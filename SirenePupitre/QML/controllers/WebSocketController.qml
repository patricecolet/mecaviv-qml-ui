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
                
                // Format binaire simple pour les notes MIDI (3 bytes)
                if (bytes.length === 3 && bytes[0] === 0x03) {
                    // Format: [0x03, note, velocity] - LE SERVEUR ENVOIE NOTE PUIS VELOCITY !
                    var note = bytes[1];
                    var velocity = bytes[2];
                    
                    // Créer l'objet événement avec flag "sequence"
                    var event = {
                        midiNote: note,
                        note: note,
                        velocity: velocity,
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
