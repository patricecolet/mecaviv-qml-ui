import QtQuick 2.15

// WebSocketManager pour SirenConsole
// Gère les connexions WebSocket vers les pupitres SirenePupitre
Item {
    id: webSocketManager
    
    // === PROPRIÉTÉS ===
    property var connections: ({})
    property var consoleController: null
    property bool pureDataConnected: false
    
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
            webSocketManager.checkPureDataStatus()
            webSocketManager.checkPupitresStatus()
        }
    }
    
    // === MÉTHODES PRIVÉES ===
    
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
    
    // Envoyer une commande à PureData (via HTTP POST au proxy)
    function sendMessage(message) {
        // Envoi commande via proxy
        
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
}