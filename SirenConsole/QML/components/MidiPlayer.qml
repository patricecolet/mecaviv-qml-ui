import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

/**
 * MidiPlayer - Lecteur MIDI avec contrôles complets
 * Transport, navigation, tempo, position
 */
Rectangle {
    id: root
    
    color: "#2a2a2a"
    radius: 8
    border.color: "#00ff00"
    border.width: 2
    
    // Propriétés
    property var commandManager: null
    
    // État de lecture
    property bool playing: false
    property int position: 0           // Position en ms
    property real beat: 0              // Beat actuel
    property int tempo: 120            // BPM
    property int timeSignatureNum: 4   // Numérateur (4/4)
    property int timeSignatureDen: 4   // Dénominateur
    property int duration: 0           // Durée totale en ms
    property int totalBeats: 0         // Nombre total de beats
    property string currentFile: ""    // Fichier en cours
    
    // Valeurs transport (reçues du serveur via /api/puredata/playback)
    property int currentBar: 1             // Numéro de mesure (reçu ou calculé)
    property int currentBeat: 1            // Beat dans la mesure (reçu ou calculé)
    property int currentFrame: Math.floor((beat % 1) * 960)  // 960 frames par beat (MIDI ticks)
    
    // Signaux
    signal play()
    signal pause()
    signal stop()
    signal seek(int position)
    signal tempoChangeRequested(int tempo)
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10
        
        // En-tête avec titre et fichier en cours
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Label {
                text: "🎵 Lecteur MIDI"
                font.pixelSize: 18
                font.bold: true
                color: "#00ff00"
            }
            
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#444444"
            }
        }
        
        // Fichier en cours (plus visible)
        Rectangle {
            Layout.fillWidth: true
            height: 40
            color: "#1a1a1a"
            radius: 4
            border.color: currentFile ? "#00ff00" : "#444444"
            border.width: 1
            
            Label {
                anchors.fill: parent
                anchors.margins: 10
                text: currentFile ? "▶ " + currentFile : "⏹ Aucun fichier chargé"
                color: currentFile ? "#00ff00" : "#666666"
                font.pixelSize: 13
                font.bold: currentFile !== ""
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideMiddle
            }
        }
        
        // Affichage position avec champs éditables (style DAW)
        Rectangle {
            Layout.fillWidth: true
            height: 70
            color: "#0a0a0a"
            radius: 4
            border.color: "#00ff00"
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 15
                
                // Position: Mesure | Beat | Frame
                RowLayout {
                    spacing: 3
                    
                    // Mesure
                    Rectangle {
                        width: 60
                        height: 50
                        color: "#1a1a1a"
                        radius: 3
                        border.color: barInput.activeFocus ? "#00ff00" : "#333333"
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0
                            
                            Label {
                                text: "MESURE"
                                color: "#666666"
                                font.pixelSize: 8
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                                Layout.topMargin: 3
                            }
                            
                            TextInput {
                                id: barInput
                                text: currentBar.toString().padStart(3, '0')
                                color: "#00ff00"
                                font.pixelSize: 18
                                font.bold: true
                                font.family: "monospace"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                
                                validator: IntValidator { bottom: 1; top: 9999 }
                                
                                onAccepted: {
                                    var newBar = parseInt(text)
                                    if (newBar > 0) {
                                        var newBeat = (newBar - 1) * timeSignatureNum
                                        var newPos = (newBeat / tempo) * 60000
                                        seek(Math.floor(newPos))
                                        focus = false
                                    }
                                }
                            }
                        }
                    }
                    
                    Label {
                        text: "|"
                        color: "#666666"
                        font.pixelSize: 24
                        font.bold: true
                    }
                    
                    // Beat
                    Rectangle {
                        width: 50
                        height: 50
                        color: "#1a1a1a"
                        radius: 3
                        border.color: beatInput.activeFocus ? "#00ff00" : "#333333"
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0
                            
                            Label {
                                text: "BEAT"
                                color: "#666666"
                                font.pixelSize: 8
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                                Layout.topMargin: 3
                            }
                            
                            TextInput {
                                id: beatInput
                                text: currentBeat.toString()
                                color: "#00ff00"
                                font.pixelSize: 18
                                font.bold: true
                                font.family: "monospace"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                
                                validator: IntValidator { bottom: 1; top: timeSignatureNum }
                                
                                onAccepted: {
                                    var newBeat = parseInt(text)
                                    if (newBeat > 0 && newBeat <= timeSignatureNum) {
                                        var totalBeat = (currentBar - 1) * timeSignatureNum + (newBeat - 1)
                                        var newPos = (totalBeat / tempo) * 60000
                                        seek(Math.floor(newPos))
                                        focus = false
                                    }
                                }
                            }
                        }
                    }
                    
                    Label {
                        text: "|"
                        color: "#666666"
                        font.pixelSize: 24
                        font.bold: true
                    }
                    
                    // Frame (ticks MIDI)
                    Rectangle {
                        width: 60
                        height: 50
                        color: "#1a1a1a"
                        radius: 3
                        border.color: frameInput.activeFocus ? "#00ff00" : "#333333"
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0
                            
                            Label {
                                text: "FRAME"
                                color: "#666666"
                                font.pixelSize: 8
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                                Layout.topMargin: 3
                            }
                            
                            TextInput {
                                id: frameInput
                                text: currentFrame.toString().padStart(3, '0')
                                color: "#00ff00"
                                font.pixelSize: 18
                                font.bold: true
                                font.family: "monospace"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                
                                validator: IntValidator { bottom: 0; top: 959 }
                                
                                onAccepted: {
                                    // Les frames sont difficiles à convertir précisément
                                    // On ignore pour l'instant, focus sur bar/beat
                                    focus = false
                                }
                            }
                        }
                    }
                }
                
                // Séparateur vertical
                Rectangle {
                    width: 1
                    height: 50
                    color: "#444444"
                }
                
                // Signature temporelle (éditable)
                Rectangle {
                    width: 80
                    height: 50
                    color: "#1a1a1a"
                    radius: 3
                    border.color: "#ffaa00"
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        Label {
                            text: "SIGNATURE"
                            color: "#666666"
                            font.pixelSize: 8
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                            Layout.topMargin: 3
                        }
                        
                        Label {
                            text: timeSignatureNum + "/" + timeSignatureDen
                            color: "#ffaa00"
                            font.pixelSize: 18
                            font.bold: true
                            font.family: "monospace"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }
                    }
                }
                
                // Tempo (éditable)
                Rectangle {
                    width: 90
                    height: 50
                    color: "#1a1a1a"
                    radius: 3
                    border.color: tempoInput.activeFocus ? "#ffaa00" : "#333333"
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        Label {
                            text: "TEMPO"
                            color: "#666666"
                            font.pixelSize: 8
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                            Layout.topMargin: 3
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 2
                            
                            Item { width: 5 }
                            
                            TextInput {
                                id: tempoInput
                                text: tempo.toString()
                                color: "#ffaa00"
                                font.pixelSize: 18
                                font.bold: true
                                font.family: "monospace"
                                horizontalAlignment: Text.AlignRight
                                verticalAlignment: Text.AlignVCenter
                                Layout.fillHeight: true
                                Layout.preferredWidth: 45
                                
                                validator: IntValidator { bottom: 20; top: 300 }
                                
                                onAccepted: {
                                    var newTempo = parseInt(text)
                                    if (newTempo >= 20 && newTempo <= 300) {
                                        tempoChangeRequested(newTempo)
                                        focus = false
                                    }
                                }
                                
                                Keys.onUpPressed: {
                                    var newTempo = Math.min(300, tempo + 1)
                                    tempoChangeRequested(newTempo)
                                }
                                
                                Keys.onDownPressed: {
                                    var newTempo = Math.max(20, tempo - 1)
                                    tempoChangeRequested(newTempo)
                                }
                            }
                            
                            Label {
                                text: "BPM"
                                color: "#888888"
                                font.pixelSize: 10
                                verticalAlignment: Text.AlignVCenter
                                Layout.fillHeight: true
                            }
                            
                            Item { width: 3 }
                        }
                    }
                }
                
                Item { Layout.fillWidth: true }
            }
        }
        
        // Contrôles de transport
        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            
            // Bouton précédent rapide
            Button {
                text: "◀◀"
                enabled: currentFile !== ""
                implicitWidth: 50
                
                onClicked: {
                    var newPos = Math.max(0, position - 10000) // Recule de 10 secondes
                    seek(newPos)
                }
                
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? "#444444" : "#2a2a2a") : "#1a1a1a"
                    border.color: parent.enabled ? "#00ff00" : "#444444"
                    border.width: 1
                    radius: 4
                }
                
                contentItem: Label {
                    text: parent.text
                    color: parent.enabled ? "#00ff00" : "#666666"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                    font.pixelSize: 16
                }
            }
            
            // Bouton Play/Pause
            Button {
                text: playing ? "⏸" : "▶"
                enabled: currentFile !== ""
                implicitWidth: 60
                
                onClicked: {
                    console.log("🎵 Bouton Play/Pause cliqué - État:", playing ? "PLAY→PAUSE" : "STOP→PLAY")
                    console.log("🎵 CommandManager:", commandManager ? "OK" : "NULL")
                    if (playing) {
                        pause()
                    } else {
                        play()
                    }
                }
                
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? "#00cc00" : "#00ff00") : "#1a1a1a"
                    border.color: parent.enabled ? "#00ff00" : "#444444"
                    border.width: 2
                    radius: 4
                }
                
                contentItem: Label {
                    text: parent.text
                    color: parent.enabled ? "#000000" : "#666666"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                    font.pixelSize: 20
                }
            }
            
            // Bouton Stop
            Button {
                text: "⏹"
                enabled: currentFile !== ""
                implicitWidth: 50
                
                onClicked: {
                    stop()
                }
                
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? "#cc0000" : "#ff0000") : "#1a1a1a"
                    border.color: parent.enabled ? "#ff0000" : "#444444"
                    border.width: 1
                    radius: 4
                }
                
                contentItem: Label {
                    text: parent.text
                    color: parent.enabled ? "#ffffff" : "#666666"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                    font.pixelSize: 16
                }
            }
            
            // Bouton suivant rapide
            Button {
                text: "▶▶"
                enabled: currentFile !== ""
                implicitWidth: 50
                
                onClicked: {
                    var newPos = Math.min(duration, position + 10000) // Avance de 10 secondes
                    seek(newPos)
                }
                
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? "#444444" : "#2a2a2a") : "#1a1a1a"
                    border.color: parent.enabled ? "#00ff00" : "#444444"
                    border.width: 1
                    radius: 4
                }
                
                contentItem: Label {
                    text: parent.text
                    color: parent.enabled ? "#00ff00" : "#666666"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                    font.pixelSize: 16
                }
            }
            
            Item { Layout.fillWidth: true }
        }
        
        // Barre de progression
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            
            // Slider de position
            MouseArea {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                
                Rectangle {
                    anchors.fill: parent
                    color: "#1a1a1a"
                    radius: 4
                    border.color: "#444444"
                    border.width: 1
                    
                    // Barre de progression
                    Rectangle {
                        x: 0
                        y: 0
                        width: duration > 0 ? (position / duration) * parent.width : 0
                        height: parent.height
                        color: "#00ff0033"
                        radius: 4
                    }
                    
                    // Curseur
                    Rectangle {
                        x: duration > 0 ? (position / duration) * parent.width - 2 : 0
                        y: 0
                        width: 4
                        height: parent.height
                        color: "#00ff00"
                    }
                    
                    // Indicateur de position au survol
                    Label {
                        visible: parent.parent.containsMouse
                        x: parent.parent.mouseX
                        y: -25
                        text: {
                            if (duration > 0) {
                                var seekPos = (parent.parent.mouseX / parent.width) * duration
                                return formatTime(seekPos)
                            }
                            return "00:00"
                        }
                        color: "#ffaa00"
                        font.pixelSize: 10
                        
                        background: Rectangle {
                            color: "#000000"
                            border.color: "#ffaa00"
                            border.width: 1
                            radius: 2
                            anchors.fill: parent
                            anchors.margins: -3
                        }
                    }
                }
                
                hoverEnabled: true
                
                onClicked: {
                    if (duration > 0) {
                        var newPos = (mouseX / width) * duration
                        seek(Math.floor(newPos))
                    }
                }
            }
            
            // Informations de position
            RowLayout {
                Layout.fillWidth: true
                
                Label {
                    text: formatTime(position)
                    color: "#00ff00"
                    font.pixelSize: 14
                    font.bold: true
                }
                
                Label {
                    text: "/"
                    color: "#666666"
                    font.pixelSize: 12
                }
                
                Label {
                    text: formatTime(duration)
                    color: "#888888"
                    font.pixelSize: 14
                }
                
                Item { Layout.fillWidth: true }
            }
        }
    }
    
    // Fonctions utilitaires
    function formatTime(ms) {
        var totalSeconds = Math.floor(ms / 1000)
        var minutes = Math.floor(totalSeconds / 60)
        var seconds = totalSeconds % 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }
    
    // Mise à jour de l'état depuis PureData
    function updatePlaybackState(state) {
        playing = state.playing || false
        position = state.position || 0
        beat = state.beat || 0
        tempo = state.tempo || 120
        duration = state.duration || 0
        totalBeats = state.totalBeats || 0
        
        // Utiliser bar/beat du serveur si disponibles (sinon calcul fallback)
        if (state.bar !== undefined) {
            currentBar = state.bar
        } else if (timeSignatureNum > 0) {
            currentBar = Math.floor(beat / timeSignatureNum) + 1
        }
        
        if (state.beatInBar !== undefined) {
            currentBeat = state.beatInBar
        } else if (timeSignatureNum > 0) {
            currentBeat = Math.floor(beat % timeSignatureNum) + 1
        }
        
        if (state.timeSignature) {
            timeSignatureNum = state.timeSignature.numerator || 4
            timeSignatureDen = state.timeSignature.denominator || 4
        }
        
        if (state.file) {
            currentFile = state.file
        }
    }
    
    // Fonction appelée quand un fichier est chargé depuis la bibliothèque
    function onFileLoaded(path) {
        currentFile = path
        console.log("📁 Fichier chargé dans le lecteur:", path)
    }
    
    // Timer pour récupérer l'état de lecture depuis PureData
    Timer {
        interval: 100 // Mise à jour toutes les 100ms pour fluidité
        running: true
        repeat: true
        
        onTriggered: {
            // Polling de l'état de lecture
            var xhr = new XMLHttpRequest()
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                    try {
                        var state = JSON.parse(xhr.responseText)
                        updatePlaybackState(state)
                    } catch (e) {
                        // Ignorer les erreurs de parsing silencieusement
                    }
                }
            }
            xhr.open("GET", "http://localhost:8001/api/puredata/playback")
            xhr.send()
        }
    }
    
    // Gestion des signaux de transport uniquement
    // Le chargement de fichier est géré par CompositionsPage
    
    onPlay: function() {
        if (commandManager) {
            commandManager.sendMidiCommand({
                "type": "MIDI_TRANSPORT",
                "action": "play"
            })
        }
    }
    
    onPause: function() {
        if (commandManager) {
            commandManager.sendMidiCommand({
                "type": "MIDI_TRANSPORT",
                "action": "pause"
            })
        }
    }
    
    onStop: function() {
        if (commandManager) {
            commandManager.sendMidiCommand({
                "type": "MIDI_TRANSPORT",
                "action": "stop"
            })
        }
    }
    
    onSeek: function(pos) {
        if (commandManager) {
            commandManager.sendMidiCommand({
                "type": "MIDI_SEEK",
                "position": pos
            })
        }
    }
    
    onTempoChangeRequested: function(newTempo) {
        if (commandManager) {
            commandManager.sendMidiCommand({
                "type": "TEMPO_CHANGE",
                "tempo": newTempo,
                "smooth": true
            })
        }
    }
}

