import QtQuick 2.15

// WebSocketManager simplifié pour SirenConsole
// La connexion à PureData se fait via proxy HTTP dans server.js
Item {
    id: webSocketManager
    
    // Propriétés
    property var connections: ({})
    property var consoleController: null
    property bool pureDataConnected: false
    
    // Signaux (pour compatibilité)
    signal connectionOpened(string url)
    signal connectionClosed(string url)
    signal messageReceived(string url, string message)
    signal errorOccurred(string url, string error)
    
    // Timer pour vérifier le statut PureData
    Timer {
        interval: 2000 // Vérifier toutes les 2 secondes
        running: true
        repeat: true
        onTriggered: checkPureDataStatus()
    }
    
    // Vérifier le statut de la connexion PureData (via HTTP)
    function checkPureDataStatus() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var status = JSON.parse(xhr.responseText)
                    pureDataConnected = status.connected
                } catch (e) {
                    // Ignorer erreur silencieusement
                }
            }
        }
        xhr.open("GET", "http://localhost:8001/api/puredata/status")
        xhr.send()
    }
    
    // Envoyer une commande à PureData (via HTTP POST au proxy)
    function sendMessage(message) {
        console.log("📤 Envoi commande via proxy:", message)
        
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://localhost:8001/api/puredata/command")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(message)
        
        return true // Toujours retourner true (async)
    }
    
    // Fonctions pour compatibilité avec le code existant
    function connectToPupitre(url, pupitreId) {
        console.log("🔌 Connexion pupitre (simulé):", url)
        
        connections[url] = {
            pupitreId: pupitreId,
            url: url,
            connected: false
        }
        
        Qt.callLater(function() {
            if (connections[url]) {
                connections[url].connected = true
                connectionOpened(url)
                if (consoleController && consoleController.onPupitreConnected) {
                    consoleController.onPupitreConnected(pupitreId, url)
                }
            }
        }, 1000)
    }
    
    function disconnectFromPupitre(url) {
        if (connections[url]) {
            connections[url].connected = false
            connectionClosed(url)
            if (consoleController && consoleController.onPupitreDisconnected) {
                consoleController.onPupitreDisconnected(connections[url].pupitreId, url)
            }
            delete connections[url]
        }
    }
    
    function disconnectAll() {
        for (var url in connections) {
            disconnectFromPupitre(url)
        }
    }
    
    function isConnected(url) {
        return connections[url] && connections[url].connected
    }
    
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
