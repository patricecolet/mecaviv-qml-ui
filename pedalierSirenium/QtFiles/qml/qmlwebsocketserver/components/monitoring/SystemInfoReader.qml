import QtQuick
import QtCore

Item {
    id: systemInfoReader
    
    property var logger
    property var currentSystemInfo: ({})
    property bool isReading: false
    property string serverUrl: "http://192.168.1.21:8010"  // IP du Raspberry Pi
    
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