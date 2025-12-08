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
    
    // Obtenir l'URL de base de l'API (détection automatique)
    function getApiBaseUrl() {
        // En WebAssembly, utiliser plusieurs méthodes pour détecter l'URL
        try {
            // Méthode 1: Variable JavaScript globale (prioritaire, définie dans le HTML)
            var serverUrl = null
            try {
                var evalResult = eval("(typeof window !== 'undefined' && window.SERVER_URL) ? window.SERVER_URL : null")
                if (evalResult) {
                    serverUrl = evalResult
                }
            } catch (e) {
                // Ignorer
            }
            
            try {
                if (typeof window !== 'undefined' && window.SERVER_URL) {
                    serverUrl = window.SERVER_URL
                } else if (typeof SERVER_URL !== 'undefined' && SERVER_URL) {
                    serverUrl = SERVER_URL
                }
            } catch (e) {
                // Ignorer
            }
            
            if (serverUrl) {
                return serverUrl
            }
            
            // Méthode 2: Utiliser location.origin directement si disponible
            var origin = null
            if (typeof self !== 'undefined' && self.location && self.location.origin) {
                origin = self.location.origin
            } else if (typeof globalThis !== 'undefined' && globalThis.location && globalThis.location.origin) {
                origin = globalThis.location.origin
            } else if (typeof window !== 'undefined' && window.location && window.location.origin) {
                origin = window.location.origin
            } else if (typeof document !== 'undefined' && document.location && document.location.origin) {
                origin = document.location.origin
            } else if (typeof location !== 'undefined' && location.origin) {
                origin = location.origin
            }
            
            if (origin) {
                return origin
            }
            
            // Méthode 3: Fallback - construire depuis location si origin n'est pas disponible
            var locationObj = null
            if (typeof self !== 'undefined' && self.location) {
                locationObj = self.location
            } else if (typeof globalThis !== 'undefined' && globalThis.location) {
                locationObj = globalThis.location
            } else if (typeof window !== 'undefined' && window.location) {
                locationObj = window.location
            } else if (typeof document !== 'undefined' && document.location) {
                locationObj = document.location
            } else if (typeof location !== 'undefined' && location.href) {
                locationObj = location
            }
            
            if (locationObj) {
                var protocol = locationObj.protocol
                var hostname = locationObj.hostname
                var port = locationObj.port || (protocol === 'https:' ? '443' : '80')
                
                if (hostname === '0.0.0.0' || hostname === '') {
                    hostname = 'localhost'
                }
                
                var apiPort = (port === '443' || port === '80' || !port || port === '') ? '8001' : port
                return protocol + "//" + hostname + ":" + apiPort
            }
        } catch (e) {
            // Ignorer les erreurs
        }
        
        // Fallback : utiliser l'URL courante si disponible via Qt
        try {
            var currentUrl = Qt.application.arguments.length > 0 ? 
                             Qt.application.arguments[0] : ""
            
            if (currentUrl && currentUrl.indexOf("://") > 0) {
                var url = currentUrl.split("://")[1].split("/")[0]
                var protocol = currentUrl.split("://")[0]
                var hostname = url.split(":")[0]
                var port = url.split(":")[1] || (protocol === 'https' ? '443' : '80')
                var apiPort = (port === '443' || port === '80') ? '8001' : port
                return protocol + "://" + hostname + ":" + apiPort
            }
        } catch (e) {
            // Ignorer les erreurs
        }
        
        // Dernier fallback
        return "https://127.0.0.1:8001"
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
