import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import "../controllers"
import "../components"

Rectangle {
    id: root
    color: "#1a1a1a"
    
    // Propriété du contrôleur console (injectée depuis Main.qml)
    property var consoleController: null
    
    // Gestionnaire de fichiers MIDI
    MidiFileManager {
        id: midiFileManager
        websocketManager: consoleController ? consoleController.websocketManager : null
        
        onFilesLoaded: {
            // Fichiers MIDI chargés
        }
        
        onLoadError: function(errorMessage) {
            errorText.text = errorMessage
            errorText.visible = true
        }
        
        onFileSelected: function(filePath) {
            statusText.text = "📁 Chargement: " + filePath
            statusText.color = "#00ff00"
            // Mettre à jour le lecteur MIDI
            midiPlayer.currentFile = filePath
        }
    }
    
    Component.onCompleted: {
        midiFileManager.loadMidiFiles()
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15
        
        // Lecteur MIDI avec contrôles de transport
        MidiPlayer {
            id: midiPlayer
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            
            commandManager: consoleController ? consoleController.commandManager : null
        }
        
        // Séparateur
        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: "#00ff00"
            opacity: 0.3
        }
        
        // En-tête
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: "#2a2a2a"
            radius: 8
            border.color: "#555555"
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20
                
                Text {
                    text: "🎵 Bibliothèque MIDI"
                    color: "#ffffff"
                    font.pixelSize: 18
                    font.bold: true
                }
                
                Item { Layout.fillWidth: true }
                
                // Bouton rafraîchir
                Button {
                    text: "🔄 Rafraîchir"
                    onClicked: midiFileManager.loadMidiFiles()
                    enabled: !midiFileManager.loading
                }
                
                // Indicateur de chargement
                Text {
                    text: "⏳ Chargement..."
                    color: "#ffaa00"
                    font.pixelSize: 14
                    visible: midiFileManager.loading
                }
            }
        }
        
        // Message d'erreur
        Rectangle {
            id: errorText
            Layout.fillWidth: true
            height: 40
            color: "#4a1a1a"
            radius: 4
            border.color: "#ff0000"
            border.width: 1
            visible: false
            
            property alias text: errorLabel.text
            
            Text {
                id: errorLabel
                anchors.centerIn: parent
                color: "#ff6666"
                font.pixelSize: 14
            }
        }
        
        // Barre de statut
        Rectangle {
            id: statusText
            Layout.fillWidth: true
            height: 35
            color: "#2a2a2a"
            radius: 4
            visible: text !== ""
            
            property alias text: statusLabel.text
            property alias color: statusLabel.color
            
            Text {
                id: statusLabel
                anchors.centerIn: parent
                font.pixelSize: 13
            }
        }
        
        // Contenu principal (Catégories + Fichiers)
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0a0a0a"
            radius: 8
            border.color: "#555555"
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 1
                spacing: 0
                
                // Liste des catégories (gauche)
                Rectangle {
                    Layout.preferredWidth: 280
                    Layout.fillHeight: true
                    color: "#1a1a1a"
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        // En-tête catégories
                        Rectangle {
                            Layout.fillWidth: true
                            height: 50
                            color: "#2a2a2a"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "📂 Catégories"
                                color: "#ffffff"
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }
                        
                        // Liste catégories
                        ListView {
                            id: categoryListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            model: midiFileManager.categories
                            
                            delegate: Rectangle {
                                width: categoryListView.width
                                height: 60
                                color: midiFileManager.selectedCategory === modelData.name ? "#3a3a3a" : "#1a1a1a"
                                
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onEntered: parent.color = "#2a2a2a"
                                    onExited: parent.color = midiFileManager.selectedCategory === modelData.name ? "#3a3a3a" : "#1a1a1a"
                                    
                                    onClicked: {
                                        midiFileManager.selectedCategory = modelData.name
                                        fileListView.model = modelData.files
                                    }
                                }
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 4
                                    
                                    Text {
                                        text: modelData.displayName
                                        color: "#ffffff"
                                        font.pixelSize: 15
                                        font.bold: midiFileManager.selectedCategory === modelData.name
                                    }
                                    
                                    Text {
                                        text: modelData.count + " fichier" + (modelData.count > 1 ? "s" : "")
                                        color: "#888888"
                                        font.pixelSize: 12
                                    }
                                }
                                
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 1
                                    color: "#333333"
                                }
                            }
                        }
                    }
                }
                
                // Séparateur vertical
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: "#555555"
                }
                
                // Liste des fichiers (droite)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#0a0a0a"
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        // En-tête fichiers
                        Rectangle {
                            Layout.fillWidth: true
                            height: 50
                            color: "#2a2a2a"
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 10
                                
                                Text {
                                    text: "🎼 Fichiers"
                                    color: "#ffffff"
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                                
                                Text {
                                    text: midiFileManager.selectedCategory ? 
                                          "(" + midiFileManager.getFilesForCategory(midiFileManager.selectedCategory).length + ")" : ""
                                    color: "#888888"
                                    font.pixelSize: 14
                                }
                                
                                Item { Layout.fillWidth: true }
                            }
                        }
                        
                        // Message si aucune catégorie sélectionnée
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: midiFileManager.selectedCategory === ""
                            
                            Text {
                                anchors.centerIn: parent
                                text: "← Sélectionnez une catégorie"
                                color: "#666666"
                                font.pixelSize: 18
                            }
                        }
                        
                        // Liste fichiers
                        ListView {
                            id: fileListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            visible: midiFileManager.selectedCategory !== ""
                            spacing: 2
                            
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }
                            
                            delegate: Rectangle {
                                width: fileListView.width - 10
                                height: 70
                                color: midiFileManager.selectedFile === modelData.path ? "#3a3a3a" : "#1a1a1a"
                                radius: 4
                                
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onEntered: parent.color = "#2a2a2a"
                                    onExited: parent.color = midiFileManager.selectedFile === modelData.path ? "#3a3a3a" : "#1a1a1a"
                                    
                                    onClicked: {
                                        // Sélectionner visuellement
                                        midiFileManager.selectedFile = modelData.path
                                    }
                                    
                                    onDoubleClicked: {
                                        // Double-clic charge le fichier
                                        midiFileManager.loadMidiFile(modelData.path)
                                    }
                                }
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 15
                                    
                                    // Icône
                                    Text {
                                        text: "🎵"
                                        font.pixelSize: 24
                                    }
                                    
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        
                                        Text {
                                            text: midiFileManager.formatFileName(modelData.name)
                                            color: "#ffffff"
                                            font.pixelSize: 15
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        
                                        Text {
                                            text: modelData.path
                                            color: "#666666"
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                    
                                    // Bouton charger
                                    Button {
                                        text: "▶ Charger"
                                        highlighted: true
                                        onClicked: midiFileManager.loadMidiFile(modelData.path)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Pied de page avec instructions
        Rectangle {
            Layout.fillWidth: true
            height: 40
            color: "#2a2a2a"
            radius: 4
            
            Text {
                anchors.centerIn: parent
                text: "💡 Double-cliquez sur un fichier ou utilisez le bouton 'Charger' pour envoyer à PureData"
                color: "#888888"
                font.pixelSize: 12
            }
        }
    }
}

