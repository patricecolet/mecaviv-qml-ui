import QtQuick 2.15
import QtQuick.Controls 2.15
import "../../config.js" as Config

Rectangle {
    id: root
    width: 400
    height: 300
    radius: 8
    color: "#1a1a1a"
    border.color: "#333"
    border.width: 1
    
    property var sirenStates: ({})
    // Superposition temps réel issue du flux MIDI binaire
    property var liveMidiStates: ({})
    property bool monitoringActive: true
    // Ping JSON des sirènes (clé: "siren1".."siren7", value: { pingOk: bool })
    property var sirenPings: ({})
    property string visualStyle: "minimal" // "minimal" ou "detailed"
    
    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8
        
        Row {
            spacing: 10
            Text {
                text: "🎵 État des Sirènes"
                color: "#00aaff"
                font.pixelSize: 12
                font.bold: true
            }
        }
        
        ScrollView {
            width: parent.width
            height: parent.height - 30
            clip: true
            
            Column {
                spacing: visualStyle === "detailed" ? 0 : 4
                width: parent.width
                
                Repeater {
                    model: 7 // 7 sirènes
                    
                    Rectangle {
                        width: parent.width - 20
                        height: 30
                        radius: 4
                        color: "#2a2a2a"
                        border.color: "#444"
                        border.width: 1
                        
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 15
                            
                            // Ping en tout début de ligne
                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: {
                                    var key = "siren" + (index + 1)
                                    var v = sirenPings ? sirenPings[key] : undefined
                                    var ok = false
                                    if (v === 1 || v === true || v === "1") {
                                        ok = true
                                    } else if (typeof v === 'object' && v && v.pingOk) {
                                        ok = true
                                    }
                                    return ok ? "#4CAF50" : "#FF5722"
                                }
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Numéro sirène
                            Text {
                                text: "S" + (index + 1)
                                color: "#00aaff"
                                font.pixelSize: 12
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            // Pitch
                            Row {
                                spacing: 4
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    text: "♪"
                                    color: "#888"
                                    font.pixelSize: 12
                                }
                                Text {
                                    text: getSirenValue(index, "pitch", "60")
                                    color: "#4CAF50"
                                    font.pixelSize: 12
                                }
                            }
                            
                            // Velocity
                            Row {
                                spacing: 4
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    text: "🔊"
                                    color: "#888"
                                    font.pixelSize: 12
                                }
                                Text {
                                    text: getSirenValue(index, "velocity", "64")
                                    color: "#FF9800"
                                    font.pixelSize: 12
                                }
                            }
                            
                            // Controllers (si style détaillé)
                            Row {
                                spacing: 8
                                visible: visualStyle === "detailed"
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Repeater {
                                    model: Config.controllers.order
                                    
                                    Row {
                                        spacing: 2
                                        Text {
                                            text: getControllerDisplayName(modelData)
                                            color: "#666"
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: getSirenControllerValue(parent.parent.parent.index, index)
                                            color: Config.controllers.definitions[modelData] ? Config.controllers.definitions[modelData].color : "#9C27B0"
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                            }
                            
                            // (Indicateur activité par vélocité retiré)
                        }
                    }
                }
            }
        }
    }
    
    function getSirenValue(sirenIndex, property, defaultValue) {
        var sirenKey = "siren" + (sirenIndex + 1)
        // Priorité au flux MIDI live si renseigné
        if (liveMidiStates[sirenKey] && liveMidiStates[sirenKey][property] !== undefined) {
            return liveMidiStates[sirenKey][property].toString()
        }
        if (sirenStates[sirenKey] && sirenStates[sirenKey][property] !== undefined) {
            return sirenStates[sirenKey][property].toString()
        }
        return defaultValue
    }
    
    function getSirenControllerValue(sirenIndex, controllerIndex) {
        var sirenKey = "siren" + (sirenIndex + 1)
        if (sirenStates[sirenKey] && sirenStates[sirenKey].controllers) {
            return sirenStates[sirenKey].controllers[controllerIndex] || "0"
        }
        return "0"
    }
    
    // getSirenActivity retiré (plus utilisé)
    
    function getControllerDisplayName(controllerName) {
        if (!Config.controllers.definitions[controllerName]) {
            return controllerName
        }
        
        var label = Config.controllers.definitions[controllerName].label
        
        // Ajouter des préfixes pour identifier les catégories
        if (controllerName.startsWith("vibrato")) {
            return "V:" + label
        } else if (controllerName.startsWith("tremolo")) {
            return "T:" + label
        } else {
            return label
        }
    }
    
    // Routage des paquets MIDI binaires: met à jour un overlay live
    // Met à jour pitch/velocity pour une sirène indexée par le canal (0..6)
    function applyMidi(note, velocity, bend, channel) {
        var sirenIndex = (channel !== undefined ? channel : 0) % 7
        var key = "siren" + (sirenIndex + 1)

        var updated = {}
        for (var k in liveMidiStates) {
            updated[k] = liveMidiStates[k]
        }

        var prev = updated[key] || { pitch: "0", velocity: "0", controllers: [] }
        updated[key] = {
            pitch: (note !== undefined ? note : prev.pitch).toString(),
            velocity: (velocity !== undefined ? velocity : prev.velocity).toString(),
            controllers: prev.controllers
        }

        liveMidiStates = updated

        // Debug retiré (bruit)
    }
    
    // Retirer le Timer de simulation
    /*
    Timer {
        interval: 100
        running: monitoringActive
        repeat: true
        onTriggered: {
            var newStates = {}
            for (var i = 1; i <= 7; i++) {
                newStates["siren" + i] = {
                    pitch: 40 + Math.floor(Math.random() * 80),
                    velocity: Math.floor(Math.random() * 127),
                    controllers: [
                        Math.floor(Math.random() * 200) - 100,
                        Math.floor(Math.random() * 200) - 100,
                        Math.floor(Math.random() * 200) - 100,
                        Math.floor(Math.random() * 200) - 100
                    ]
                }
            }
            root.sirenStates = newStates
        }
    }
    */
} 