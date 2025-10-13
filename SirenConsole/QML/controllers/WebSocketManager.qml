import QtQuick 2.15
import QtWebSockets 1.15

QtObject {
    id: webSocketManager
    
    // Propriétés
    property var connections: ({})
    property var consoleController: null
    property bool autoReconnect: true
    property int reconnectDelay: 3000
    
    // WebSocket vers PureData (central)
    property string pureDataUrl: "ws://localhost:10001"
    property var pureDataSocket: null
    property bool pureDataConnected: false
    
    // Signaux
    signal connectionOpened(string url)
    signal connectionClosed(string url)
    signal messageReceived(string url, string message)
    signal errorOccurred(string url, string error)
    signal pureDataConnected()
    signal pureDataDisconnected()
    
    // Initialisation : Connexion automatique à PureData
    Component.onCompleted: {
        connectToPureData()
    }
    
    // Connexion à PureData (WebSocket central)
    function connectToPureData() {
        console.log("🔌 Connexion à PureData:", pureDataUrl)
        
        if (pureDataSocket) {
            pureDataSocket.active = false
            pureDataSocket.destroy()
        }
        
        pureDataSocket = pureDataSocketComponent.createObject(webSocketManager)
    }
    
    // Composant WebSocket pour PureData
    Component {
        id: pureDataSocketComponent
        
        WebSocket {
            id: socket
            url: pureDataUrl
            active: true
            
            onStatusChanged: {
                console.log("📡 PureData WebSocket status:", status)
                
                if (status === WebSocket.Open) {
                    pureDataConnected = true
                    console.log("✅ Connecté à PureData:", url)
                    connectionOpened(url)
                    webSocketManager.pureDataConnected()
                } else if (status === WebSocket.Closed || status === WebSocket.Error) {
                    pureDataConnected = false
                    console.log("❌ Déconnecté de PureData")
                    connectionClosed(url)
                    webSocketManager.pureDataDisconnected()
                    
                    // Reconnexion automatique
                    if (autoReconnect) {
                        console.log("🔄 Reconnexion dans", reconnectDelay, "ms")
                        reconnectTimer.start()
                    }
                }
            }
            
            onTextMessageReceived: function(message) {
                console.log("📥 Message de PureData:", message)
                messageReceived(url, message)
                
                // Parser et dispatcher
                try {
                    var data = JSON.parse(message)
                    handlePureDataMessage(data)
                } catch (e) {
                    console.error("❌ Erreur parsing message:", e)
                }
            }
            
            onErrorStringChanged: {
                console.error("❌ Erreur WebSocket:", errorString)
                errorOccurred(url, errorString)
            }
        }
    }
    
    // Timer de reconnexion
    Timer {
        id: reconnectTimer
        interval: reconnectDelay
        repeat: false
        onTriggered: connectToPureData()
    }
    
    // Gérer les messages de PureData
    function handlePureDataMessage(data) {
        console.log("📨 Type de message:", data.type)
        
        // TODO: Dispatcher selon le type de message
        // CONFIG_FULL, MIDI_NOTE, CONTROLLERS, etc.
    }
    
    // Envoyer un message à PureData
    function sendMessage(message) {
        if (pureDataSocket && pureDataConnected) {
            console.log("📤 Envoi à PureData:", message)
            pureDataSocket.sendTextMessage(message)
            return true
        } else {
            console.error("❌ PureData non connecté")
            return false
        }
    }
    
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