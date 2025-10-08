import QtQuick 2.15

QtObject {
    id: webSocketManager
    
    // Propriétés
    property var connections: ({})
    property var consoleController: null
    property bool autoReconnect: true
    property int reconnectDelay: 3000
    
    // Signaux
    signal connectionOpened(string url)
    signal connectionClosed(string url)
    signal messageReceived(string url, string message)
    signal errorOccurred(string url, string error)
    
    // Fonction pour créer une connexion WebSocket (simulation)
    function connectToPupitre(url, pupitreId) {
        console.log("🔌 Tentative de connexion à:", url)
        
        // Mode simulation puisque les pupitres ne sont pas sur le réseau
        console.log("⚠️ Mode simulation - les pupitres ne sont pas sur le réseau")
        
        // Stocker la connexion simulée
        connections[url] = {
            socket: null,
            pupitreId: pupitreId,
            url: url,
            connected: false
        }
        
        // Simuler une connexion réussie après un délai
        Qt.callLater(function() {
            if (connections[url]) {
                console.log("🎭 Simulation: Connexion simulée ouverte:", url)
                connections[url].connected = true
                connectionOpened(url)
                
                if (consoleController) {
                    consoleController.onPupitreConnected(pupitreId, url)
                }
            }
        }, 1000)
    }
    
    // Fonction pour envoyer un message (simulation)
    function sendMessage(url, message) {
        if (connections[url] && connections[url].connected) {
            console.log("🎭 Simulation: Message simulé envoyé à", url, ":", message)
            return true
        } else {
            console.log("❌ Connexion non disponible:", url)
            return false
        }
    }
    
    // Fonction pour fermer une connexion
    function disconnectFromPupitre(url) {
        if (connections[url]) {
            console.log("🔌 Fermeture connexion:", url)
            connections[url].connected = false
            connectionClosed(url)
            
            if (consoleController) {
                var pupitreId = connections[url].pupitreId
                consoleController.onPupitreDisconnected(pupitreId, url)
            }
            
            delete connections[url]
        }
    }
    
    // Fonction pour fermer toutes les connexions
    function disconnectAll() {
        console.log("🔌 Fermeture de toutes les connexions")
        for (var url in connections) {
            disconnectFromPupitre(url)
        }
    }
    
    // Fonction pour obtenir le statut d'une connexion
    function isConnected(url) {
        return connections[url] && connections[url].connected
    }
    
    // Fonction pour obtenir la liste des connexions actives
    function getActiveConnections() {
        var active = []
        for (var url in connections) {
            if (connections[url].connected) {
                active.push({
                    url: url,
                    pupitreId: connections[url].pupitreId
                })
            }
        }
        return active
    }
}