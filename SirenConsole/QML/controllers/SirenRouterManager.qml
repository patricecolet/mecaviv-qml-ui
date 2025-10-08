import QtQuick 2.15
import QtQuick.Controls 2.15

QtObject {
    id: sirenRouterManager
    
    // Configuration
    property string routerApiUrl: "http://localhost:8002"
    property string routerWsUrl: "ws://localhost:8003"
    property bool connected: false
    property var sireneStatus: ({})
    
    // WebSocket pour notifications temps réel
    property var webSocket: null
    
    // Timer pour vérification périodique
    Timer {
        id: statusCheckTimer
        interval: 2000 // Vérification toutes les 2 secondes
        running: sirenRouterManager.connected
        repeat: true
        onTriggered: sirenRouterManager.checkSireneStatus()
    }
    
    // Initialisation
    Component.onCompleted: {
        connectToRouter()
    }
    
    // Connexion au Router
    function connectToRouter() {
        console.log("🔌 Connexion au SireneRouter...")
        
        // Vérification initiale de l'état
        checkSireneStatus()
        
        // Connexion WebSocket
        if (webSocket) {
            webSocket.close()
        }
        
        webSocket = new WebSocket(routerWsUrl)
        webSocket.onopen = function() {
            console.log("✅ WebSocket SireneRouter connecté")
            sirenRouterManager.connected = true
        }
        
        webSocket.onmessage = function(event) {
            const notification = JSON.parse(event.data)
            handleRouterNotification(notification)
        }
        
        webSocket.onclose = function() {
            console.log("❌ WebSocket SireneRouter déconnecté")
            sirenRouterManager.connected = false
        }
        
        webSocket.onerror = function(error) {
            console.log("⚠️ Erreur WebSocket SireneRouter:", error)
        }
    }
    
    // Vérification de l'état des sirènes
    function checkSireneStatus() {
        if (!connected) return
        
        const xhr = new XMLHttpRequest()
        xhr.open("GET", routerApiUrl + "/api/status/sirenes")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                const status = JSON.parse(xhr.responseText)
                updateSireneStatus(status)
            }
        }
        xhr.send()
    }
    
    // Mise à jour de l'état des sirènes
    function updateSireneStatus(status) {
        sireneStatus = status.sirenes || {}
        console.log("📊 État des sirènes mis à jour:", Object.keys(sireneStatus))
        
        // Émettre un signal pour notifier les autres composants
        sireneStatusChanged()
    }
    
    // Gestion des notifications WebSocket
    function handleRouterNotification(notification) {
        console.log("🔔 Notification Router:", notification.type)
        
        switch (notification.type) {
            case "sirene_status_changed":
                updateSireneStatus({ sirenes: { [notification.data.sireneId]: notification.data } })
                break
            case "sirene_controller_changed":
                console.log(`🎛️ Contrôleur changé: S${notification.data.sireneId} ${notification.data.previousController} → ${notification.data.newController}`)
                break
        }
    }
    
    // Vérifier si une sirène est disponible avant contrôle
    function isSireneAvailable(sireneId) {
        const sirene = sireneStatus[sireneId]
        if (!sirene) return true // Si pas d'info, on assume disponible
        
        // Vérifier si la sirène est en cours d'utilisation
        return sirene.status === "stopped" || sirene.controller === null
    }
    
    // Obtenir l'état d'une sirène
    function getSireneState(sireneId) {
        return sireneStatus[sireneId] || { status: "unknown", controller: null }
    }
    
    // Obtenir le contrôleur actuel d'une sirène
    function getSireneController(sireneId) {
        const sirene = sireneStatus[sireneId]
        return sirene ? sirene.controller : null
    }
    
    // Signal pour notifier les changements
    signal sireneStatusChanged()
    
    // Déconnexion
    function disconnect() {
        if (webSocket) {
            webSocket.close()
            webSocket = null
        }
        connected = false
        console.log("🔌 Déconnexion du SireneRouter")
    }
}

