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
    property real currentHz: parent && parent.currentHz !== undefined ? parent.currentHz : 440.0
    property real currentRpm: parent && parent.currentRpm !== undefined ? parent.currentRpm : 0
    // Ambitus transmis par le Loader (si présent)
    property int ambitusMin: parent && parent.ambitusMin !== undefined ? parent.ambitusMin : 48
    property int ambitusMax: parent && parent.ambitusMax !== undefined ? parent.ambitusMax : 72
    // État de synchronisation
    property bool pupitreSynced: parent ? (parent.pupitreSynced || false) : false
    property var consoleController: parent ? parent.consoleController : null
    property bool autoVolantActive: false
    property bool autoPadActive: false
    property bool autoSliderActive: false
    property bool autoJoystickActive: false
    
    
    height: 80
    width: parent.width
    //color: pupitre && pupitre.status === "connected" ? "#2a4a2a" : "#2a2a2a"
    color: overviewRow.pupitreStatus === "connected" ? "#2a4a2a" : "#2a2a2a"
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
                
                // Indicateurs: connexion et synchronisation
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    
                    // Indicateur de statut (diode connexion)
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
                    
                    // Indicateur de synchronisation (diode sync) - en dessous du voyant connexion
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: overviewRow.pupitreSynced ? "#00ff00" : "#666666"
                        
                        ToolTip {
                            visible: syncMouseArea.containsMouse
                            text: overviewRow.pupitreSynced ? "Synchronisé" : "Non synchronisé"
                            delay: 500
                        }
                        
                        MouseArea {
                            id: syncMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
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
                minNote: overviewRow.ambitusMin
                maxNote: overviewRow.ambitusMax
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
                            text: String(Math.round(overviewRow.currentRpm))
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
                            text:  String(Math.round(overviewRow.currentHz))
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
                            text:  String(Math.round(overviewRow.currentNote))
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
        
        // Rectangle 4: Boutons Auto*
        Rectangle {
            Layout.minimumWidth: 140
            Layout.preferredWidth: 180
            Layout.maximumWidth: 220
            Layout.fillHeight: true
            color: "#1a1a1a"
            radius: 4
            border.color: "#333333"
            border.width: 1
            
            Flow {
                anchors.centerIn: parent
                width: parent.width - 16
                spacing: 8
                
                Repeater {
                    model: [
                        { label: "AutoVolant", device: "volant", prop: "autoVolantActive" },
                        { label: "AutoPad", device: "pad", prop: "autoPadActive" },
                        { label: "AutoSlider", device: "slider", prop: "autoSliderActive" },
                        { label: "AutoJoystick", device: "joystick", prop: "autoJoystickActive" }
                    ]
                    
                    delegate: Button {
                        width: (parent.width / 2) - 10
                        height: 26
                        checkable: true
                        checked: overviewRow[modelData.prop]
                        text: modelData.label
                        font.pixelSize: 10
                        onToggled: {
                            overviewRow[modelData.prop] = checked
                            if (overviewRow.consoleController && overviewRow.pupitreId) {
                                overviewRow.consoleController.setAutonomyMode(overviewRow.pupitreId, modelData.device, checked)
                            }
                        }
                    }
                }
            }
        }
    }
}