import QtQuick 2.15

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
    signal pureDataConnectedSignal()
    signal pureDataDisconnectedSignal()
    
    // Initialisation : Connexion automatique à PureData
    Component.onCompleted: {
        connectToPureData()
    }
    
    // Connexion à PureData via JavaScript WebSocket natif
    function connectToPureData() {
        console.log("🔌 Connexion à PureData:", pureDataUrl)
        
        try {
            // Créer WebSocket natif JavaScript
            pureDataSocket = Qt.createQmlObject('
                import QtQuick 2.15
                QtObject {
                    id: wsWrapper
                    property var socket: null
                    
                    Component.onCompleted: {
                        socket = new WebSocket("' + pureDataUrl + '")
                        
                        socket.onopen = function() {
                            console.log("✅ Connecté à PureData:", "' + pureDataUrl + '")
                            pureDataConnected = true
                            connectionOpened("' + pureDataUrl + '")
                            pureDataConnectedSignal()
                        }
                        
                        socket.onclose = function() {
                            console.log("❌ Déconnecté de PureData")
                            pureDataConnected = false
                            connectionClosed("' + pureDataUrl + '")
                            pureDataDisconnectedSignal()
                            
                            if (autoReconnect) {
                                console.log("🔄 Reconnexion dans", reconnectDelay, "ms")
                                reconnectTimer.start()
                            }
                        }
                        
                        socket.onerror = function(error) {
                            console.error("❌ Erreur WebSocket:", error)
                            errorOccurred("' + pureDataUrl + '", error.toString())
                        }
                        
                        socket.onmessage = function(event) {
                            console.log("📥 Message de PureData:", event.data)
                            messageReceived("' + pureDataUrl + '", event.data)
                            handlePureDataMessage(event.data)
                        }
                    }
                    
                    function send(message) {
                        if (socket && socket.readyState === WebSocket.OPEN) {
                            socket.send(message)
                            return true
                        }
                        return false
                    }
                    
                    function close() {
                        if (socket) {
                            socket.close()
                        }
                    }
                }
            ', webSocketManager)
            
        } catch (e) {
            console.error("❌ Erreur création WebSocket:", e)
            errorOccurred(pureDataUrl, e.toString())
            
            if (autoReconnect) {
                reconnectTimer.start()
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
        if (pureDataSocket && pureDataConnected) {
            console.log("📤 Envoi à PureData:", message)
            var success = pureDataSocket.send(message)
            return success
        } else {
            console.error("❌ PureData non connecté")
            return false
        }
    }
    
    // Fonction pour connecter aux pupitres (simulation pour compatibilité)
    function connectToPupitre(url, pupitreId) {
        console.log("🔌 Tentative de connexion pupitre:", url)
        console.log("⚠️ Mode simulation - les pupitres utilisent PureData central")
        
        // Simuler connexion réussie (pour compatibilité avec le code existant)
        connections[url] = {
            socket: null,
            pupitreId: pupitreId,
            url: url,
            connected: false
        }
        
        Qt.callLater(function() {
            if (connections[url]) {
                connections[url].connected = true
                connectionOpened(url)
                if (consoleController) {
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
        
        // Fermer PureData
        if (pureDataSocket) {
            pureDataSocket.close()
        }
        
        // Fermer pupitres
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
