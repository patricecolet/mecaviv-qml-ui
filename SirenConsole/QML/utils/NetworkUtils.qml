import QtQuick 2.15

QtObject {
    id: networkUtils
    
    // Vérifier si une adresse IP est valide
    function isValidIP(ip) {
        if (!ip || typeof ip !== 'string') return false
        var regex = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
        try {
            var ipString = String(ip)
            var regexObj = new RegExp(regex)
            var result = regexObj.test(ipString)
            return result
        } catch (e) {
            return false
        }
    }
    
    // Vérifier si un port est valide
    function isValidPort(port) {
        if (!port) return false
        var numPort = parseInt(port)
        return !isNaN(numPort) && numPort >= 1 && numPort <= 65535
    }
    
    // Construire une URL WebSocket
    function buildWebSocketURL(host, port, path) {
        if (!isValidIP(host) || !isValidPort(port)) {
            return ""
        }
        
        var url = "ws://" + host + ":" + port
        if (path && path !== "" && typeof path === 'string') {
            if (!String(path).startsWith("/")) {
                url += "/"
            }
            url += path
        }
        
        return url
    }
    
    // Tester la connectivité réseau
    function testConnectivity(host, port, callback) {
        // Test de connectivité
        
        // TODO: Implémenter un test de connectivité réel
        // Pour l'instant, on simule
        if (typeof setTimeout !== 'undefined') {
            setTimeout(function() {
                var isReachable = Math.random() > 0.3 // 70% de chance de succès
                if (callback) {
                    callback(isReachable)
                }
            }, 1000)
        }
    }
    
    // Obtenir l'adresse IP locale
    function getLocalIP() {
        // TODO: Implémenter la récupération de l'IP locale
        return "192.168.1.100"
    }
    
    // Scanner le réseau pour trouver des pupitres
    function scanNetwork(baseIP, startPort, endPort, callback) {
        // Scan réseau
        
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
        if (!port) return "Port invalide"
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
