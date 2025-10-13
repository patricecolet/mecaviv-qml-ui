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
                
                if (bytes.length < 8) {
                    console.error("Message trop court:", bytes.length);
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
                    console.log("📊 Nouvelle réception:", totalSize, "bytes au total");
                }
                
                // Copier les données à la bonne position
                for (var i = 0; i < dataLength; i++) {
                    controller.binaryBuffer[position + i] = bytes[8 + i];
                }
                controller.receivedBytes += dataLength;
                
                var progress = Math.round((controller.receivedBytes / totalSize) * 100);
                console.log("📦 Chunk à position", position + ":", dataLength, 
                           "bytes | Total:", controller.receivedBytes + "/" + totalSize,
                           "(" + progress + "%)");
                
                // Vérifier si on a tout reçu
                if (controller.receivedBytes >= totalSize) {
                    console.log("✅ Réception complète !");
                    
                    // Reconstruire le JSON
                    var jsonString = "";
                    for (var j = 0; j < totalSize; j++) {
                        jsonString += String.fromCharCode(controller.binaryBuffer[j]);
                    }
                    
                    var jsonData = JSON.parse(jsonString);
                    if (jsonData.type === "CONFIG_FULL" && controller.configController) {
                        controller.configController.updateFullConfig(jsonData.config);
                        console.log("✅ Configuration mise à jour !");
                    }
                    
                    // Réinitialiser
                    controller.binaryBuffer = null;
                    controller.expectedSize = 0;
                    controller.receivedBytes = 0;
                }
            } catch (e) {
                console.error("❌ Erreur:", e);
            }
        }
        
        // Alternative plus simple si PureData envoie en texte les métadonnées
        onTextMessageReceived: function(message) {
            try {
                // Logs désactivés pour performance
                // console.log("📥 WebSocket reçu - Message brut:", message);
                
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
                            console.log("CONFIG_FULL reçu (BINARY_END)");
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
                        console.log("Début réception binaire (text):", controller.expectedSize, "octets");
                    }
                    return;
                }
                
                var data = JSON.parse(message);
                // Logs désactivés pour performance
                // console.log(" Données parsées:", JSON.stringify(data, null, 2));
                
                // Mettre à jour les statistiques
                controller.messageCount++
                var now = new Date()
                controller.lastMessageTime = now.toLocaleTimeString()
                
                // Logs désactivés pour performance
                // console.log("🏷️ Type de message:", data.type || "AUCUN");
                
                // Gestion de la présence de la console
                if (data.type === "CONSOLE_CONNECT") {
                    consoleConnected = true
                    if (controller.configController) controller.configController.consoleConnected = true
                    console.log("🎛️ Console connectée - priorité activée")
                    return
                }
                if (data.type === "CONSOLE_DISCONNECT") {
                    consoleConnected = false
                    if (controller.configController) controller.configController.consoleConnected = false
                    console.log("🎛️ Console déconnectée - retour mode autonome")
                    return
                }

                // AJOUTER : Traiter PARAM_UPDATE
                if (data.type === "PARAM_UPDATE") {
                    console.log("=== PARAM_UPDATE REÇU ===");
                    console.log("configController défini?", controller.configController ? "OUI" : "NON");
                    
                    // Tester directement l'appel
                    if (controller.configController) {
                        console.log("Test direct getValueAtPath:", 
                            controller.configController.getValueAtPath(["sirenConfig", "mode"], "default"));
                    }
                    
                    if (!controller.configController) {
                        console.error("❌ configController est null !");
                        return;
                    }
                    
                    if (!data.path || !Array.isArray(data.path)) {
                        console.error("❌ Path invalide ou manquant:", data.path);
                        return;
                    }
                    
                    if (data.value === undefined) {
                        console.error("❌ Value est undefined !");
                        return;
                    }
                    
                    // Afficher le chemin complet pour debug
                    console.log("📍 Chemin complet:", data.path.join(" -> "));
                    
                    // Appeler setValueAtPath et logger le résultat
                    try {
                        // Transmettre la source pour éviter les renvois inutiles
                        var result = controller.configController.setValueAtPath(data.path, data.value, data.source || "console");
                        console.log("✅ setValueAtPath résultat:", result ? "succès" : "échec");
                        
                        // Vérifier la valeur après modification
                        var newValue = controller.configController.getValueAtPath(data.path);
                        console.log("📊 Nouvelle valeur lue:", newValue, "- Type:", typeof newValue);
                        
                        if (newValue !== data.value && typeof newValue !== typeof data.value) {
                            console.log("⚠️ Conversion de type détectée:", typeof data.value, "->", typeof newValue);
                        }
                    } catch (e) {
                        console.error("❌ Erreur dans setValueAtPath:", e);
                    }
                    
                    console.log("=== FIN PARAM_UPDATE ===\n");
                    return;
                }
                
                // Après le bloc PARAM_UPDATE
                if (data.type === "CONFIG_FULL") {
                    console.log("CONFIG_FULL reçu de PureData");
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
                console.error("Erreur parsing JSON:", e);
            }
        }
        
        onStatusChanged: function(status) {
            if (controller.debugMode || status === WebSocket.Error) { // Toujours logger les erreurs
                switch(status) {
                    case WebSocket.Error:
                        console.error("WebSocket error:", socket.errorString);
                        break;
                    case WebSocket.Open:
                        console.log("WebSocket connected to", controller.serverUrl);
                        // Demander la configuration complète à PureData
                        controller.sendBinaryMessage({
                            type: "REQUEST_CONFIG"
                        });
                        console.log("REQUEST_CONFIG envoyé à PureData");
                        break;
                    case WebSocket.Closed:
                        console.log("WebSocket disconnected");
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
                console.log("Envoi message binaire:", JSON.stringify(message));
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
