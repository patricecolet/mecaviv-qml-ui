import QtQuick 2.15

QtObject {
    id: commandManager
    
    // Propriétés
    property var pupitreManager: null
    property var webSocketManager: null
    
    // Signaux
    signal commandExecuted(string command, var result)
    signal commandError(string command, string error)
    signal bulkOperationStarted(int totalCommands)
    signal bulkOperationProgress(int completed, int total)
    signal bulkOperationCompleted(int successCount, int errorCount)
    
    // Initialisation
    Component.onCompleted: {
        console.log("🎮 CommandManager initialisé")
    }
    
    // ==========================================
    // Commandes MIDI (PureData via proxy HTTP)
    // ==========================================
    
    function sendMidiCommand(command) {
        console.log("🎵 Envoi commande MIDI à PureData:", JSON.stringify(command))
        
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        if (response.success) {
                            commandExecuted("midi_" + command.type, response)
                            console.log("✅ Commande MIDI envoyée:", command.type)
                        } else {
                            commandError("midi_" + command.type, response.message || "Erreur inconnue")
                        }
                    } catch (e) {
                        commandError("midi_" + command.type, "Erreur parsing réponse: " + e)
                    }
                } else {
                    commandError("midi_" + command.type, "Erreur HTTP: " + xhr.status)
                }
            }
        }
        
        xhr.open("POST", "http://localhost:8001/api/puredata/command")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify(command))
        
        return true
    }
    
    function loadMidiFile(path) {
        return sendMidiCommand({
            "type": "MIDI_FILE_LOAD",
            "path": path
        })
    }
    
    function playMidi() {
        return sendMidiCommand({
            "type": "MIDI_TRANSPORT",
            "action": "play"
        })
    }
    
    function pauseMidi() {
        return sendMidiCommand({
            "type": "MIDI_TRANSPORT",
            "action": "pause"
        })
    }
    
    function stopMidi() {
        return sendMidiCommand({
            "type": "MIDI_TRANSPORT",
            "action": "stop"
        })
    }
    
    function seekMidi(position) {
        return sendMidiCommand({
            "type": "MIDI_SEEK",
            "position": position
        })
    }
    
    function setMidiTempo(tempo) {
        return sendMidiCommand({
            "type": "TEMPO_CHANGE",
            "tempo": tempo,
            "smooth": true
        })
    }
    
    // Exécuter une commande sur un pupitre
    function executeCommand(pupitreId, command, parameters) {
        if (!pupitreManager) {
            commandError(command, "PupitreManager non disponible")
            return false
        }
        
        var pupitre = pupitreManager.getPupitreById(pupitreId)
        if (!pupitre) {
            commandError(command, "Pupitre non trouvé: " + pupitreId)
            return false
        }
        
        if (!pupitre.connected) {
            commandError(command, "Pupitre non connecté: " + pupitreId)
            return false
        }
        
        console.log("🎮 Exécution commande:", command, "sur", pupitre.name, parameters)
        
        var message = {
            type: "command",
            command: command,
            parameters: parameters || {},
            timestamp: Date.now()
        }
        
        if (webSocketManager) {
            var success = webSocketManager.sendMessage(pupitreId, JSON.stringify(message))
            if (success) {
                commandExecuted(command, { pupitreId: pupitreId, parameters: parameters })
                return true
            } else {
                commandError(command, "Erreur envoi message WebSocket")
                return false
            }
        } else {
            commandError(command, "WebSocketManager non disponible")
            return false
        }
    }
    
    // Commandes de contrôle des sirènes
    function enableSirene(pupitreId, sireneNumber) {
        return executeCommand(pupitreId, "enable_sirene", { sirene: sireneNumber })
    }
    
    function disableSirene(pupitreId, sireneNumber) {
        return executeCommand(pupitreId, "disable_sirene", { sirene: sireneNumber })
    }
    
    function setSireneAmbitusRestreint(pupitreId, sireneNumber, enabled) {
        return executeCommand(pupitreId, "sirene_ambitus_restreint", { 
            sirene: sireneNumber, 
            enabled: enabled 
        })
    }
    
    function setSireneModeFrette(pupitreId, sireneNumber, enabled) {
        return executeCommand(pupitreId, "sirene_mode_frette", { 
            sirene: sireneNumber, 
            enabled: enabled 
        })
    }
    
    // Commandes de configuration pupitre
    function setAmbitus(pupitreId, min, max) {
        return executeCommand(pupitreId, "set_ambitus", { min: min, max: max })
    }
    
    function setFrettedMode(pupitreId, enabled) {
        return executeCommand(pupitreId, "set_fretted_mode", { enabled: enabled })
    }
    
    function setMotorSpeed(pupitreId, speed) {
        return executeCommand(pupitreId, "set_motor_speed", { speed: speed })
    }
    
    function setFrequency(pupitreId, frequency) {
        return executeCommand(pupitreId, "set_frequency", { frequency: frequency })
    }
    
    function setMidiNote(pupitreId, note) {
        return executeCommand(pupitreId, "set_midi_note", { note: note })
    }
    
    // Commandes de contrôle des sorties
    function enableVST(pupitreId, enabled) {
        return executeCommand(pupitreId, "enable_vst", { enabled: enabled })
    }
    
    function enableUDP(pupitreId, enabled) {
        return executeCommand(pupitreId, "enable_udp", { enabled: enabled })
    }
    
    function enableRtpMidi(pupitreId, enabled) {
        return executeCommand(pupitreId, "enable_rtp_midi", { enabled: enabled })
    }
    
    // Commandes de mapping des contrôleurs
    function setControllerMapping(pupitreId, controllerType, cc, curve) {
        return executeCommand(pupitreId, "set_controller_mapping", {
            controller: controllerType,
            cc: cc,
            curve: curve
        })
    }
    
    // Commandes de test et diagnostic
    function testConnection(pupitreId) {
        return executeCommand(pupitreId, "ping", {})
    }
    
    function getStatus(pupitreId) {
        return executeCommand(pupitreId, "get_status", {})
    }
    
    function getConfiguration(pupitreId) {
        return executeCommand(pupitreId, "get_configuration", {})
    }
    
    function resetPupitre(pupitreId) {
        return executeCommand(pupitreId, "reset", {})
    }
    
    function calibrateSensors(pupitreId) {
        return executeCommand(pupitreId, "calibrate_sensors", {})
    }
    
    // Commandes de contrôle en temps réel
    function setJoystickPosition(pupitreId, x, y) {
        return executeCommand(pupitreId, "joystick_position", { x: x, y: y })
    }
    
    function setFaderValue(pupitreId, value) {
        return executeCommand(pupitreId, "fader_value", { value: value })
    }
    
    function setSelectorValue(pupitreId, value) {
        return executeCommand(pupitreId, "selector_value", { value: value })
    }
    
    function setPedalValue(pupitreId, value) {
        return executeCommand(pupitreId, "pedal_value", { value: value })
    }
    
    // Commandes de sauvegarde et restauration
    function savePupitreConfig(pupitreId) {
        return executeCommand(pupitreId, "save_config", {})
    }
    
    function loadPupitreConfig(pupitreId) {
        return executeCommand(pupitreId, "load_config", {})
    }
    
    function factoryReset(pupitreId) {
        return executeCommand(pupitreId, "factory_reset", {})
    }
    
    // Opérations en lot
    function executeBulkCommands(commands) {
        if (!Array.isArray(commands) || commands.length === 0) {
            commandError("bulk_commands", "Liste de commandes vide")
            return false
        }
        
        console.log("🎮 Exécution en lot de", commands.length, "commandes")
        bulkOperationStarted(commands.length)
        
        var successCount = 0
        var errorCount = 0
        var completed = 0
        
        function executeNext(index) {
            if (index >= commands.length) {
                bulkOperationCompleted(successCount, errorCount)
                console.log("🎮 Opération en lot terminée:", successCount, "succès,", errorCount, "erreurs")
                return
            }
            
            var command = commands[index]
            var success = executeCommand(
                command.pupitreId,
                command.command,
                command.parameters
            )
            
            if (success) {
                successCount++
            } else {
                errorCount++
            }
            
            completed++
            bulkOperationProgress(completed, commands.length)
            
            // Exécuter la commande suivante après un court délai
            setTimeout(function() {
                executeNext(index + 1)
            }, 50)
        }
        
        executeNext(0)
        return true
    }
    
    // Commandes de contrôle global
    function enableAllSirenes(pupitreId) {
        var commands = []
        for (var i = 1; i <= 7; i++) {
            commands.push({
                pupitreId: pupitreId,
                command: "enable_sirene",
                parameters: { sirene: i }
            })
        }
        return executeBulkCommands(commands)
    }
    
    function disableAllSirenes(pupitreId) {
        var commands = []
        for (var i = 1; i <= 7; i++) {
            commands.push({
                pupitreId: pupitreId,
                command: "disable_sirene",
                parameters: { sirene: i }
            })
        }
        return executeBulkCommands(commands)
    }
    
    function setAllSirenesAmbitusRestreint(pupitreId, enabled) {
        var commands = []
        for (var i = 1; i <= 7; i++) {
            commands.push({
                pupitreId: pupitreId,
                command: "sirene_ambitus_restreint",
                parameters: { sirene: i, enabled: enabled }
            })
        }
        return executeBulkCommands(commands)
    }
    
    function setAllSirenesModeFrette(pupitreId, enabled) {
        var commands = []
        for (var i = 1; i <= 7; i++) {
            commands.push({
                pupitreId: pupitreId,
                command: "sirene_mode_frette",
                parameters: { sirene: i, enabled: enabled }
            })
        }
        return executeBulkCommands(commands)
    }
    
    // Commandes de synchronisation
    function syncAllPupitres() {
        if (!pupitreManager) {
            commandError("sync_all", "PupitreManager non disponible")
            return false
        }
        
        var commands = []
        var connectedPupitres = pupitreManager.getConnectedPupitres()
        
        for (var i = 0; i < connectedPupitres.length; i++) {
            var pupitre = connectedPupitres[i]
            commands.push({
                pupitreId: pupitre.id,
                command: "get_status",
                parameters: {}
            })
        }
        
        console.log("🔄 Synchronisation de", commands.length, "pupitres")
        return executeBulkCommands(commands)
    }
    
    // Commandes de diagnostic système
    function diagnoseAllPupitres() {
        if (!pupitreManager) {
            commandError("diagnose_all", "PupitreManager non disponible")
            return false
        }
        
        var commands = []
        var enabledPupitres = pupitreManager.getEnabledPupitres()
        
        for (var i = 0; i < enabledPupitres.length; i++) {
            var pupitre = enabledPupitres[i]
            commands.push({
                pupitreId: pupitre.id,
                command: "ping",
                parameters: {}
            })
        }
        
        console.log("🔍 Diagnostic de", commands.length, "pupitres")
        return executeBulkCommands(commands)
    }
    
    // Commandes de mise à jour
    function updatePupitreFirmware(pupitreId, firmwareData) {
        return executeCommand(pupitreId, "update_firmware", { firmware: firmwareData })
    }
    
    function backupPupitreData(pupitreId) {
        return executeCommand(pupitreId, "backup_data", {})
    }
    
    function restorePupitreData(pupitreId, backupData) {
        return executeCommand(pupitreId, "restore_data", { backup: backupData })
    }
    
    // Commandes de monitoring
    function startMonitoring(pupitreId) {
        return executeCommand(pupitreId, "start_monitoring", {})
    }
    
    function stopMonitoring(pupitreId) {
        return executeCommand(pupitreId, "stop_monitoring", {})
    }
    
    function getMonitoringData(pupitreId) {
        return executeCommand(pupitreId, "get_monitoring_data", {})
    }
    
    // Utilitaires
    function createCommand(pupitreId, command, parameters) {
        return {
            pupitreId: pupitreId,
            command: command,
            parameters: parameters || {},
            timestamp: Date.now()
        }
    }
    
    function validateCommand(command) {
        if (!command.pupitreId || !command.command) {
            return false
        }
        
        var validCommands = [
            "enable_sirene", "disable_sirene", "sirene_ambitus_restreint", "sirene_mode_frette",
            "set_ambitus", "set_fretted_mode", "set_motor_speed", "set_frequency", "set_midi_note",
            "enable_vst", "enable_udp", "enable_rtp_midi", "set_controller_mapping",
            "ping", "get_status", "get_configuration", "reset", "calibrate_sensors",
            "joystick_position", "fader_value", "selector_value", "pedal_value",
            "save_config", "load_config", "factory_reset",
            "update_firmware", "backup_data", "restore_data",
            "start_monitoring", "stop_monitoring", "get_monitoring_data"
        ]
        
        return validCommands.indexOf(command.command) !== -1
    }
    
    function getCommandHistory() {
        // TODO: Implémenter l'historique des commandes
        return []
    }
    
    function clearCommandHistory() {
        // TODO: Implémenter la suppression de l'historique
        console.log("🗑️ Historique des commandes effacé")
    }
}
