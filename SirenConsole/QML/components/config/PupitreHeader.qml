import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: pupitreHeader
    
    // Propriétés publiques
    property string pupitreName: ""
    property var pupitre: null
    
    Layout.fillWidth: true
    Layout.preferredHeight: 50
    color: "#2a2a2a"
    border.color: "#555555"
    border.width: 1
    radius: 4
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 15
        
        Text {
            text: pupitreHeader.pupitreName
            color: "#ffffff"
            font.pixelSize: 18
            font.bold: true
        }
        
        Item {
            Layout.fillWidth: true
        }
        
        // Statut du pupitre
        RowLayout {
            spacing: 8
            
            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: {
                    if (!pupitreHeader.pupitre) return "#888888"
                    switch(pupitreHeader.pupitre.status) {
                        case "connected": return "#00ff00"
                        case "error": return "#ff0000"
                        default: return "#ffaa00"
                    }
                }
            }
            
            Text {
                text: {
                    if (!pupitreHeader.pupitre) return "Non configuré"
                    return pupitreHeader.pupitre.status || "Inconnu"
                }
                color: "#cccccc"
                font.pixelSize: 14
            }
        }
    }
}
