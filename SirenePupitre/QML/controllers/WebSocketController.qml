import QtQuick
import QtWebSockets

Item {
    id: controller
    
    // Flag de debug
    property bool debugMode: false
    
    // WebSocket
    property string serverUrl: "ws://127.0.0.1:10002"
    property alias active: socket.active
    property alias status: socket.status
    property bool connected: socket.status === WebSocket.Open
    // Priorité console
    property bool consoleConnected: false
    
    // Statistiques
    property int messageCount: 0
    property string lastMessageTime: ""
    
    // 📊 STATISTIQUES DE PERFORMANCE (Solution 4)
    property int messagesPerSecond: 0
    property int messageCountThisSecond: 0
    property int droppedMessagesCount: 0
    property int controllersMessagesPerSecond: 0
    property int controllersMessageCountThisSecond: 0
    
    // 🎛️ THROTTLING DES CONTRÔLEURS (Solution 1)
    property int controllersThrottleMs: 50  // Limiter à 20 messages/sec max
    property var pendingControllersData: null
    
    // 🔍 FILTRAGE DES CHANGEMENTS (Solution 2)
    property var lastControllerValues: ({
        "wheelPos": -1,
        "joyX": 0,
        "joyY": 0,
        "joyZ": 0,
        "fader": -1,
        "pedal": -1,
        "selector": -1,
        "encoder": -1,
        "encoderPressed": false
    })
    
    // Seuils de changement minimum (réglables)
    property int wheelThreshold: 2        // ±2 degrés pour le volant
    property int joystickThreshold: 5     // ±5 unités pour le joystick
    property int faderThreshold: 3        // ±3 valeurs pour fader/pédale
    
    // Signal émis quand on reçoit des données
    signal dataReceived(var data)
    signal configReceived(var config)
    signal controlChangeReceived(int ccNumber, int ccValue)  // Signal pour les CC MIDI
    signal playbackPositionReceived(bool playing, int bar, int beatInBar, real beat)  // Position lecture (format 9 octets, legacy)
    signal playbackTickReceived(bool playing, int tick)  // Position lecture = tick seul (6 octets), JS gère bar/beat
    signal filesListReceived(var categories)  // Liste fichiers MIDI
    signal gameModeReceived(bool enabled)  // Mode jeu activé/désactivé par le serveur
    signal padCalibrationValuesReceived(var values)  // [int16, int16] pour affichage sous les boutons (pad 0 et 1)
    signal joystickCalibrationStateReceived(var data)  // JOYSTICK_CALIBRATION_STATE : { x: [...], y: [...] }
    signal joystickFilteredValuesReceived(real x, real y)  // JOYSTICK_FILTERED : { xy: [x, y] }
    /** Consigne chef (mode dirigé) — voir docs/CONDUCTOR_CUES_PROTOCOL.md */
    signal conductorCueReceived(var data)
    property var configController: null
    property var rootWindow: null  // Référence vers la fenêtre racine (Main.qml)
    
    // Propriétés pour la réception binaire
    property var binaryBuffer: null      // Buffer pour stocker les bytes
    property int expectedSize: 0         // Taille totale attendue
    property int receivedBytes: 0        // Nombre de bytes déjà reçus
    
    // ⏱️ TIMER POUR THROTTLING DES CONTRÔLEURS (Solution 1)
    Timer {
        id: controllersUpdateTimer
        interval: controller.controllersThrottleMs
        repeat: false
        onTriggered: {
            if (controller.pendingControllersData) {
                // Traiter le dernier message accumulé
                controller.dataReceived(controller.pendingControllersData)
                controller.pendingControllersData = null
            }
        }
    }
    
    // 📊 TIMER POUR STATISTIQUES (Solution 4)
    Timer {
        id: statsTimer
        interval: 1000  // Toutes les secondes
        repeat: true
        running: true
        onTriggered: {
            controller.messagesPerSecond = controller.messageCountThisSecond
            controller.controllersMessagesPerSecond = controller.controllersMessageCountThisSecond
            
            // Logger uniquement si debugMode activé ou si trafic élevé
            if (controller.debugMode || controller.messagesPerSecond > 50) {
                // Stats tracking (logs removed)
            }
            
            // Réinitialiser les compteurs
            controller.messageCountThisSecond = 0
            controller.controllersMessageCountThisSecond = 0
        }
    }
    
    // 🔍 FONCTION DE FILTRAGE (Solution 2)
    function hasSignificantChange(controllers) {
        var changed = false
        var lastVals = controller.lastControllerValues
        
        // Vérifier volant (changement de position significatif)
        if (Math.abs(controllers.wheel.position - lastVals.wheelPos) > controller.wheelThreshold) {
            changed = true
        }
        
        // Vérifier joystick (au moins un axe a bougé significativement)
        if (Math.abs(controllers.joystick.x - lastVals.joyX) > controller.joystickThreshold ||
            Math.abs(controllers.joystick.y - lastVals.joyY) > controller.joystickThreshold ||
            Math.abs(controllers.joystick.z - lastVals.joyZ) > controller.joystickThreshold) {
            changed = true
        }
        
        // Vérifier fader
        if (Math.abs(controllers.fader.value - lastVals.fader) > controller.faderThreshold) {
            changed = true
        }
        
        // Vérifier pédale
        if (Math.abs(controllers.modPedal.value - lastVals.pedal) > controller.faderThreshold) {
            changed = true
        }
        
        // Vérifier sélecteur (changement de vitesse)
        if (controllers.gearShift.position !== lastVals.selector) {
            changed = true
        }
        
        // Pads et boutons: toujours traiter (changements discrets importants)
        if (controllers.pad1.active || controllers.pad2.active || 
            controllers.buttons.button1 || controllers.buttons.button2 ||
            controllers.joystick.button) {
            changed = true
        }
        
        // Encodeur : toujours laisser passer (la détection des changements est gérée par EncoderController)
        if (controllers.encoder) {
            changed = true
        }
        
        return changed
    }
    
    // 💾 FONCTION DE MISE À JOUR DU CACHE (Solution 2)
    function updateControllerCache(controllers) {
        controller.lastControllerValues = {
            "wheelPos": controllers.wheel.position,
            "joyX": controllers.joystick.x,
            "joyY": controllers.joystick.y,
            "joyZ": controllers.joystick.z,
            "fader": controllers.fader.value,
            "pedal": controllers.modPedal.value,
            "selector": controllers.gearShift.position,
            "encoder": controllers.encoder ? controllers.encoder.value : -1,
            "encoderPressed": controllers.encoder ? (controllers.encoder.pressed > 0 || controllers.encoder.pressed === true) : false
        }
    }
    
    WebSocket {
        id: socket
        url: controller.serverUrl
        active: false
        
        onBinaryMessageReceived: function(message) {
            try {
                var bytes = new Uint8Array(message);
                
                // 📊 Incrémenter compteur total de messages
                controller.messageCountThisSecond++
                
                // Format binaire pour CONTROLLERS (type 0x02, 18 bytes) - CONTRÔLEURS PHYSIQUES
                if (bytes.length === 18 && bytes[0] === 0x02) {
                    // 📊 Incrémenter compteur de messages contrôleurs
                    controller.controllersMessageCountThisSecond++
                    
                    // Décoder les données
                    // Volant position (uint16, déjà en degrés 0-360)
                    var wheelPos = bytes[1] | (bytes[2] << 8);
                    
                    // Pads (2 pads distincts)
                    var pad1After = bytes[3];
                    var pad1Vel = bytes[4];
                    var pad2After = bytes[5];
                    var pad2Vel = bytes[6];
                    
                    // Joystick : 0-127 = +0 à +127, 128-255 = -0 à -127
                    var joyX = bytes[7] <= 127 ? bytes[7] : bytes[7] - 255;
                    var joyY = bytes[8] <= 127 ? bytes[8] : bytes[8] - 255;
                    var joyZ = bytes[9] <= 127 ? bytes[9] : bytes[9] - 255;
                    
                    // Joystick bouton
                    var joyBtn = bytes[10] > 0 ? 1 : 0;
                    
                    // Sélecteur 5 vitesses (0-4)
                    var selector = bytes[11];
                    
                    // Fader et pédale
                    var fader = bytes[12];
                    var pedal = bytes[13];
                    
                    // Boutons supplémentaires
                    var btn1 = bytes[14] > 0 ? 1 : 0;
                    var btn2 = bytes[15] > 0 ? 1 : 0;
                    
                    // Encoder (nouveau, bytes 16-17)
                    var encoderValue = bytes[16];
                    var encoderPressed = bytes[17] > 0 ? true : false;
                    
                    // Valeurs demi-tons pour GearShift (5 positions : 0, 1, 12, 24, 48)
                    var gearSemitones = [0, 1, 12, 24, 48];
                    var gearDisplayValue = String(gearSemitones[selector] ?? 0);
                    
                    // Créer l'objet contrôleurs
                    var controllers = {
                        wheel: {
                            position: wheelPos,  // 0-360 degrés (déjà converti par PureData)
                            velocity: 0  // Non disponible dans ce format
                        },
                        joystick: {
                            x: joyX,
                            y: joyY,
                            z: joyZ,
                            button: joyBtn === 1
                        },
                        gearShift: {
                            position: selector,      // 0-4 (5 vitesses)
                            mode: gearDisplayValue   // 0, 1, 12, 24, 48 (demi-tons)
                        },
                        fader: {
                            value: fader
                        },
                        modPedal: {
                            value: pedal,
                            percent: (pedal / 127.0) * 100.0
                        },
                        pad1: {
                            velocity: pad1Vel,
                            aftertouch: pad1After,
                            active: pad1Vel > 0
                        },
                        pad2: {
                            velocity: pad2Vel,
                            aftertouch: pad2After,
                            active: pad2Vel > 0
                        },
                        buttons: {
                            button1: btn1 === 1,
                            button2: btn2 === 1
                        },
                        encoder: {
                            value: encoderValue,
                            pressed: encoderPressed
                        }
                    };
                    
                    // 🔍 FILTRAGE: Vérifier si le changement est significatif (Solution 2)
                    if (!controller.hasSignificantChange(controllers)) {
                        // Changement insignifiant, ignorer ce message
                        controller.droppedMessagesCount++
                        return;
                    }
                    
                    // ⏱️ THROTTLING: Accumuler et traiter avec délai (Solution 1)
                    var data = {
                        controllers: controllers,
                        isControllersOnly: true,  // Flag pour identifier ce type de message
                        timestamp: Date.now()
                    };
                    
                    // Mise à jour du cache pour le prochain filtrage
                    controller.updateControllerCache(controllers)
                    
                    // Accumuler le message (le dernier sera traité)
                    controller.pendingControllersData = data
                    
                    // Démarrer le timer s'il n'est pas déjà en cours
                    if (!controllersUpdateTimer.running) {
                        controllersUpdateTimer.start()
                    }
                    
                    return;
                }
                
                // Format binaire 0x01 - POSITION : mesure seule (4 bytes) — Pd envoie mesure 0-based → passer 1-based au séquenceur
                if (bytes.length === 4 && bytes[0] === 0x01) {
                    var flags = bytes[1];
                    var playing = (flags & 0x01) !== 0;
                    var measure = bytes[2] | (bytes[3] << 8);
                    controller.playbackPositionReceived(playing, measure + 1, 1, 1.0);
                    return;
                }
                // Format binaire 0x01 - POSITION : tick seul (6 bytes) — JS dérive bar/beat depuis BPM/PPQ
                if (bytes.length === 6 && bytes[0] === 0x01) {
                    var flags = bytes[1];
                    var playing = (flags & 0x01) !== 0;
                    var tick = (bytes[2] | (bytes[3] << 8) | (bytes[4] << 16) | (bytes[5] << 24)) >>> 0;
                    controller.playbackTickReceived(playing, tick);
                    return;
                }
                // Format legacy 0x01 - POSITION (9 bytes) - bar, beatInBar, beat
                if (bytes.length === 9 && bytes[0] === 0x01) {
                    var flags = bytes[1];
                    var playing = (flags & 0x01) !== 0;
                    var bar = bytes[2] | (bytes[3] << 8);
                    var beatInBar = bytes[4];
                    var f0 = bytes[5], f1 = bytes[6], f2 = bytes[7], f3 = bytes[8];
                    var beat = new DataView(Uint8Array.of(f0, f1, f2, f3).buffer).getFloat32(0, true);
                    controller.playbackPositionReceived(playing, bar, beatInBar, beat);
                    return;
                }
                
                // Format binaire 0x03 - MIDI_NOTE_VOLANT (5 bytes)
                if (bytes.length === 5 && bytes[0] === 0x03) {
                    // Format: [0x03, note, velocity, bend_lsb, bend_msb]
                    var note = bytes[1];
                    var velocity = bytes[2];
                    var bendLsb = bytes[3];
                    var bendMsb = bytes[4];
                    
                    // Calculer le pitch bend (14 bits, centré à 8192)
                    // bendLsb = 7 bits bas, bendMsb = 7 bits haut
                    var pitchBend = bendLsb | (bendMsb << 7);
                    var bendSemitones = ((pitchBend - 8192) / 8192.0) * 2.0;  // ±2 demi-tons
                    
                    // Note finale avec micro-tonalité
                    var midiNote = note + bendSemitones;
                    
                    // Créer l'objet événement (va vers sirenController.midiNote)
                    var event = {
                        midiNote: midiNote,
                        note: note,
                        velocity: velocity,
                        isVolantNote: true,  // Flag pour distinguer du séquenceur
                        timestamp: Date.now()
                    };
                    
                    // Transmettre l'événement
                    controller.dataReceived(event);
                    return;
                }
                
                // Format binaire pour Control Change (3 bytes) - CC MIDI SÉQUENCE
                if (bytes.length === 3 && bytes[0] === 0x05) {
                    // Format: [0x05, CC_number, value]
                    var ccNumber = bytes[1];
                    var ccValue = bytes[2];  // 0-127
                    
                    // Émettre un signal pour les CC de séquence
                    controller.controlChangeReceived(ccNumber, ccValue);
                    return;
                }
                
                // Format binaire 0x06 - ENCODER_VALUE : rotation de l'encodeur (2 bytes)
                if (bytes.length === 2 && bytes[0] === 0x06) {
                    // Format: [0x06, value] où value est 0-127
                    var encoderValue = bytes[1];
                    
                    // Créer l'objet encoder avec uniquement la valeur
                    var encoderData = {
                        encoder: {
                            value: encoderValue
                        }
                    };
                    
                    // Envoyer vers EncoderController via dataReceived
                    controller.dataReceived({
                        controllers: encoderData,
                        isEncoderNavigation: true,
                        timestamp: Date.now()
                    });
                    return;
                }
                
                // Format binaire 0x07 - ENCODER_PUSH : appui du bouton encodeur (2 bytes)
                if (bytes.length === 2 && bytes[0] === 0x07) {
                    // Format: [0x07, pressed] où pressed est 0 (relâché) ou 1 (appuyé)
                    var encoderPressed = bytes[1] > 0;
                    
                    // Créer l'objet encoder avec uniquement l'état du bouton
                    var encoderData = {
                        encoder: {
                            pressed: encoderPressed
                        }
                    };
                    
                    // Envoyer vers EncoderController via dataReceived
                    controller.dataReceived({
                        controllers: encoderData,
                        isEncoderNavigation: true,
                        timestamp: Date.now()
                    });
                    return;
                }
                
                // Format binaire optimisé pour les notes MIDI avec durée (5 bytes)
                if (bytes.length === 5 && bytes[0] === 0x04) {
                    // Format: [0x04, note, velocity, duration_lsb, duration_msb]
                    var note = bytes[1];
                    var velocity = bytes[2];
                    var duration = bytes[3] + (bytes[4] << 8);  // Durée en ms (16 bits, max 65535ms = 65.5s)
                    
                    // Créer l'objet événement avec durée
                    var event = {
                        midiNote: note,
                        note: note,
                        velocity: velocity,
                        duration: duration,
                        timestamp: Date.now(),
                        controllers: {},
                        isSequence: true  // Flag pour différencier séquence/contrôleurs
                    };
                    
                    // Transmettre l'événement
                    controller.dataReceived(event);
                    return;
                }
                
                // Format binaire config (8+ bytes)
                if (bytes.length < 8) {
                    return;
                }
                
                // Décoder les métadonnées (toujours présentes)
                var totalSize = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
                var position = bytes[4] | (bytes[5] << 8) | (bytes[6] << 16) | (bytes[7] << 24);
                
                // Les données commencent à l'index 8
                var dataLength = bytes.length - 8;
                
                // Initialiser le buffer si nécessaire
                if (!controller.binaryBuffer || controller.expectedSize !== totalSize) {
                    controller.binaryBuffer = new Array(totalSize);
                    controller.expectedSize = totalSize;
                    controller.receivedBytes = 0;
                }
                
                // Copier les données à la bonne position
                for (var i = 0; i < dataLength; i++) {
                    controller.binaryBuffer[position + i] = bytes[8 + i];
                }
                controller.receivedBytes += dataLength;
                
                // Vérifier si on a tout reçu
                if (controller.receivedBytes >= totalSize) {
                    
                    // Reconstruire le JSON
                    var jsonString = "";
                    for (var j = 0; j < totalSize; j++) {
                        jsonString += String.fromCharCode(controller.binaryBuffer[j]);
                    }
                    
                    var jsonData = JSON.parse(jsonString);
                    if (jsonData.type === "CONFIG_FULL" && controller.configController) {
                        controller.configController.updateFullConfig(jsonData.config);
                    }
                    
                    // Réinitialiser
                    controller.binaryBuffer = null;
                    controller.expectedSize = 0;
                    controller.receivedBytes = 0;
                }
            } catch (e) {
            }
        }
        
        // Alternative plus simple si PureData envoie en texte les métadonnées
        onTextMessageReceived: function(message) {
            try {
                // Logs désactivés pour performance
                
                // Gérer les messages de contrôle binaire
                if (message === "BINARY_END") {
                    if (controller.receivingBinary && controller.binaryBuffer.length > 0) {
                        // Forcer le traitement même si incomplet
                        var jsonString = "";
                        for (var i = 0; i < controller.binaryBuffer.length; i++) {
                            jsonString += String.fromCharCode(controller.binaryBuffer[i]);
                        }
                        
                        var jsonData = JSON.parse(jsonString);
                        if (jsonData.type === "CONFIG_FULL") {
                            if (controller.configController && jsonData.config) {
                                controller.configController.updateFullConfig(jsonData.config);
                            }
                        }
                        
                        controller.receivingBinary = false;
                        controller.binaryBuffer = [];
                    }
                    return;
                }
                
                // Gérer BINARY_START si envoyé en texte
                if (message.startsWith("BINARY_START")) {
                    var parts = message.split(" ");
                    if (parts.length >= 3) {
                        controller.expectedSize = parseInt(parts[1]);
                        controller.chunkSize = parseInt(parts[2]);
                        controller.binaryBuffer = [];
                        controller.receivingBinary = true;
                    }
                    return;
                }
                
                var data = JSON.parse(message);
                
                // Log spécifique pour PARAM_UPDATE avec uiControls (pour debug)
                if (data.type === "PARAM_UPDATE" && data.path && Array.isArray(data.path) && 
                    data.path.length === 2 && data.path[0] === "uiControls" && data.path[1] === "enabled") {
                    console.log("[WebSocket] UI_CONTROLS message onTextMessageReceived type:", data.type, "path:", JSON.stringify(data.path), "value:", data.value)
                }
                
                // Logs désactivés pour performance
                
                // Mettre à jour les statistiques
                controller.messageCount++
                var now = new Date()
                controller.lastMessageTime = now.toLocaleTimeString()
                
                // Logs désactivés pour performance
                
                // Gestion de la présence de la console
                if (data.type === "CONSOLE_CONNECT") {
                    consoleConnected = true
                    if (controller.configController) controller.configController.consoleConnected = true
                    return
                }
                if (data.type === "CONSOLE_DISCONNECT") {
                    consoleConnected = false
                    if (controller.configController) controller.configController.consoleConnected = false
                    return
                }
                if (data.type === "PAD_CONNECTED") {
                    var padConnected = data.connected === true
                    if (controller.configController) controller.configController.padConnected = padConnected
                    return
                }

                // GEAR - Vitesse / GearShift envoyée par Pure Data en JSON (un seul message simple, pas dans le paquet binaire debug)
                if (data.type === "GEAR") {
                    var gearPos = (typeof data.position === "number" && data.position >= 0 && data.position <= 4) ? data.position : 0
                    var gearSemitones = [0, 1, 12, 24, 48]
                    var gearDisplayValue = String(gearSemitones[gearPos] ?? 0)
                    var gearControllers = {
                        gearShift: {
                            position: gearPos,
                            mode: gearDisplayValue   // 0, 1, 12, 24, 48 (demi-tons)
                        }
                    }
                    controller.dataReceived({
                        controllers: gearControllers,
                        isControllersOnly: true,
                        timestamp: Date.now()
                    })
                    return
                }

                // ENCODER_NAV : DÉPRÉCIÉ - Les messages encodeur utilisent maintenant les messages binaires 0x06 (value) et 0x07 (push)
                // Le traitement JSON ENCODER_NAV a été supprimé en faveur des messages binaires pour améliorer les performances

                // AJOUTER : Traiter PARAM_UPDATE
                if (data.type === "PARAM_UPDATE") {
                    // Log spécifique pour uiControls (préfixe unique pour filtrage)
                    if (data.path && Array.isArray(data.path) && data.path.length === 2 &&
                        data.path[0] === "uiControls" && data.path[1] === "enabled") {
                        console.log("[WebSocket] UI_CONTROLS_PARAM_UPDATE path:", JSON.stringify(data.path), "value:", data.value)
                        var enabled = data.value !== undefined ? (data.value !== 0) : true
                        console.log("[WebSocket] UI_CONTROLS_PARAM_UPDATE enabled calculé:", enabled, "rootWindow:", !!controller.rootWindow)
                        if (controller.rootWindow && controller.rootWindow.uiControlsEnabled !== undefined) {
                            console.log("[WebSocket] UI_CONTROLS_PARAM_UPDATE mise à jour uiControlsEnabled:", enabled)
                            controller.rootWindow.uiControlsEnabled = enabled
                            console.log("[WebSocket] UI_CONTROLS_PARAM_UPDATE uiControlsEnabled:", controller.rootWindow.uiControlsEnabled)
                        } else {
                            console.log("[WebSocket] UI_CONTROLS_PARAM_UPDATE ERREUR rootWindow ou uiControlsEnabled manquant")
                        }
                        return
                    }
                    
                    // Debug : PARAM_UPDATE frettedMode (path[2] = index tableau 0-based ou id chaîne)
                    if (data.path && Array.isArray(data.path) && data.path.length >= 4 && 
                        data.path[0] === "sirenConfig" && data.path[1] === "sirens" && 
                        data.path[3] === "frettedMode" && data.path[4] === "enabled") {
                        var sirenIdentifier = data.path[2];
                        var isNumericIndex = typeof sirenIdentifier === "number";
                        var dbgId = null
                        if (controller.configController && isNumericIndex) {
                            var sirens = controller.configController.getValueAtPath(["sirenConfig", "sirens"], []);
                            if (sirens[sirenIdentifier])
                                dbgId = sirens[sirenIdentifier].id
                        }
                        console.log("[WebSocket] PARAM_UPDATE frettedMode sirens",
                            isNumericIndex ? ("index=" + sirenIdentifier + (dbgId !== null ? " id=" + dbgId : "")) : ("id=" + sirenIdentifier),
                            "enabled:", data.value);
                    }
                    
                    if (!controller.configController) {
                        return;
                    }
                    
                    if (!data.path || !Array.isArray(data.path)) {
                        return;
                    }
                    
                    if (data.value === undefined) {
                        return;
                    }
                    
                    // Afficher le chemin complet pour debug
                    
                    // Appeler setValueAtPath et logger le résultat
                    try {
                        // Transmettre la source pour éviter les renvois inutiles
                        var result = controller.configController.setValueAtPath(data.path, data.value, data.source || "console");
                        
                        // Vérifier la valeur après modification
                        var newValue = controller.configController.getValueAtPath(data.path);
                        
                        if (newValue !== data.value && typeof newValue !== typeof data.value) {
                        }
                    } catch (e) {
                    }
                    
                    return;
                }
                
                // Après le bloc PARAM_UPDATE
                if (data.type === "CONFIG_FULL") {
                    if (controller.configController && data.config) {
                        controller.configController.updateFullConfig(data.config);
                    }
                    return;
                }
                
                // MIDI_FILES_LIST - Liste des fichiers MIDI disponibles
                if (data.type === "MIDI_FILES_LIST") {
                    controller.filesListReceived(data.categories || []);
                    return;
                }
                
                // GAME_MODE - Changement de mode jeu/normal depuis le serveur (PureData)
                if (data.type === "GAME_MODE") {
                    var enabled = data.enabled || false;
                    console.log("[WebSocket] GAME_MODE enabled:", enabled);
                    controller.gameModeReceived(enabled);
                    return;
                }

                // PAD_CALIBRATION_VALUE - Une seule structure : valeurs int16 pour les deux pads
                // Accepte: [val0, val1], ["31 3"] (chaîne space-separated), ou "31 3"
                if (data.type === "PAD_CALIBRATION_VALUE") {
                    var vals = [0, 0];
                    var raw = data.values;
                    if (raw !== undefined && raw !== null) {
                        var parts = [];
                        if (Array.isArray(raw)) {
                            if (raw.length > 0 && typeof raw[0] === "string" && raw[0].indexOf(" ") >= 0) {
                                parts = raw[0].trim().split(/\s+/);
                            } else {
                                parts = raw;
                            }
                        } else if (typeof raw === "string") {
                            parts = raw.trim().split(/\s+/);
                        }
                        for (var i = 0; i < 2 && i < parts.length; i++) {
                            var v = parseInt(parts[i], 10);
                            if (!isFinite(v)) v = 0;
                            if (v < -32768) v = -32768;
                            if (v > 32767) v = 32767;
                            vals[i] = v;
                        }
                    }
                    console.log("[PAD_CALIB] Reçu values:", JSON.stringify(vals), "raw data.values:", raw !== undefined ? JSON.stringify(raw) : "undefined")
                    controller.padCalibrationValuesReceived(vals);
                    return;
                }

                if (data.type === "JOYSTICK_CALIBRATION_STATE") {
                    controller.joystickCalibrationStateReceived({
                        x: data.x,
                        y: data.y
                    });
                    return;
                }

                if (data.type === "JOYSTICK_FILTERED") {
                    var arr = null;
                    if (Array.isArray(data.xy) && data.xy.length >= 2)
                        arr = data.xy;
                    else if (Array.isArray(data.values) && data.values.length >= 2)
                        arr = data.values;
                    if (arr) {
                        var jfx = Number(arr[0]);
                        var jfy = Number(arr[1]);
                        if (isFinite(jfx) && isFinite(jfy))
                            controller.joystickFilteredValuesReceived(jfx, jfy);
                    }
                    return;
                }

                if (data.type === "CONDUCTOR_CUE") {
                    controller.conductorCueReceived(data);
                    return;
                }
                
                // Code existant pour MUSIC_VISUALIZER
                if (data.device === "MUSIC_VISUALIZER") {
                    // Logs désactivés pour performance
                    if (data.config) {
                        controller.configReceived(data.config);
                    } else {
                        controller.dataReceived(data);
                    }
                } else {
                    // Logs désactivés pour performance
                    // Essayer de traiter comme données musicales par défaut
                    if (data.midiNote !== undefined || data.controllers) {
                        controller.dataReceived(data);
                    }
                }
            } catch (e) {
            }
        }
        
        onStatusChanged: function(status) {
            if (controller.debugMode || status === WebSocket.Error) { // Toujours logger les erreurs
                switch(status) {
                    case WebSocket.Error:
                        break;
                    case WebSocket.Open:
                        // Marquer qu'on attend la config
                        if (controller.configController) {
                            controller.configController.waitingForConfig = true;
                        }
                        // Demander la configuration complète à PureData
                        controller.sendBinaryMessage({
                            type: "REQUEST_CONFIG"
                        });
                        break;
                    case WebSocket.Closed:
                        break;
                }
            }
        }
    }
    
    // Auto-connexion au démarrage
    Component.onCompleted: {
        connect();
    }
    
    // Fonctions de contrôle
    function connect() {
        socket.active = true;
    }
    
    function disconnect() {
        socket.active = false;
    }
    
    function reconnect() {
        socket.active = false;
        socket.active = true;
    }
    
    function sendBinaryMessage(message) {
        if (socket.status === WebSocket.Open) {
            if (controller.debugMode) {
            }
            // Convertir le JSON en string puis en binaire
            var jsonString = JSON.stringify(message);
            socket.sendBinaryMessage(jsonString);
        }
    }
    
    // Fonction pour envoyer un vrai message binaire (ArrayBuffer)
    function sendRawBinaryMessage(buffer) {
        if (socket.status === WebSocket.Open) {
            socket.sendBinaryMessage(buffer);
            return true;
        }
        return false;
    }

    // Garder sendMessage pour compatibilité si besoin
    function sendMessage(message) {
        // Utiliser sendBinaryMessage par défaut maintenant
        sendBinaryMessage(message);
    }
}
