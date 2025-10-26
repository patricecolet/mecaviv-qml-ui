import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: overviewRow
    
    // Propriétés directes au lieu de l'objet pupitre
    property string pupitreId: parent ? parent.pupitreId : ""
    property string pupitreStatus: parent ? parent.pupitreStatus : "disconnected"
    property string pupitreName: parent ? parent.pupitreName : ""
    property string pupitreHost: parent ? parent.pupitreHost : ""
    property real currentNote: parent ? parent.currentNote : 60
    
Component.onCompleted: {
console.log("🔍 OverviewRow loaded for", pupitreId, "status =", pupitreStatus, "currentNote =", currentNote)
}
    
    height: 80
    width: parent.width
    //color: pupitre && pupitre.status === "connected" ? "#2a4a2a" : "#2a2a2a"
    color: {
        console.log("🔍 OverviewRow color: pupitreId =", pupitreId, "status =", pupitreStatus)
        return overviewRow.pupitreStatus === "connected" ? "#2a4a2a" : "#2a2a2a"
    }
    border.color: overviewRow.pupitreStatus === "connected" ? "#00ff00" : "#555555"
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
                
                // Nom du pupitre (P1, P2, etc.)
                Text {
                    text: overviewRow.pupitreId || "P?"
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
                        switch(overviewRow.pupitreStatus) {
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
                minNote: 48
                maxNote: 72
                currentNote: overviewRow.currentNote
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
                            text: "0"
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
                            text: "440.0"
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
                            text: "60"
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
                            text: "OFF"
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
                        // Configuration pupitre
                    }
                }
                
                Button {
                    text: "Vue"
                    width: 80
                    height: 25
                    font.pixelSize: 10
                    onClicked: {
                        // Vue locale pupitre
                    }
                }
            }
        }
    }
}