import QtQuick
import QtQuick3D
import QtQuick.Controls
import "../utils"
import "../components"
import "../components/ambitus"

/**
 * Mode Jeu "Siren Hero"
 * Vue principale du jeu avec partition défilante
 */
Item {
    id: root
    
    // Propriétés reçues
    property var webSocketController: null
    property var sirenController: null
    property var configController: null
    
    // État du jeu
    property bool gameActive: false
    property string midiFile: ""
    property string gameMode: "practice"  // practice, performance, challenge
    property string difficulty: "normal"  // easy, normal, hard, expert
    
    // Paramètres du jeu
    property int lookaheadMs: 2000  // Avance d'affichage (ms)
    property int toleranceMs: 150   // Tolérance timing (ms)
    property bool showNotes: true
    
    // Score et stats
    property int score: 0
    property int combo: 0
    property int maxCombo: 0
    property int accuracy: 0  // 0-100%
    property int perfect: 0
    property int good: 0
    property int miss: 0
    
    // Leaderboard (multi-joueurs)
    property var leaderboard: []  // [{rank, pupitreId, score, combo, accuracy}]
    
    // Événements musicaux (notes à venir)
    property var upcomingEvents: []  // [{timestamp, note, velocity, controllers}]
    
    // Temps de jeu
    property real gameTime: 0  // Temps écoulé depuis le début (ms)
    property real gameStartTime: 0
    
    // Connexion WebSocket pour recevoir messages de jeu
    Connections {
        target: webSocketController
        
        function onBinaryDataReceived(data) {
            if (!gameActive) return
            
            var view = new DataView(data)
            var messageType = view.getUint8(0)
            
            // Messages de jeu reçus du serveur
            if (messageType === 0x12) {  // GAME_LEADERBOARD
                handleLeaderboard(data)
            }
        }
        
        function onDataReceived(data) {
            if (!data || !data.type) return
            
            // Messages JSON du jeu
            if (data.type === "GAME_START") {
                handleGameStart(data)
            } else if (data.type === "GAME_PAUSE") {
                gameActive = !data.paused
            } else if (data.type === "GAME_ABORT") {
                endGame()
            } else if (data.type === "GAME_SEQUENCE") {
                upcomingEvents = data.events || []
            }
        }
    }
    
    // Démarrage du jeu
    function handleGameStart(data) {
        console.log("🎮 GAME_START reçu:", JSON.stringify(data))
        
        midiFile = data.midiFile
        gameMode = data.mode
        difficulty = data.difficulty
        lookaheadMs = data.options?.lookaheadMs || 2000
        toleranceMs = data.options?.toleranceMs || 150
        showNotes = data.options?.showNotes !== false
        
        // Reset scores
        score = 0
        combo = 0
        maxCombo = 0
        accuracy = 0
        perfect = 0
        good = 0
        miss = 0
        
        // Attendre le syncTimestamp pour démarrer
        var countdown = data.countdown || 3
        var syncTimestamp = data.syncTimestamp
        var now = Date.now()
        var delay = syncTimestamp - now
        
        console.log("⏱ Démarrage dans", delay, "ms (countdown:", countdown, "s)")
        
        // Timer de countdown
        countdownTimer.interval = delay
        countdownTimer.restart()
    }
    
    // Timer de countdown
    Timer {
        id: countdownTimer
        repeat: false
        onTriggered: {
            console.log("🎮 GO! Partie démarrée")
            gameActive = true
            gameStartTime = Date.now()
            gameTimer.start()
        }
    }
    
    // Timer de jeu (60 FPS)
    Timer {
        id: gameTimer
        interval: 16  // ~60 FPS
        repeat: true
        running: gameActive
        
        onTriggered: {
            if (gameActive) {
                gameTime = Date.now() - gameStartTime
                updateLinePositions()
                checkEventsAtCursor()
            }
        }
    }
    
    // Mettre à jour les positions des lignes mélodiques
    function updateLinePositions() {
        melodicLineRepeater.updatePositions(gameTime)
    }
    
    // Vérifier les événements au curseur NOW
    function checkEventsAtCursor() {
        // Comparer les contrôleurs actuels vs attendus
        if (upcomingEvents.length === 0) return
        
        var currentControllers = {
            wheel: sirenController ? sirenController.wheelPosition : 0,
            fader: sirenController ? sirenController.faderValue : 0
            // TODO: ajouter joystick, gearShift, etc.
        }
        
        // Vérifier si un événement est dans la fenêtre de timing
        for (var i = 0; i < upcomingEvents.length; i++) {
            var event = upcomingEvents[i]
            var timingDiff = Math.abs(gameTime - event.timestamp)
            
            if (timingDiff <= toleranceMs) {
                // Calculer la précision
                var result = calculateAccuracy(event, currentControllers)
                if (result) {
                    handleEventHit(event, result)
                    upcomingEvents.splice(i, 1)
                    i--
                }
            }
        }
    }
    
    // Calculer la précision d'un hit
    function calculateAccuracy(event, currentControllers) {
        if (!event.controllers) return null
        
        var totalAccuracy = 0
        var count = 0
        
        // Comparer chaque contrôleur
        if (event.controllers.wheel) {
            var expected = event.controllers.wheel.position
            var actual = currentControllers.wheel
            var tolerance = event.controllers.wheel.tolerance || 10
            var diff = Math.abs(expected - actual)
            var acc = 1 - (diff / tolerance)
            totalAccuracy += Math.max(0, acc)
            count++
        }
        
        if (event.controllers.fader) {
            var expected = event.controllers.fader.value
            var actual = currentControllers.fader
            var tolerance = event.controllers.fader.tolerance || 10
            var diff = Math.abs(expected - actual)
            var acc = 1 - (diff / tolerance)
            totalAccuracy += Math.max(0, acc)
            count++
        }
        
        var avgAccuracy = count > 0 ? totalAccuracy / count : 0
        
        // Déterminer le rating
        var rating = 0  // miss
        if (avgAccuracy >= 0.95) rating = 2  // perfect
        else if (avgAccuracy >= 0.80) rating = 1  // good
        else if (avgAccuracy >= 0.50) rating = 0  // ok (pas de points bonus mais pas de reset combo)
        else rating = -1  // miss
        
        return {
            accuracy: avgAccuracy,
            rating: rating
        }
    }
    
    // Gérer un hit d'événement
    function handleEventHit(event, result) {
        var baseScore = 100
        var scoreMultiplier = [0, 1, 2, 3][result.rating + 1]  // miss=0, ok=1, good=2, perfect=3
        
        // Combo
        if (result.rating >= 0) {
            combo++
            maxCombo = Math.max(maxCombo, combo)
        } else {
            combo = 0
        }
        
        // Multiplicateur de combo
        var comboMultiplier = 1
        if (combo >= 20) comboMultiplier = 4
        else if (combo >= 10) comboMultiplier = 3
        else if (combo >= 5) comboMultiplier = 2
        
        var earnedScore = baseScore * scoreMultiplier * comboMultiplier
        score += earnedScore
        
        // Stats
        if (result.rating === 2) perfect++
        else if (result.rating === 1) good++
        else if (result.rating === -1) miss++
        
        // Accuracy global
        var totalHits = perfect + good + miss
        if (totalHits > 0) {
            accuracy = Math.floor(((perfect * 100 + good * 80) / (totalHits * 100)) * 100)
        }
        
        // Afficher feedback visuel
        gameFeedback.show(result.rating, earnedScore)
        
        // Envoyer GAME_NOTE_HIT au serveur (binaire 0x10)
        sendNoteHit(event, result, earnedScore)
        
        // Envoyer GAME_SCORE_UPDATE (binaire 0x11) toutes les secondes
        if (!scoreUpdateTimer.running) {
            scoreUpdateTimer.restart()
        }
    }
    
    // Timer pour envoyer les scores (1 sec)
    Timer {
        id: scoreUpdateTimer
        interval: 1000
        repeat: false
        onTriggered: {
            sendScoreUpdate()
        }
    }
    
    // Envoyer GAME_NOTE_HIT (0x10 - 9 bytes)
    function sendNoteHit(event, result, earnedScore) {
        var buffer = new ArrayBuffer(9)
        var view = new DataView(buffer)
        
        view.setUint8(0, 0x10)  // messageType
        view.setUint8(1, configController.pupitreId || 1)  // pupitreId
        view.setUint8(2, event.note || 60)  // noteNumber
        view.setUint8(3, event.controllers.wheel?.position || 0)  // expectedValue
        view.setUint8(4, sirenController.wheelPosition || 0)  // actualValue
        view.setInt16(5, 0, true)  // timingMs (à calculer)
        view.setUint8(7, result.rating + 1)  // rating (0=miss, 1=good, 2=perfect)
        view.setUint8(8, Math.floor(earnedScore / 10))  // scoreGained / 10
        
        webSocketController.sendBinary(buffer)
    }
    
    // Envoyer GAME_SCORE_UPDATE (0x11 - 14 bytes)
    function sendScoreUpdate() {
        var buffer = new ArrayBuffer(14)
        var view = new DataView(buffer)
        
        view.setUint8(0, 0x11)  // messageType
        view.setUint8(1, configController.pupitreId || 1)  // pupitreId
        view.setUint32(2, score, true)  // score
        view.setUint16(6, combo, true)  // combo
        view.setUint16(8, maxCombo, true)  // maxCombo
        view.setUint8(10, accuracy)  // accuracy (0-100%)
        view.setUint8(11, perfect)  // perfect
        view.setUint8(12, good)  // good
        view.setUint8(13, miss)  // miss
        
        webSocketController.sendBinary(buffer)
    }
    
    // Gérer le leaderboard (0x12)
    function handleLeaderboard(data) {
        var view = new DataView(data)
        var newLeaderboard = []
        
        // Lire tous les joueurs (9 bytes chacun)
        var numPlayers = Math.floor((data.byteLength - 1) / 9)
        
        for (var i = 0; i < numPlayers; i++) {
            var offset = 1 + (i * 9)
            newLeaderboard.push({
                rank: view.getUint8(offset),
                pupitreId: view.getUint8(offset + 1),
                score: view.getUint32(offset + 2, true),
                combo: view.getUint16(offset + 6, true),
                accuracy: view.getUint8(offset + 8)
            })
        }
        
        leaderboard = newLeaderboard
    }
    
    // Terminer le jeu
    function endGame() {
        gameActive = false
        gameTimer.stop()
        
        // Envoyer GAME_END (JSON)
        var rank = calculateRank()
        var endMessage = {
            type: "GAME_END",
            pupitreId: configController.pupitreId || 1,
            finalScore: score,
            accuracy: accuracy / 100.0,
            rank: rank,
            stats: {
                perfect: perfect,
                good: good,
                miss: miss,
                totalNotes: perfect + good + miss,
                maxCombo: maxCombo,
                duration: gameTime
            }
        }
        
        webSocketController.sendMessage(JSON.stringify(endMessage))
    }
    
    // Calculer le rang
    function calculateRank() {
        if (accuracy >= 95) return "S"
        if (accuracy >= 85) return "A"
        if (accuracy >= 75) return "B"
        if (accuracy >= 65) return "C"
        return "D"
    }
    
    // Interface visuelle
    Rectangle {
        anchors.fill: parent
        color: "#0a0a0a"
        
        // Vue 3D pour la partition défilante
        View3D {
            id: mainView3D
            anchors.fill: parent
            
            environment: SceneEnvironment {
                antialiasingMode: SceneEnvironment.MSAA
                antialiasingQuality: SceneEnvironment.High
                backgroundMode: SceneEnvironment.Color
                clearColor: "#0a0a0a"
            }
            
            // Caméra
            PerspectiveCamera {
                id: camera
                position: Qt.vector3d(0, 0, 1000)
                eulerRotation.x: 0
                clipNear: 1
                clipFar: 5000
            }
            
            // Lumière
            DirectionalLight {
                eulerRotation.x: -30
                eulerRotation.y: -70
                brightness: 1.0
                ambientColor: "#404040"
            }
            
            // Portée musicale fixe (fond)
            MusicalStaff3D {
                id: musicalStaff
                z: -50
                currentNoteMidi: sirenController ? sirenController.midiNote : 69
                ambitusMin: configController ? configController.getValueAtPath(["sirenConfig", "ambitus", "min"], 48) : 48
                ambitusMax: configController ? configController.getValueAtPath(["sirenConfig", "ambitus", "max"], 72) : 72
            }
            
            // Curseur NOW (ligne verticale fixe au centre)
            Node {
                id: nowCursor
                x: 0
                z: 0
                
                Model {
                    source: "#Cube"
                    scale: Qt.vector3d(0.02, 15, 1)
                    materials: PrincipledMaterial {
                        baseColor: "#FF0000"
                        emissiveFactor: Qt.vector3d(1, 0, 0)
                        lighting: PrincipledMaterial.NoLighting
                    }
                }
            }
            
            // Répéteur pour les lignes mélodiques
            Repeater {
                id: melodicLineRepeater
                model: upcomingEvents
                
                function updatePositions(currentTime) {
                    // Mettre à jour la position Z de chaque ligne
                    for (var i = 0; i < count; i++) {
                        var item = itemAt(i)
                        if (item) {
                            var event = upcomingEvents[i]
                            var timeUntilPlay = event.timestamp - currentTime
                            item.z = -timeUntilPlay * 0.5  // Profondeur 3D
                        }
                    }
                }
                
                delegate: MelodicLine {
                    event: modelData
                    gameTime: root.gameTime
                }
            }
        }
        
        // HUD (Head-Up Display)
        GameHUD {
            id: gameHUD
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 80
            
            score: root.score
            combo: root.combo
            accuracy: root.accuracy
            leaderboard: root.leaderboard
            pupitreId: configController ? configController.pupitreId : 1
        }
        
        // Feedback visuel (Perfect/Good/Miss)
        GameFeedback {
            id: gameFeedback
            anchors.centerIn: parent
        }
        
        // Barres de contrôleurs (bas)
        Column {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 20
            spacing: 10
            
            ControllerTargetBar {
                width: parent.width
                controllerName: "Volant"
                currentValue: sirenController ? sirenController.wheelPosition : 0
                targetValue: getCurrentTarget("wheel")
                maxValue: 360
            }
            
            ControllerTargetBar {
                width: parent.width
                controllerName: "Fader"
                currentValue: sirenController ? sirenController.faderValue : 0
                targetValue: getCurrentTarget("fader")
                maxValue: 127
            }
        }
    }
    
    // Obtenir la valeur cible du contrôleur le plus proche
    function getCurrentTarget(controllerType) {
        if (upcomingEvents.length === 0) return 0
        
        // Trouver l'événement le plus proche du curseur NOW
        var closestEvent = null
        var minDist = Infinity
        
        for (var i = 0; i < upcomingEvents.length; i++) {
            var event = upcomingEvents[i]
            var dist = Math.abs(event.timestamp - gameTime)
            if (dist < minDist) {
                minDist = dist
                closestEvent = event
            }
        }
        
        if (!closestEvent || !closestEvent.controllers) return 0
        
        if (controllerType === "wheel") {
            return closestEvent.controllers.wheel?.position || 0
        } else if (controllerType === "fader") {
            return closestEvent.controllers.fader?.value || 0
        }
        
        return 0
    }
}

