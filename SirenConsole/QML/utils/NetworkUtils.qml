import QtQuick 2.15

QtObject {
    id: networkUtils
    
    // Vérifier si une adresse IP est valide
    function isValidIP(ip) {
        var regex = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
        return regex.test(ip)
    }
    
    // Vérifier si un port est valide
    function isValidPort(port) {
        var numPort = parseInt(port)
        return numPort >= 1 && numPort <= 65535
    }
    
    // Construire une URL WebSocket
    function buildWebSocketURL(host, port, path) {
        if (!isValidIP(host) || !isValidPort(port)) {
            return ""
        }
        
        var url = "ws://" + host + ":" + port
        if (path && path !== "") {
            if (!path.startsWith("/")) {
                url += "/"
            }
            url += path
        }
        
        return url
    }
    
    // Tester la connectivité réseau
    function testConnectivity(host, port, callback) {
        console.log("🔍 Test de connectivité vers", host + ":" + port)
        
        // TODO: Implémenter un test de connectivité réel
        // Pour l'instant, on simule
        setTimeout(function() {
            var isReachable = Math.random() > 0.3 // 70% de chance de succès
            if (callback) {
                callback(isReachable)
            }
        }, 1000)
    }
    
    // Obtenir l'adresse IP locale
    function getLocalIP() {
        // TODO: Implémenter la récupération de l'IP locale
        return "192.168.1.100"
    }
    
    // Scanner le réseau pour trouver des pupitres
    function scanNetwork(baseIP, startPort, endPort, callback) {
        console.log("🔍 Scan réseau:", baseIP, "ports", startPort + "-" + endPort)
        
        var foundDevices = []
        var baseIPParts = baseIP.split('.')
        var baseIPPrefix = baseIPParts[0] + '.' + baseIPParts[1] + '.' + baseIPParts[2] + '.'
        
        // Scanner les 10 dernières adresses IP
        for (var i = 1; i <= 10; i++) {
            var testIP = baseIPPrefix + (100 + i)
            testConnectivity(testIP, startPort, function(isReachable) {
                if (isReachable) {
                    foundDevices.push({
                        host: testIP,
                        port: startPort,
                        status: "reachable"
                    })
                }
                
                if (callback) {
                    callback(foundDevices)
                }
            })
        }
    }
    
    // Formater une adresse IP
    function formatIP(ip) {
        if (!isValidIP(ip)) {
            return "Adresse invalide"
        }
        
        return ip
    }
    
    // Formater un port
    function formatPort(port) {
        var numPort = parseInt(port)
        if (!isValidPort(port)) {
            return "Port invalide"
        }
        
        return numPort.toString()
    }
    
    // Obtenir le statut de connexion sous forme de texte
    function getConnectionStatusText(status) {
        switch (status) {
            case "connected": return "Connecté"
            case "connecting": return "Connexion..."
            case "disconnected": return "Déconnecté"
            case "error": return "Erreur"
            default: return "Inconnu"
        }
    }
    
    // Obtenir la couleur selon le statut
    function getConnectionStatusColor(status) {
        switch (status) {
            case "connected": return "#F18F01"
            case "connecting": return "#2E86AB"
            case "disconnected": return "#666666"
            case "error": return "#C73E1D"
            default: return "#666666"
        }
    }
}
