import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: overviewRow
    
    property var pupitre: null
    
    height: 80
    width: parent.width
    color: pupitre && pupitre.status === "connected" ? "#2a4a2a" : "#2a2a2a"
    border.color: pupitre && pupitre.status === "connected" ? "#00ff00" : "#555555"
    border.width: 2
    radius: 8
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8
        
        // Rectangle 1: Nom, état connexion
        Rectangle {
            Layout.minimumWidth: 60
            Layout.preferredWidth: 80
            Layout.maximumWidth: 100
            Layout.fillHeight: true
            color: "#1a1a1a"
            radius: 4
            border.color: "#333333"
            border.width: 1
            
            Column {
                anchors.centerIn: parent
                spacing: 8
                
                // Nom de la sirène (S1, S2, etc.)
                Text {
                    text: "S" + (pupitre ? pupitre.id : "?")
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                // Indicateur de statut (diode)
                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: {
                        if (!pupitre) return "#666666"
                        switch(pupitre.status) {
                            case "connected": return "#00ff00"
                            case "connecting": return "#ffff00"
                            case "error": return "#ff0000"
                            default: return "#666666"
                        }
                    }
                }
                
            }
        }
        
        // Rectangle 2: Ambitus (s'adapte à la largeur disponible)
        Rectangle {
            Layout.minimumWidth: 200
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1a1a1a"
            radius: 4
            border.color: "#333333"
            border.width: 1
            
            AmbitusBar {
                anchors.centerIn: parent
                width: parent.width - 16
                height: 30
                minNote: (pupitre && pupitre.ambitus) ? pupitre.ambitus.min : 48
                maxNote: (pupitre && pupitre.ambitus) ? pupitre.ambitus.max : 72
                currentNote: (pupitre && pupitre.midiNote !== undefined) ? pupitre.midiNote : 60
            }
        }
        
        // Rectangle 3: RPM, Fréquence, Note MIDI
        Rectangle {
            Layout.minimumWidth: 75
            Layout.preferredWidth: 100
            Layout.maximumWidth: 125
            Layout.fillHeight: true
            color: "#1a1a1a"
            radius: 4
            border.color: "#333333"
            border.width: 1
            
            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6
                
                // RPM et Fréquence
                Row {
                    width: parent.width
                    spacing: 15
                    
                    Column {
                        spacing: 2
                        Text {
                            text: "RPM"
                            color: "#cccccc"
                            font.pixelSize: 9
                        }
                        Text {
                            text: (pupitre && pupitre.motorSpeed !== undefined) ? pupitre.motorSpeed : 0
                            color: "#ffffff"
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                    
                    Column {
                        spacing: 2
                        Text {
                            text: "Hz"
                            color: "#cccccc"
                            font.pixelSize: 9
                        }
                        Text {
                            text: (pupitre && pupitre.frequency !== undefined) ? pupitre.frequency.toFixed(1) : "440.0"
                            color: "#ffffff"
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                }
                
                // Note MIDI et Mode Fretté
                Row {
                    width: parent.width
                    spacing: 15
                    
                    Column {
                        spacing: 2
                        Text {
                            text: "MIDI"
                            color: "#cccccc"
                            font.pixelSize: 9
                        }
                        Text {
                            text: (pupitre && pupitre.midiNote !== undefined) ? pupitre.midiNote : 60
                            color: "#ffffff"
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                    
                    Column {
                        spacing: 2
                        Text {
                            text: "Fretté"
                            color: "#cccccc"
                            font.pixelSize: 9
                        }
                        Text {
                            text: (pupitre && pupitre.frettedMode) ? "ON" : "OFF"
                            color: "#ffffff"
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                }
            }
        }
        
        // Rectangle 4: Boutons Config et Vue Locale
        Rectangle {
            Layout.minimumWidth: 80
            Layout.preferredWidth: 100
            Layout.maximumWidth: 120
            Layout.fillHeight: true
            color: "#1a1a1a"
            radius: 4
            border.color: "#333333"
            border.width: 1
            
            Column {
                anchors.centerIn: parent
                spacing: 8
                
                Button {
                    text: "Config"
                    width: 80
                    height: 25
                    font.pixelSize: 10
                    onClicked: {
                        console.log("Configuration pupitre", pupitre ? pupitre.id : "?")
                    }
                }
                
                Button {
                    text: "Vue"
                    width: 80
                    height: 25
                    font.pixelSize: 10
                    onClicked: {
                        console.log("Vue locale pupitre", pupitre ? pupitre.id : "?")
                    }
                }
            }
        }
    }
}