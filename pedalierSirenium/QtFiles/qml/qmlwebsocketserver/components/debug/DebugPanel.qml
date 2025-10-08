import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../core"
import "../monitoring"
import "../controls"

Rectangle {
    id: panelBg
    property var settings
    property var logger
    property int logHistoryVersion: 0
    property var filteredHistory: []
    property var webSocketController
    property var midiMonitorController  // Référence vers le contrôleur MIDI
    
    // Nouvelles propriétés pour monitoring
    property string visualStyle: "minimal"
    property bool performanceMonitoring: true
    
    // Données reçues du serveur
    property var currentMonitoringData: ({})
    property var currentSystemInfo: ({})
    
    function updateFilteredHistory(force) {
        if (logHistoryBg.historyPaused && !force) return;
        if (!logger || !logger.logHistory) {
            filteredHistory = [];
            return;
        }
        // Table de correspondance niveau texte -> valeur numérique
        var levelMap = {"OFF":0, "ERROR":1, "WARN":2, "INFO":3, "DEBUG":4, "TRACE":5};
        filteredHistory = logger.logHistory.filter(function(msg) {
            // Extraire la catégorie et le niveau du message
            // Format attendu : [HH:MM:SS] [ICÔNE] [CATEGORIE] LEVEL: ...
            let match = msg.match(/\[.*?\] [^\[]* \[(.*?)\] (\w+):/);
            let cat = null;
            let msgLevel = null;
            if (match) {
                cat = match[1];
                msgLevel = match[2];
            }
            if (!cat || !msgLevel) return true; // Si on ne trouve pas, on affiche
            // Vérifier le niveau actif pour cette catégorie
            let catLevel = 0;
            switch(cat) {
                case "WEBSOCKET": catLevel = logger.levelWebSocket; break;
                case "CLOCK": catLevel = logger.levelClock; break;
                case "VOICE": catLevel = logger.levelVoice; break;
                case "ANIMATION": catLevel = logger.levelAnimation; break;
                case "BATCH": catLevel = logger.levelBatch; break;
                case "RECORDING": catLevel = logger.levelRecording; break;
                case "PRESET": catLevel = logger.levelPreset; break;
                case "KNOB": catLevel = logger.levelKnob; break;
                case "ROUTER": catLevel = logger.levelRouter; break;
                case "PARSER": catLevel = logger.levelParser; break;
                case "INIT": catLevel = logger.levelInit; break;
                case "SCENES": catLevel = logger.levelScenes; break;
                case "MIDI": catLevel = logger.levelMidi; break;
                default: catLevel = 1; // Afficher par défaut
            }
            let msgLevelNum = levelMap[msgLevel] !== undefined ? levelMap[msgLevel] : 1;
            return catLevel > 0 && msgLevelNum <= catLevel;
        });
    }
    
    // Mettre à jour le filtrage à chaque changement d'historique ou de niveau
    Connections {
        target: logger
        function onHistoryChanged() { updateFilteredHistory(); }
    }
    
    // Réagir aux changements de niveaux (optimisé)
    onLogHistoryVersionChanged: updateFilteredHistory()
    anchors.fill: parent
    color: "#222"
    border.color: "#444"
    z: 1000
    signal closeRequested()
    
    // Overlay : bouton fermer
    MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        width: 32
        height: 32
        z: 2000
        cursorShape: Qt.PointingHandCursor
        onClicked: panelBg.closeRequested()
        Image {
            source: "qrc:/qml/icons/close.png"
            anchors.centerIn: parent
            width: 18
            height: 18
            fillMode: Image.PreserveAspectFit
        }
        ToolTip.text: "Fermer le panneau de debug"
    }
    
    // En-tête avec onglets
    Row {
        id: tabRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        height: 40
        spacing: 5
        z: 1001

        Button {
            id: debugTab
            width: 100
            height: 30
            checked: stackLayout.currentIndex === 0
            onClicked: stackLayout.currentIndex = 0
            background: Rectangle {
                color: parent.checked ? "#2a2a2a" : "#1a1a1a"
                border.color: "#444"
                radius: 4
            }
            contentItem: Row {
                anchors.centerIn: parent
                spacing: 5
                Image {
                    source: "qrc:/qml/icons/bug.png"
                    width: 16
                    height: 16
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Debug"
                    color: "white"
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Button {
            id: monitoringTab
            width: 120
            height: 30
            checked: stackLayout.currentIndex === 1
            onClicked: stackLayout.currentIndex = 1
            background: Rectangle {
                color: parent.checked ? "#2a2a2a" : "#1a1a1a"
                border.color: "#444"
                radius: 4
            }
            contentItem: Row {
                anchors.centerIn: parent
                spacing: 5
                Image {
                    source: "qrc:/qml/icons/chart.png"
                    width: 16
                    height: 16
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Monitoring"
                    color: "white"
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Button {
            id: performanceTab
            width: 130
            height: 30
            checked: stackLayout.currentIndex === 2
            onClicked: stackLayout.currentIndex = 2
            background: Rectangle {
                color: parent.checked ? "#2a2a2a" : "#1a1a1a"
                border.color: "#444"
                radius: 4
            }
            contentItem: Row {
                anchors.centerIn: parent
                spacing: 5
                Image {
                    source: "qrc:/qml/icons/lightning.png"
                    width: 16
                    height: 16
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Performance"
                    color: "white"
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Onglet MIDI retiré (sélection de ports obsolète en mode WASM)

        // Onglet de test WebMIDI retiré (obsolète côté QML/WASM)
    }
    
    // Contenu principal avec StackLayout
    StackLayout {
        id: stackLayout
        anchors.top: tabRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        currentIndex: 0

        // Section 1: Debug classique (ancien système)
        Column {
            spacing: 0
            
            // Titre et boutons rapides en haut
            Rectangle {
                width: parent.width
                height: 60
                color: "transparent"
                Row {
                    anchors.centerIn: parent
                    spacing: 20
                    Text {
                        text: "Contrôles de Debug"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 18
                    }
                    Item { width: 20; height: 1 } // Espace
                    Button {
                        text: "All OFF"
                        width: 80
                        height: 32
                        onClicked: {
                            if (logger) logger.setAllCategories(0);
                            updateFilteredHistory(true);
                        }
                    }
                    Button {
                        text: "All INFO"
                        width: 80
                        height: 32
                        onClicked: {
                            if (logger) logger.setAllCategories(3);
                            updateFilteredHistory(true);
                        }
                    }
                    Button {
                        text: "All DEBUG"
                        width: 90
                        height: 32
                        onClicked: {
                            if (logger) logger.setAllCategories(4);
                            updateFilteredHistory(true);
                        }
                    }
                }
            }
            
            Rectangle { width: parent.width; height: 1; color: "#444" }
            
            // Catégories de logs (scrollables si besoin)
            ScrollView {
                id: categoriesScroll
                width: parent.width
                height: Math.max(180, parent.height * 0.4)
                clip: true
                Column {
                    width: parent.width
                    spacing: 8
                    CategoryRow { name: "WEBSOCKET"; emoji: "🌐"; iconName: "network.png"; level: logger ? logger.levelWebSocket : 0; onLevelChangeRequested: function(newLevel) { if (logger) logger.levelWebSocket = newLevel; updateFilteredHistory(true); } }
                    CategoryRow { name: "CLOCK"; emoji: "⏰"; iconName: "clock.png"; level: logger ? logger.levelClock : 0; onLevelChangeRequested: function(newLevel) { if (logger) logger.levelClock = newLevel; updateFilteredHistory(true); } }
                    CategoryRow { name: "VOICE"; emoji: "🎤"; iconName: "mic.png"; level: logger ? logger.levelVoice : 0; onLevelChangeRequested: function(newLevel) { if (logger) logger.levelVoice = newLevel; updateFilteredHistory(true); } }
                    CategoryRow { name: "ANIMATION"; emoji: "🎬"; iconName: "animation.png"; level: logger ? logger.levelAnimation : 0; onLevelChangeRequested: function(newLevel) { if (logger) logger.levelAnimation = newLevel; updateFilteredHistory(true); } }
                    CategoryRow { name: "BATCH"; emoji: "📦"; iconName: "package.png"; level: logger ? logger.levelBatch : 0; onLevelChangeRequested: function(newLevel) { if (logger) logger.levelBatch = newLevel; updateFilteredHistory(true); } }
                    CategoryRow { name: "RECORDING"; emoji: "🔴"; iconName: "record.png"; level: logger ? logger.levelRecording : 0; onLevelChangeRequested: function(newLevel) { if (logger) logger.levelRecording = newLevel; updateFilteredHistory(true); } }
                    CategoryRow { name: "PRESET"; emoji: "💾"; iconName: "save.png"; level: logger ? logger.levelPreset : 0; onLevelChangeRequested: function(newLevel) { if (logger) logger.levelPreset = newLevel; updateFilteredHistory(true); } }
                    CategoryRow { name: "KNOB"; emoji: "🎛️"; iconName: "knob.png"; level: logger ? logger.levelKnob : 0; onLevelChangeRequested: function(newLevel) { if (logger) logger.levelKnob = newLevel; updateFilteredHistory(true); } }
                    CategoryRow { name: "ROUTER"; emoji: "🔀"; iconName: "switch.png"; level: logger ? logger.levelRouter : 0; onLevelChangeRequested: function(newLevel) { if (logger) logger.levelRouter = newLevel; updateFilteredHistory(true); } }
                    CategoryRow { name: "PARSER"; emoji: "📊"; iconName: "parse.png"; level: logger ? logger.levelParser : 0; onLevelChangeRequested: function(newLevel) { if (logger) logger.levelParser = newLevel; updateFilteredHistory(true); } }
                    CategoryRow { name: "INIT"; emoji: "🚀"; iconName: "rocket.png"; level: logger ? logger.levelInit : 0; onLevelChangeRequested: function(newLevel) { if (logger) logger.levelInit = newLevel; updateFilteredHistory(true); } }
                    CategoryRow { name: "SCENES"; emoji: "🎭"; iconName: "theater.png"; level: logger ? logger.levelScenes : 0; onLevelChangeRequested: function(newLevel) { if (logger) logger.levelScenes = newLevel; updateFilteredHistory(true); } }
                    CategoryRow { name: "MIDI"; emoji: "🎛️"; iconName: "music.png"; level: logger ? logger.levelMidi : 0; onLevelChangeRequested: function(newLevel) { if (logger) logger.levelMidi = newLevel; updateFilteredHistory(true); } }
                }
            }
            
            Rectangle { width: parent.width; height: 1; color: "#444" }
            
            // Historique des logs en bas
            Rectangle {
                id: logHistoryBg
                height: Math.max(140, parent.height * 0.35)
                width: parent.width
                color: "#181818"
                border.color: "#333"
                z: 1001
                property bool shouldAutoScroll: true
                property bool historyPaused: false
                
                // Row pour les boutons pause/play et poubelle
                Row {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 8
                    
                    // Bouton pause/play à gauche
                    MouseArea {
                        width: 32
                        height: 32
                        z: 1002
                        cursorShape: Qt.PointingHandCursor
                        onClicked: logHistoryBg.historyPaused = !logHistoryBg.historyPaused
                                            Image {
                        source: logHistoryBg.historyPaused ? "qrc:/qml/icons/play.png" : "qrc:/qml/icons/pause.png"
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        fillMode: Image.PreserveAspectFit
                    }
                        ToolTip.text: logHistoryBg.historyPaused ? "Reprendre l'affichage des logs" : "Mettre en pause l'affichage des logs"
                    }
                    
                    // Bouton poubelle à droite
                    MouseArea {
                        width: 32
                        height: 32
                        z: 1002
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (logger) logger.clearHistory();
                                            Image {
                        source: "qrc:/qml/icons/trash.png"
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        fillMode: Image.PreserveAspectFit
                    }
                        ToolTip.text: "Effacer l'historique des logs"
                    }
                }
                
                ScrollView {
                    id: logScroll
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 56
                    anchors.margins: 20
                    TextArea {
                        id: logTextArea
                        text: filteredHistory.slice().reverse().join("\n")
                        readOnly: true
                        wrapMode: TextArea.Wrap
                        font.family: "monospace"
                        font.pixelSize: 13
                        color: "#fff"
                        background: null
                    }
                }
            }
        }

        // Section 2: Monitoring Controls
        Rectangle {
            color: "transparent"
            
            Column {
                anchors.fill: parent
                spacing: 15

                // Contrôles de monitoring
                Rectangle {
                    width: parent.width
                    height: 100
                    color: "#2a2a2a"
                    radius: 8
                    border.color: "#444"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 10

                        Row {
                            spacing: 8
                            Image {
                                source: "qrc:/qml/icons/settings.png"
                                width: 14
                                height: 14
                                fillMode: Image.PreserveAspectFit
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Contrôles de Monitoring"
                                color: "#00aaff"
                                font.pixelSize: 14
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: 5
                            Text {
                                text: "Style:"
                                color: "#888"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            ComboBox {
                                model: ["minimal", "detailed"]
                                currentIndex: visualStyle === "detailed" ? 1 : 0
                                onCurrentTextChanged: {
                                    visualStyle = currentText
                                    sirenMonitor.visualStyle = currentText
                                }
                            }
                            ComboBox {
                                id: frequencyCombo
                                model: [
                                    { text: "100ms", value: 100 },
                                    { text: "250ms", value: 250 },
                                    { text: "500ms", value: 500 },
                                    { text: "1s", value: 1000 }
                                ]
                                textRole: "text"
                                valueRole: "value"
                                currentIndex: 0
                            }
                        }
                    }
                }
                
                // Monitoring des sirènes
                SirenStateMonitor {
                    id: sirenMonitor
                    width: parent.width
                    monitoringActive: true
                    visualStyle: panelBg.visualStyle
                    sirenStates: currentMonitoringData.sirenStates || ({})
                    sirenPings: currentMonitoringData.sirenPings || ({})
                }
                
                // (Connexion MIDI déplacée au niveau racine pour être toujours active)
            }
        }

        // Section 3: Performance & Système
        Rectangle {
            color: "transparent"
            
            Column {
                anchors.fill: parent
                spacing: 15

                                        Row {
                            spacing: 8
                            Image {
                                source: "qrc:/qml/icons/settings.png"
                                width: 14
                                height: 14
                                fillMode: Image.PreserveAspectFit
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Performance & Système"
                                color: "#00aaff"
                                font.pixelSize: 14
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                // Température CPU
                TemperatureMonitor {
                    id: tempMonitor
                    anchors.horizontalCenter: parent.horizontalCenter
                    temperature: currentSystemInfo.temperature || 0
                }

                // Performance générale
                PerformanceMonitor {
                    id: perfMonitor
                    anchors.horizontalCenter: parent.horizontalCenter
                    fps: currentMonitoringData.performance ? currentMonitoringData.performance.fps || 60 : 60
                    cpuUsage: currentSystemInfo.cpu || 0
                    memoryUsage: currentSystemInfo.memory || 0
                    wsMessages: webSocketController ? webSocketController.wsMessagesPerSecond : 0
                }

                // Contrôles performance
                Rectangle {
                    width: parent.width
                    height: 80
                    color: "#2a2a2a"
                    radius: 8
                    border.color: "#444"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 10

                        Row {
                            spacing: 8
                            Image {
                                source: "qrc:/qml/icons/settings.png"
                                width: 12
                                height: 12
                                fillMode: Image.PreserveAspectFit
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Options Performance"
                                color: "#888"
                                font.pixelSize: 12
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: 20

                            CheckBox {
                                text: "Monitoring performance"
                                checked: performanceMonitoring
                                onCheckedChanged: {
                                    performanceMonitoring = checked
                                    // Activer/désactiver les timers de performance
                                }
                            }

                            Button {
                                text: "Refresh système"
                                onClicked: {
                                    if (systemInfoReader) {
                                        systemInfoReader.requestSystemInfo()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Section 4 retirée (Contrôle MIDI / sélection de ports) – obsolète

        // Section 5 retirée (Test Web MIDI API) – non pertinente en QML/WASM
    }

    // SystemInfoReader pour lire les logs système
SystemInfoReader {
    id: systemInfoReader
    logger: panelBg.logger
    
    onSystemInfoReceived: function(data) {
        //console.log("�� DebugPanel: systemInfoReceived appelé avec:", JSON.stringify(data))
        currentSystemInfo = data
        //console.log("🎯 DebugPanel: currentSystemInfo mis à jour:", JSON.stringify(currentSystemInfo))
        
        // Forcer la mise à jour des composants
        tempMonitor.temperature = data.temperature || 0
        perfMonitor.cpuUsage = data.cpu || 0
        perfMonitor.memoryUsage = data.memory || 0
        
        //console.log("�� DebugPanel: Composants mis à jour - Temp:", tempMonitor.temperature, "CPU:", perfMonitor.cpuUsage, "RAM:", perfMonitor.memoryUsage)
    }
}
    
    // Connexions avec WebSocket
    Connections {
        target: webSocketController
        function onMonitoringDataReceived(data) {
            currentMonitoringData = data
        }
    }

    // Connexion MIDI -> SirenStateMonitor (toujours active)
    Connections {
        target: panelBg.midiMonitorController
        function onMidiDataChanged(note, velocity, bend, channel) {
            if (panelBg.logger) panelBg.logger.trace("MIDI", "onMidiDataChanged", note, velocity, bend, channel)
            if (sirenMonitor && typeof sirenMonitor.applyMidi === 'function') {
                sirenMonitor.applyMidi(note, velocity, bend, channel)
            }
        }
    }
}
