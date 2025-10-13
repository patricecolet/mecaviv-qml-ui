import QtQuick 2.15
import "../utils/WebSocketHelper.js" as WS

Item {
    id: webSocketManager
    
    // Propriétés
    property var connections: ({})
    property var consoleController: null
    property bool autoReconnect: true
    property int reconnectDelay: 3000
    
    // WebSocket vers PureData (central)
    property string pureDataUrl: "ws://localhost:10001"
    property bool pureDataConnected: false
    
    // Signaux
    signal connectionOpened(string url)
    signal connectionClosed(string url)
    signal messageReceived(string url, string message)
    signal errorOccurred(string url, string error)
    signal pureDataConnectedSignal()
    signal pureDataDisconnectedSignal()
    
    // Initialisation
    Component.onCompleted: {
        connectToPureData()
    }
    
    // Connexion à PureData
    function connectToPureData() {
        console.log("🔌 Connexion à PureData:", pureDataUrl)
        
        WS.connect(
            pureDataUrl,
            function() {
                // onOpen
                pureDataConnected = true
                connectionOpened(pureDataUrl)
                pureDataConnectedSignal()
            },
            function() {
                // onClose
                pureDataConnected = false
                connectionClosed(pureDataUrl)
                pureDataDisconnectedSignal()
                
                if (autoReconnect) {
                    console.log("🔄 Reconnexion dans", reconnectDelay, "ms")
                    reconnectTimer.start()
                }
            },
            function(message) {
                // onMessage
                messageReceived(pureDataUrl, message)
                handlePureDataMessage(message)
            },
            function(error) {
                // onError
                errorOccurred(pureDataUrl, error)
            }
        )
    }
    
    // Timer de reconnexion
    Timer {
        id: reconnectTimer
        interval: reconnectDelay
        repeat: false
        onTriggered: connectToPureData()
    }
    
    // Gérer les messages de PureData
    function handlePureDataMessage(messageText) {
        try {
            var data = JSON.parse(messageText)
            console.log("📨 Type de message:", data.type)
            
            // TODO: Dispatcher selon le type de message
            // CONFIG_FULL, MIDI_NOTE, CONTROLLERS, etc.
        } catch (e) {
            console.error("❌ Erreur parsing message:", e)
        }
    }
    
    // Envoyer un message à PureData
    function sendMessage(message) {
        if (pureDataConnected) {
            console.log("📤 Envoi à PureData:", message)
            return WS.send(message)
        } else {
            console.error("❌ PureData non connecté")
            return false
        }
    }
    
    // Fonction pour connecter aux pupitres (simulation pour compatibilité)
    function connectToPupitre(url, pupitreId) {
        console.log("🔌 Connexion pupitre simulée:", url)
        console.log("⚠️ Les pupitres utilisent PureData central")
        
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
    
    // Fonction pour fermer une connexion
    function disconnectFromPupitre(url) {
        if (connections[url]) {
            console.log("🔌 Fermeture connexion:", url)
            connections[url].connected = false
            connectionClosed(url)
            
            if (consoleController && consoleController.onPupitreDisconnected) {
                var pupitreId = connections[url].pupitreId
                consoleController.onPupitreDisconnected(pupitreId, url)
            }
            
            delete connections[url]
        }
    }
    
    // Fonction pour fermer toutes les connexions
    function disconnectAll() {
        console.log("🔌 Fermeture de toutes les connexions")
        
        WS.close()
        
        for (var url in connections) {
            disconnectFromPupitre(url)
        }
    }
    
    // Fonction pour obtenir le statut d'une connexion
    function isConnected(url) {
        if (url === pureDataUrl) {
            return pureDataConnected
        }
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
