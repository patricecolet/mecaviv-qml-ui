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
    property var midiFileManager: null
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
    
    // Fichiers disponibles
    property var midiFiles: []
    property int selectedFileIndex: -1
    
    // Signaux
    signal loadFile(string path)
    signal play()
    signal pause()
    signal stop()
    signal seek(int position)
    signal tempoChanged(int tempo)
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10
        
        // Titre
        Label {
            text: "🎵 Lecteur MIDI"
            font.pixelSize: 18
            font.bold: true
            color: "#00ff00"
        }
        
        // Sélection de fichier
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Label {
                text: "Fichier :"
                color: "#ffffff"
                font.pixelSize: 14
            }
            
            ComboBox {
                id: fileSelector
                Layout.fillWidth: true
                model: midiFiles
                textRole: "name"
                currentIndex: selectedFileIndex
                
                delegate: ItemDelegate {
                    width: fileSelector.width
                    contentItem: RowLayout {
                        spacing: 8
                        
                        Label {
                            text: modelData.category || "?"
                            color: "#ffaa00"
                            font.pixelSize: 10
                            font.bold: true
                            Layout.preferredWidth: 60
                        }
                        
                        Label {
                            text: modelData.name || "?"
                            color: "#ffffff"
                            font.pixelSize: 12
                            Layout.fillWidth: true
                        }
                    }
                    
                    background: Rectangle {
                        color: parent.hovered ? "#3a3a3a" : "transparent"
                    }
                }
                
                background: Rectangle {
                    color: "#1a1a1a"
                    border.color: fileSelector.activeFocus ? "#00ff00" : "#444444"
                    border.width: 1
                    radius: 4
                }
                
                contentItem: Label {
                    text: {
                        if (fileSelector.currentIndex >= 0 && midiFiles[fileSelector.currentIndex]) {
                            var file = midiFiles[fileSelector.currentIndex]
                            return file.category + "/" + file.name
                        }
                        return "Sélectionner un fichier..."
                    }
                    color: "#ffffff"
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                }
                
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && midiFiles[currentIndex]) {
                        selectedFileIndex = currentIndex
                    }
                }
            }
            
            Button {
                text: "📂 Charger"
                enabled: selectedFileIndex >= 0
                
                onClicked: {
                    if (selectedFileIndex >= 0 && midiFiles[selectedFileIndex]) {
                        var file = midiFiles[selectedFileIndex]
                        currentFile = file.path
                        loadFile(file.path)
                        console.log("📂 Chargement fichier:", file.path)
                    }
                }
                
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? "#00aa00" : "#00ff00") : "#444444"
                    radius: 4
                }
                
                contentItem: Label {
                    text: parent.text
                    color: parent.enabled ? "#000000" : "#888888"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                }
            }
        }
        
        // Fichier en cours
        Label {
            text: currentFile ? "▶ " + currentFile : "Aucun fichier chargé"
            color: currentFile ? "#00ff00" : "#888888"
            font.pixelSize: 12
            font.italic: true
            Layout.fillWidth: true
        }
        
        // Séparateur
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#444444"
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
            
            // Affichage signature temporelle
            Rectangle {
                Layout.preferredWidth: 70
                Layout.preferredHeight: 40
                color: "#1a1a1a"
                border.color: "#00ff00"
                border.width: 1
                radius: 4
                
                Label {
                    anchors.centerIn: parent
                    text: timeSignatureNum + "/" + timeSignatureDen
                    color: "#00ff00"
                    font.pixelSize: 18
                    font.bold: true
                }
            }
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
                
                Label {
                    text: "Beat: " + beat.toFixed(1) + " / " + totalBeats
                    color: "#ffaa00"
                    font.pixelSize: 12
                }
            }
        }
        
        // Séparateur
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#444444"
        }
        
        // Contrôle du tempo
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Label {
                text: "Tempo :"
                color: "#ffffff"
                font.pixelSize: 14
            }
            
            Button {
                text: "-10"
                implicitWidth: 50
                
                onClicked: {
                    var newTempo = Math.max(40, tempo - 10)
                    tempoChanged(newTempo)
                }
                
                background: Rectangle {
                    color: parent.pressed ? "#444444" : "#2a2a2a"
                    border.color: "#ffaa00"
                    border.width: 1
                    radius: 4
                }
                
                contentItem: Label {
                    text: parent.text
                    color: "#ffaa00"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            Rectangle {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 35
                color: "#1a1a1a"
                border.color: "#ffaa00"
                border.width: 2
                radius: 4
                
                Label {
                    anchors.centerIn: parent
                    text: tempo + " BPM"
                    color: "#ffaa00"
                    font.pixelSize: 16
                    font.bold: true
                }
            }
            
            Button {
                text: "+10"
                implicitWidth: 50
                
                onClicked: {
                    var newTempo = Math.min(240, tempo + 10)
                    tempoChanged(newTempo)
                }
                
                background: Rectangle {
                    color: parent.pressed ? "#444444" : "#2a2a2a"
                    border.color: "#ffaa00"
                    border.width: 1
                    radius: 4
                }
                
                contentItem: Label {
                    text: parent.text
                    color: "#ffaa00"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            Item { Layout.fillWidth: true }
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
        
        if (state.timeSignature) {
            timeSignatureNum = state.timeSignature.numerator || 4
            timeSignatureDen = state.timeSignature.denominator || 4
        }
        
        if (state.file) {
            currentFile = state.file
        }
    }
    
    // Charger la liste des fichiers MIDI
    function loadMidiFilesList(files) {
        midiFiles = files
        console.log("📁 Liste MIDI chargée:", files.length, "fichiers")
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
    
    // Connexion aux signaux
    Component.onCompleted: {
        // Demander la liste des fichiers MIDI au démarrage
        if (midiFileManager) {
            midiFileManager.requestFiles()
        }
    }
    
    // Gestion des signaux
    onLoadFile: function(path) {
        if (commandManager) {
            commandManager.sendMidiCommand({
                "type": "MIDI_FILE_LOAD",
                "path": path
            })
        }
    }
    
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
    
    onTempoChanged: function(newTempo) {
        if (commandManager) {
            commandManager.sendMidiCommand({
                "type": "TEMPO_CHANGE",
                "tempo": newTempo,
                "smooth": true
            })
        }
    }
}

