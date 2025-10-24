import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: pupitreViewer
    
    property var pupitre: null
    
    height: 150
    color: "#2a2a2a"
    border.color: "#555555"
    border.width: 1
    radius: 8
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15
        
        // Titre
        Text {
            text: pupitre ? "Interface " + pupitre.name : "Interface Pupitre"
            color: "#ffffff"
            font.pixelSize: 16
            font.bold: true
        }
        
        // Description
        Text {
            text: "Ouvrir l'interface complète du pupitre dans une nouvelle fenêtre"
            color: "#cccccc"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        
        // Informations de connexion
        RowLayout {
            spacing: 20
            
            Column {
                Text {
                    text: "Adresse:"
                    color: "#cccccc"
                    font.pixelSize: 10
                }
                Text {
                    text: pupitre ? pupitre.host + ":" + pupitre.port : "Non configuré"
                    color: "#ffffff"
                    font.pixelSize: 12
                    font.bold: true
                }
            }
            
            Column {
                Text {
                    text: "Statut:"
                    color: "#cccccc"
                    font.pixelSize: 10
                }
                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: pupitre && pupitre.status === "connected" ? "#00ff00" : 
                           pupitre && pupitre.status === "connecting" ? "#ffaa00" : "#ff6b6b"
                    
                    Text {
                        anchors.centerIn: parent
                        text: pupitre && pupitre.status === "connected" ? "●" : 
                              pupitre && pupitre.status === "connecting" ? "◐" : "○"
                        color: "#000000"
                        font.pixelSize: 8
                        font.bold: true
                    }
                }
            }
        }
        
        // Boutons d'action
        RowLayout {
            spacing: 10
            
            Button {
                text: "Ouvrir Interface"
                width: 150
                height: 40
                enabled: pupitre && pupitre.status === "connected"
                onClicked: {
                    if (pupitre) {
                        // Ouvrir nouvelle fenêtre avec URL du pupitre
                        var url = "http://" + pupitre.host + ":" + pupitre.port
                        // Ouverture interface pupitre
                        Qt.openUrlExternally(url)
                    }
                }
            }
            
            Button {
                text: "Rafraîchir"
                width: 120
                height: 40
                onClicked: {
                    // TODO: Rafraîchir la connexion
                    // Rafraîchissement pupitre
                }
            }
            
            Button {
                text: "Déconnecter"
                width: 120
                height: 40
                enabled: pupitre && pupitre.status === "connected"
                onClicked: {
                    // TODO: Déconnecter le pupitre
                    // Déconnexion pupitre
                }
            }
        }
        
        // Note sur les limitations
        Text {
            text: "Note: L'interface s'ouvrira dans une nouvelle fenêtre du navigateur (limitation WebAssembly)"
            color: "#888888"
            font.pixelSize: 10
            font.italic: true
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
