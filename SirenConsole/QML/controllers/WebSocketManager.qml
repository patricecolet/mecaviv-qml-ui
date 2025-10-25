import QtQuick 2.15
import QtWebSockets 1.0

// WebSocketManager pour SirenConsole
// Gère les connexions WebSocket vers les pupitres SirenePupitre
Item {
    id: webSocketManager
    
    // === PROPRIÉTÉS ===
    property var connections: ({})
    property var consoleController: null
    property bool pureDataConnected: false
    
    // WebSocket vers le serveur Node.js
    property var webSocket: null
    property bool connected: false
    property string serverUrl: "ws://localhost:8001/ws"
    
    // === SIGNAUX ===
    signal connectionOpened(string url)
    signal connectionClosed(string url)
    signal messageReceived(string url, string message)
    signal errorOccurred(string url, string error)
    
    // === TIMER DE VÉRIFICATION ===
    Timer {
        id: statusTimer
        interval: 2000 // Vérifier toutes les 2 secondes
        running: true
        repeat: true
        onTriggered: {
            // Garder le polling HTTP comme backup
            webSocketManager.checkPureDataStatus()
            webSocketManager.checkPupitresStatus()
            
            // Envoyer un ping WebSocket pour maintenir la connexion
            if (webSocketManager.connected) {
                webSocketManager.sendMessage({
                    type: "PING",
                    source: "SIRENCONSOLE_QML",
                    timestamp: Date.now()
                })
            }
        }
    }
    
    // === MÉTHODES PRIVÉES ===
    
    // Créer et configurer la connexion WebSocket
    function createWebSocket() {
        if (webSocket) {
            webSocket.destroy()
        }
        
        webSocket = Qt.createQmlObject('
            import QtWebSockets 1.0
            WebSocket {
                id: ws
                url: "' + serverUrl + '"
                active: true
                
                onStatusChanged: function(status) {
                    if (status === WebSocket.Open) {
                        webSocketManager.connected = true
                        webSocketManager.connectionOpened(url)
                        console.log("🔌 WebSocket connecté au serveur Node.js")
                    } else if (status === WebSocket.Closed) {
                        webSocketManager.connected = false
                        webSocketManager.connectionClosed(url)
                        console.log("❌ WebSocket déconnecté du serveur Node.js")
                    } else if (status === WebSocket.Error) {
                        webSocketManager.connected = false
                        webSocketManager.errorOccurred(url, "Erreur connexion WebSocket")
                        console.log("❌ Erreur WebSocket:", errorString)
                    }
                }
                
                onTextMessageReceived: function(message) {
                    webSocketManager.handleWebSocketMessage(message)
                }
            }
        ', webSocketManager)
    }
    
    // Gérer les messages WebSocket reçus
    function handleWebSocketMessage(message) {
        console.log("📥 Message WebSocket reçu:", message.substring(0, 100))
        
        try {
            var data = JSON.parse(message)
            console.log("📥 Type de message:", data.type)
            
            // Traiter les messages du serveur
            switch (data.type) {
                case "PONG":
                    // Pong reçu (log supprimé pour éviter le spam)
                    break
                case "INITIAL_STATUS":
                    console.log("📊 Statut initial reçu:", data.data)
                    // Mettre à jour les statuts initiaux des pupitres
                    if (data.data && data.data.connections && consoleController) {
                        for (var i = 0; i < data.data.connections.length; i++) {
                            var pupitreStatus = data.data.connections[i]
                            var statusText = pupitreStatus.connected ? "connected" : "disconnected"
                            consoleController.pupitreStatusChanged(pupitreStatus.pupitreId, statusText)
                        }
                    }
                    break
                case "PUPITRE_STATUS_UPDATE":
                    console.log("🎛️ Mise à jour pupitres:", data.data)
                    console.log("📊 Connected count:", data.data.connectedCount)
                    console.log("📊 Total connections:", data.data.totalConnections)
                    // Mettre à jour les statuts des pupitres dans l'interface
                    if (data.data && data.data.connections && consoleController) {
                        console.log("🎛️ consoleController trouvé, mise à jour des statuts")
                        for (var i = 0; i < data.data.connections.length; i++) {
                            var pupitreStatus = data.data.connections[i]
                            console.log("🎛️ Pupitre", pupitreStatus.pupitreId, "connected:", pupitreStatus.connected)
                            var statusText = pupitreStatus.connected ? "connected" : "disconnected"
                            console.log("🎛️ Appel updatePupitreStatus pour", pupitreStatus.pupitreId, "avec status:", statusText)
                            consoleController.updatePupitreStatus(pupitreStatus.pupitreId, statusText)
                        }
                    } else {
                        console.log("❌ consoleController non trouvé ou données manquantes")
                        console.log("❌ consoleController:", consoleController)
                        console.log("❌ data.data:", data.data)
                        console.log("❌ data.data.connections:", data.data ? data.data.connections : "undefined")
                    }
                    break
                case "VOLANT_DATA":
                    console.log("🎹 Données volant reçues:", data)
                    // Mettre à jour les données du volant
                    if (consoleController && data.note !== undefined) {
                        consoleController.updateVolantData(
                            data.note, 
                            data.velocity || 0, 
                            data.pitchbend || 8192, 
                            data.frequency || 261.63, 
                            data.rpm || 1308.15
                        )
                    }
                    break
                default:
                    console.log("📨 Autre message reçu:", data.type)
            }
        } catch (e) {
            console.log("📦 Message non-JSON reçu:", message.substring(0, 50))
        }
        
        messageReceived(serverUrl, message)
    }
    
    // Vérifier le statut de la connexion PureData (via HTTP)
    function checkPureDataStatus() {
        var xhr = new XMLHttpRequest()
        var self = webSocketManager
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var status = JSON.parse(xhr.responseText)
                    self.pureDataConnected = status.connected
                } catch (e) {
                    // Ignorer erreur silencieusement
                }
            }
        }
        xhr.open("GET", "http://localhost:8001/api/puredata/status")
        xhr.send()
    }
    
    // Vérifier le statut des pupitres (pour les LEDs)
    function checkPupitresStatus() {
        var xhr = new XMLHttpRequest()
        var self = webSocketManager
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var status = JSON.parse(xhr.responseText)
                    // Statut pupitres mis à jour
                    
                    // Mettre à jour le statut de chaque pupitre
                    for (var i = 0; i < status.connections.length; i++) {
                        var pupitreStatus = status.connections[i]
                        var statusText = pupitreStatus.connected ? "connected" : "disconnected"
                        
                        // Notifier le ConsoleController du changement de statut
                        if (self.consoleController) {
                            self.consoleController.pupitreStatusChanged(pupitreStatus.pupitreId, statusText)
                        }
                    }
                } catch (e) {
                    // Erreur parsing statut pupitres
                }
            }
        }
        xhr.open("GET", "http://localhost:8001/api/pupitres/status")
        xhr.send()
    }
    
    // === MÉTHODES PUBLIQUES ===
    
    // Se connecter au serveur Node.js
    function connect() {
        console.log("🔌 Connexion au serveur Node.js:", serverUrl)
        createWebSocket()
        return true
    }
    
    // Se déconnecter du serveur Node.js
    function disconnect() {
        if (webSocket) {
            webSocket.active = false
            webSocket.destroy()
            webSocket = null
        }
        connected = false
        console.log("❌ Déconnecté du serveur Node.js")
    }
    
    // Envoyer un message au serveur Node.js
    function sendMessage(message) {
        if (!connected || !webSocket) {
            console.error("❌ WebSocket non connecté")
            return false
        }
        
        var messageStr = typeof message === 'string' ? message : JSON.stringify(message)
        // Log supprimé pour éviter le spam des ping/pong
        
        webSocket.sendTextMessage(messageStr)
        return true
    }
    
    // Envoyer une commande à PureData (via HTTP POST au proxy) - MÉTHODE LEGACY
    function sendPureDataCommand(message) {
        // Envoi commande via proxy HTTP (legacy)
        
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://localhost:8001/api/puredata/command")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(message)
        
        return true // Toujours retourner true (async)
    }
    
    // Connexion à un pupitre
    function connectToPupitre(host, port, pupitreId) {
        // Connexion pupitre
        
        // 1. D'abord vérifier que SirenePupitre répond sur le port 8000
        // Vérification SirenePupitre
        
        var xhr = new XMLHttpRequest()
        var self = webSocketManager
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    // SirenePupitre répond
                    
                    // 2. Utiliser le proxy Node.js pour la connexion WebSocket
                    // Connexion via proxy Node.js
                    
                    // Stocker la connexion simulée (le proxy Node.js gère le vrai WebSocket)
                    self.connections[pupitreId] = {
                        websocket: null, // Pas de WebSocket direct
                        url: "ws://" + host + ":10002",
                        host: host,
                        port: 10002,
                        connected: true // Le proxy Node.js gère la connexion
                    }
                    
                    // Connexion simulée via proxy
                    self.connectionOpened(self.connections[pupitreId].url)
                    if (self.consoleController) {
                        self.consoleController.pupitreStatusChanged(pupitreId, "connected")
                    }
                    
                } else {
                    // SirenePupitre ne répond pas
                    if (self.consoleController) {
                        self.consoleController.pupitreStatusChanged(pupitreId, "disconnected")
                    }
                }
            }
        }
        xhr.open("GET", "http://" + host + ":8000/", true)
        xhr.send()
        
        return true
    }
    
    // Déconnexion d'un pupitre
    function disconnectFromPupitre(pupitreId) {
        if (webSocketManager.connections[pupitreId]) {
            // Déconnexion pupitre
            
            if (webSocketManager.connections[pupitreId].websocket) {
                webSocketManager.connections[pupitreId].websocket.close()
            }
            
            webSocketManager.connections[pupitreId].connected = false
            webSocketManager.connectionClosed(webSocketManager.connections[pupitreId].url)
            
            // Mettre à jour le statut du pupitre
            if (webSocketManager.consoleController) {
                webSocketManager.consoleController.pupitreStatusChanged(pupitreId, "disconnected")
            }
            
            delete webSocketManager.connections[pupitreId]
        }
    }
    
    // Déconnexion de tous les pupitres
    function disconnectAll() {
        // Déconnexion de tous les pupitres
        for (var pupitreId in webSocketManager.connections) {
            webSocketManager.disconnectFromPupitre(pupitreId)
        }
    }
    
    // Vérifier si un pupitre est connecté
    function isConnected(pupitreId) {
        return webSocketManager.connections[pupitreId] && webSocketManager.connections[pupitreId].connected
    }
    
    // Obtenir les connexions actives
    function getActiveConnections() {
        var active = []
        for (var pupitreId in webSocketManager.connections) {
            if (webSocketManager.connections[pupitreId].connected) {
                active.push({
                    pupitreId: pupitreId,
                    url: webSocketManager.connections[pupitreId].url,
                    host: webSocketManager.connections[pupitreId].host,
                    port: webSocketManager.connections[pupitreId].port
                })
            }
        }
        return active
    }
    
    // Envoyer un message à un pupitre spécifique
    function sendToPupitre(pupitreId, message) {
        if (webSocketManager.connections[pupitreId] && webSocketManager.connections[pupitreId].connected) {
            var ws = webSocketManager.connections[pupitreId].websocket
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send(message)
                // Message envoyé
                return true
            }
        }
        // Pupitre non connecté
        return false
    }
    
    // Envoyer un message à tous les pupitres connectés
    function broadcast(message) {
        var sent = 0
        for (var pupitreId in webSocketManager.connections) {
            if (webSocketManager.sendToPupitre(pupitreId, message)) {
                sent++
            }
        }
        // Message broadcast envoyé
        return sent
    }
    
    // === TIMER D'IDENTIFICATION ===
    Timer {
        id: identificationTimer
        interval: 1000 // Attendre 1 seconde que la connexion soit établie
        running: false
        repeat: false
        onTriggered: {
            if (webSocketManager.connected) {
                console.log("🔑 Envoi identification SirenConsole QML")
                webSocketManager.sendMessage({
                    type: "SIRENCONSOLE_IDENTIFICATION",
                    source: "SIRENCONSOLE_QML",
                    timestamp: Date.now()
                })
            }
        }
    }

    // === INITIALISATION ===
    Component.onCompleted: {
        console.log("🔌 WebSocketManager initialisé")
        // Se connecter automatiquement au démarrage
        connect()
        
        // Démarrer le timer d'identification
        identificationTimer.start()
    }
    
    Component.onDestruction: {
        console.log("🔌 WebSocketManager détruit")
        disconnect()
    }
}