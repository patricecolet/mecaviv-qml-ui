import QtQuick 2.15

QtObject {
    id: pupitreManager
    
    // Propriétés
    property var configManager: null
    property var webSocketManager: null
    property var pupitres: []
    property int currentPupitreIndex: 0
    
    // Signaux
    signal pupitreConnected(string pupitreId)
    signal pupitreDisconnected(string pupitreId)
    signal pupitreStatusChanged(string pupitreId, string status)
    signal pupitreDataChanged(string pupitreId, var data)
    
    // Initialisation
    Component.onCompleted: {
        // PupitreManager initialisé
    }
    
    // Initialiser les pupitres à partir de la configuration
    function initializePupitres() {
        // Début initialisation pupitres
        
        if (!configManager) {
            // ConfigManager non disponible
            return false
        }
        
        if (!configManager.config) {
            // Configuration non chargée
            return false
        }
        
        // Initialisation des pupitres
        
        pupitres = []
        var configPupitres = configManager.getAllPupitres()
        // Pupitres trouvés
        
        for (var i = 0; i < configPupitres.length; i++) {
            var configPupitre = configPupitres[i]
            
            // Créer un objet pupitre avec les données de base
            var pupitre = {
                id: configPupitre.id,
                name: configPupitre.name,
                host: configPupitre.host,
                port: configPupitre.port,
                websocketPort: configPupitre.websocketPort,
                enabled: configPupitre.enabled,
                description: configPupitre.description || "",
                
                // Configuration audio
                ambitus: configPupitre.ambitus || { min: 48, max: 72 },
                frettedMode: configPupitre.frettedMode || false,
                motorSpeed: configPupitre.motorSpeed || 0,
                frequency: configPupitre.frequency || 440,
                midiNote: configPupitre.midiNote || 60,
                restrictedMax: configPupitre.restrictedMax || 72,
                
                // Statut de connexion
                status: "disconnected",
                connected: false,
                lastSeen: null,
                
                // Configuration des sorties
                assignedSirenes: configPupitre.assignedSirenes || [],
                vstEnabled: configPupitre.vstEnabled || false,
                udpEnabled: configPupitre.udpEnabled || false,
                rtpMidiEnabled: configPupitre.rtpMidiEnabled || false,
                
                // Mapping des contrôleurs
                controllerMapping: configPupitre.controllerMapping || {},
                
                // Données de contrôle en temps réel
                joystickX: 0,
                joystickY: 0,
                fader: 0,
                selector: 0,
                pedalId: 0,
                
                // État des sirènes
                sirene1: { enabled: false, ambitusRestreint: false, modeFrette: false },
                sirene2: { enabled: false, ambitusRestreint: false, modeFrette: false },
                sirene3: { enabled: false, ambitusRestreint: false, modeFrette: false },
                sirene4: { enabled: false, ambitusRestreint: false, modeFrette: false },
                sirene5: { enabled: false, ambitusRestreint: false, modeFrette: false },
                sirene6: { enabled: false, ambitusRestreint: false, modeFrette: false },
                sirene7: { enabled: false, ambitusRestreint: false, modeFrette: false }
            }
            
            pupitres.push(pupitre)
            // Pupitre initialisé
        }
        
        // Initialisation terminée
        return true
    }
    
    // Obtenir un pupitre par ID
    function getPupitreById(pupitreId) {
        for (var i = 0; i < pupitres.length; i++) {
            if (pupitres[i].id === pupitreId) {
                return pupitres[i]
            }
        }
        return null
    }
    
    // Obtenir un pupitre par index
    function getPupitreByIndex(index) {
        if (index >= 0 && index < pupitres.length) {
            return pupitres[index]
        }
        return null
    }
    
    // Obtenir le pupitre actuel
    function getCurrentPupitre() {
        return getPupitreByIndex(currentPupitreIndex)
    }
    
    // Définir le pupitre actuel
    function setCurrentPupitre(index) {
        if (index >= 0 && index < pupitres.length) {
            currentPupitreIndex = index
            // Pupitre actuel changé
            return true
        }
        return false
    }
    
    // Connecter un pupitre
    function connectPupitre(pupitreId) {
        var pupitre = getPupitreById(pupitreId)
        if (!pupitre) {
            // Pupitre non trouvé
            return false
        }
        
        if (!pupitre.enabled) {
            // Pupitre désactivé
            return false
        }
        
        // Connexion pupitre
        
        // Mettre à jour le statut
        //pupitre.status = "connecting"
        //pupitreStatusChanged(pupitreId, "connecting")
        
        // Utiliser le WebSocketManager pour la connexion
        if (webSocketManager) {
            webSocketManager.connectToPupitre(pupitre.host, pupitre.websocketPort, pupitreId)
        }
        
        return true
    }
    
    // Déconnecter un pupitre
    function disconnectPupitre(pupitreId) {
        var pupitre = getPupitreById(pupitreId)
        if (!pupitre) {
            // Pupitre non trouvé
            return false
        }
        
        // Déconnexion pupitre
        
        // Mettre à jour le statut
        pupitre.status = "disconnected"
        pupitre.connected = false
        pupitreStatusChanged(pupitreId, "disconnected")
        
        // Utiliser le WebSocketManager pour la déconnexion
        if (webSocketManager) {
            webSocketManager.disconnectFromPupitre(pupitreId)
        }
        
        return true
    }
    
    // Connecter tous les pupitres activés
    function connectAllPupitres() {
        // Connexion de tous les pupitres
        
        var connectedCount = 0
        for (var i = 0; i < pupitres.length; i++) {
            if (pupitres[i].enabled && connectPupitre(pupitres[i].id)) {
                connectedCount++
            }
        }
        
        // Connexion terminée
        return connectedCount
    }
    
    // Déconnecter tous les pupitres
    function disconnectAllPupitres() {
        // Déconnexion de tous les pupitres
        
        var disconnectedCount = 0
        for (var i = 0; i < pupitres.length; i++) {
            if (disconnectPupitre(pupitres[i].id)) {
                disconnectedCount++
            }
        }
        
        // Déconnexion terminée
        return disconnectedCount
    }
    
    // Mettre à jour le statut d'un pupitre
    function updatePupitreStatus(pupitreId, status) {
        var pupitre = getPupitreById(pupitreId)
        if (!pupitre) {
            return false
        }
        
        var oldStatus = pupitre.status
        pupitre.status = status
        pupitre.connected = (status === "connected")
        
        if (status === "connected") {
            pupitre.lastSeen = new Date()
        }
        
        // Statut pupitre mis à jour
        pupitreStatusChanged(pupitreId, status)
        
        return true
    }
    
    // Mettre à jour les données d'un pupitre
    function updatePupitreData(pupitreId, data) {
        var pupitre = getPupitreById(pupitreId)
        if (!pupitre) {
            return false
        }
        
        // Mettre à jour les propriétés reçues
        for (var key in data) {
            if (pupitre.hasOwnProperty(key)) {
                pupitre[key] = data[key]
            }
        }
        
        pupitre.lastSeen = new Date()
        pupitreDataChanged(pupitreId, data)
        
        return true
    }
    
    // Envoyer une commande à un pupitre
    function sendCommand(pupitreId, command, value) {
        var pupitre = getPupitreById(pupitreId)
        if (!pupitre || !pupitre.connected) {
            // Pupitre non connecté
            return false
        }
        
        var message = {
            type: "command",
            command: command,
            value: value,
            timestamp: Date.now()
        }
        
        // Commande envoyée
        
        if (webSocketManager) {
            webSocketManager.sendMessage(pupitreId, JSON.stringify(message))
            return true
        }
        
        return false
    }
    
    // Contrôler une sirène
    function controlSirene(pupitreId, sireneNumber, enabled, ambitusRestreint, modeFrette) {
        var pupitre = getPupitreById(pupitreId)
        if (!pupitre) {
            return false
        }
        
        var sireneKey = "sirene" + sireneNumber
        if (!pupitre[sireneKey]) {
            pupitre[sireneKey] = { enabled: false, ambitusRestreint: false, modeFrette: false }
        }
        
        var sirene = pupitre[sireneKey]
        sirene.enabled = enabled !== undefined ? enabled : sirene.enabled
        sirene.ambitusRestreint = ambitusRestreint !== undefined ? ambitusRestreint : sirene.ambitusRestreint
        sirene.modeFrette = modeFrette !== undefined ? modeFrette : sirene.modeFrette
        
        // Contrôle sirène
        
        // Envoyer la commande au pupitre
        sendCommand(pupitreId, "sirene_" + sireneNumber, {
            enabled: sirene.enabled,
            ambitusRestreint: sirene.ambitusRestreint,
            modeFrette: sirene.modeFrette
        })
        
        return true
    }
    
    // Définir l'ambitus d'un pupitre
    function setPupitreAmbitus(pupitreId, min, max) {
        var pupitre = getPupitreById(pupitreId)
        if (!pupitre) {
            return false
        }
        
        pupitre.ambitus = { min: min, max: max }
        // Ambitus défini
        
        // Envoyer la commande au pupitre
        sendCommand(pupitreId, "ambitus", pupitre.ambitus)
        
        return true
    }
    
    // Définir le mode fretté d'un pupitre
    function setPupitreFrettedMode(pupitreId, frettedMode) {
        var pupitre = getPupitreById(pupitreId)
        if (!pupitre) {
            return false
        }
        
        pupitre.frettedMode = frettedMode
        // Mode fretté
        
        // Envoyer la commande au pupitre
        sendCommand(pupitreId, "frettedMode", frettedMode)
        
        return true
    }
    
    // Définir la vitesse moteur d'un pupitre
    function setPupitreMotorSpeed(pupitreId, speed) {
        var pupitre = getPupitreById(pupitreId)
        if (!pupitre) {
            return false
        }
        
        pupitre.motorSpeed = speed
        // Vitesse moteur
        
        // Envoyer la commande au pupitre
        sendCommand(pupitreId, "motorSpeed", speed)
        
        return true
    }
    
    // Définir la fréquence d'un pupitre
    function setPupitreFrequency(pupitreId, frequency) {
        var pupitre = getPupitreById(pupitreId)
        if (!pupitre) {
            return false
        }
        
        pupitre.frequency = frequency
        // Fréquence
        
        // Envoyer la commande au pupitre
        sendCommand(pupitreId, "frequency", frequency)
        
        return true
    }
    
    // Obtenir les statistiques des pupitres
    function getPupitresStats() {
        var stats = {
            total: pupitres.length,
            enabled: 0,
            connected: 0,
            disconnected: 0,
            connecting: 0
        }
        
        for (var i = 0; i < pupitres.length; i++) {
            var pupitre = pupitres[i]
            if (pupitre.enabled) stats.enabled++
            
            switch (pupitre.status) {
                case "connected":
                    stats.connected++
                    break
                case "connecting":
                    stats.connecting++
                    break
                case "disconnected":
                    stats.disconnected++
                    break
            }
        }
        
        return stats
    }
    
    // Obtenir les pupitres connectés
    function getConnectedPupitres() {
        var connected = []
        for (var i = 0; i < pupitres.length; i++) {
            if (pupitres[i].connected) {
                connected.push(pupitres[i])
            }
        }
        return connected
    }
    
    // Obtenir les pupitres activés
    function getEnabledPupitres() {
        var enabled = []
        for (var i = 0; i < pupitres.length; i++) {
            if (pupitres[i].enabled) {
                enabled.push(pupitres[i])
            }
        }
        return enabled
    }
    
    // Activer/désactiver un pupitre
    function setPupitreEnabled(pupitreId, enabled) {
        var pupitre = getPupitreById(pupitreId)
        if (!pupitre) {
            return false
        }
        
        pupitre.enabled = enabled
        // Pupitre activé/désactivé
        
        // Si désactivé, déconnecter
        if (!enabled && pupitre.connected) {
            disconnectPupitre(pupitreId)
        }
        
        return true
    }
    
    // Synchroniser avec la configuration
    function syncWithConfig() {
        if (!configManager) {
            return false
        }
        
        // Synchronisation avec la configuration
        
        var configPupitres = configManager.getAllPupitres()
        for (var i = 0; i < pupitres.length && i < configPupitres.length; i++) {
            var pupitre = pupitres[i]
            var configPupitre = configPupitres[i]
            
            // Mettre à jour les propriétés de configuration
            pupitre.host = configPupitre.host
            pupitre.port = configPupitre.port || 8000
            pupitre.websocketPort = configPupitre.websocketPort || 10002
            pupitre.enabled = configPupitre.enabled || false
            pupitre.description = configPupitre.description || ""
            pupitre.assignedSirenes = configPupitre.assignedSirenes || []
            pupitre.vstEnabled = configPupitre.vstEnabled || false
            pupitre.udpEnabled = configPupitre.udpEnabled || false
            pupitre.rtpMidiEnabled = configPupitre.rtpMidiEnabled || false
            pupitre.controllerMapping = configPupitre.controllerMapping || {}
        }
        
        // Synchronisation terminée
        return true
    }
}
