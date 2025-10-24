import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components" as Components

/**
 * MidiPage - Page de contrôle des fichiers MIDI et lecture
 */
Rectangle {
    id: root
    
    color: "#1a1a1a"
    
    // Références aux managers
    property var midiFileManager: null
    property var commandManager: null
    property var consoleController: null
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        
        // Titre de la page
        Label {
            text: "🎵 Contrôle MIDI"
            font.pixelSize: 24
            font.bold: true
            color: "#00ff00"
        }
        
        // Lecteur MIDI
        Components.MidiPlayer {
            id: midiPlayer
            Layout.fillWidth: true
            Layout.preferredHeight: 300
            
            midiFileManager: root.midiFileManager
            commandManager: root.commandManager
            
            onLoadFile: function(path) {
                // Page MIDI - Chargement fichier
            }
        }
        
        // Espace flexible
        Item {
            Layout.fillHeight: true
        }
        
        // Informations système
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: "#2a2a2a"
            radius: 8
            border.color: "#444444"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10
                
                Label {
                    text: "📊 Informations Système"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#ffaa00"
                }
                
                GridLayout {
                    columns: 2
                    columnSpacing: 20
                    rowSpacing: 5
                    Layout.fillWidth: true
                    
                    Label { text: "Repository MIDI :"; color: "#888888"; font.pixelSize: 11 }
                    Label { 
                        text: "../mecaviv/compositions"
                        color: "#00ff00"
                        font.pixelSize: 11
                        font.family: "monospace"
                    }
                    
                    Label { text: "Fichiers disponibles :"; color: "#888888"; font.pixelSize: 11 }
                    Label { 
                        text: midiPlayer.midiFiles.length + " fichiers"
                        color: "#00ff00" 
                        font.pixelSize: 11
                        font.bold: true
                    }
                    
                    Label { text: "WebSocket PureData :"; color: "#888888"; font.pixelSize: 11 }
                    Label { 
                        text: "127.0.0.1:10002"
                        color: "#00ff00"
                        font.pixelSize: 11
                        font.family: "monospace"
                    }
                }
            }
        }
    }
    
    // Connexion aux managers
    Connections {
        target: midiFileManager
        
        function onFilesLoaded(files) {
            midiPlayer.loadMidiFilesList(files)
        }
    }
}

