import QtQuick
import QtCore

Item {
    id: systemInfoReader
    
    property var logger
    property var currentSystemInfo: ({})
    property bool isReading: false
    // Vide = URL relative, résolue sur l'origine de la page : le serveur qui sert
    // l'application est aussi celui qui expose /api/system-info. Ne jamais remettre
    // une IP en dur ici, elle serait compilée dans le wasm.
    property string serverUrl: ""
    
    signal systemInfoReceived(var data)
    
    // Timer pour lire les infos périodiquement
    Timer {
        interval: 5000 // 5 secondes
        running: true
        repeat: true
        onTriggered: readSystemInfo()
    }
    
    function readSystemInfo() {
        if (isReading) return
        isReading = true
        
        if (logger) {
            logger.debug("SYSTEM", "🌐 Requête système vers:", serverUrl + "/api/system-info")
        }
        
        let xhr = new XMLHttpRequest()
        xhr.open('GET', serverUrl + '/api/system-info')
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (logger) {
                    logger.debug("SYSTEM", "📡 Réponse HTTP:", xhr.status)
                }
                
                if (xhr.status === 200) {
                    try {
                        let data = JSON.parse(xhr.responseText)
                        currentSystemInfo = data
                        systemInfoReceived(data)
                        
                        if (logger) {
                            logger.info("SYSTEM", "✅ Infos système reçues:", JSON.stringify(data))
                        }
                    } catch (e) {
                        if (logger) {
                            logger.error("SYSTEM", "❌ Erreur parsing JSON:", e)
                        }
                    }
                } else {
                    if (logger) {
                        logger.error("SYSTEM", "❌ Erreur HTTP:", xhr.status, xhr.responseText)
                    }
                }
                isReading = false
            }
        }
        xhr.send()
    }
    
    function requestSystemInfo() {
        // Compatibilité avec l'ancien système
        readSystemInfo()
    }
}