import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property var configController: null
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 15
        
        Item { height: 20 }
        
        Text {
            Layout.leftMargin: 20
            text: "Configuration"
            color: "#FFD700"
            font.pixelSize: 18
            font.bold: true
        }
        
        // Configuration actuelle
        GroupBox {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            title: "Configuration actuelle"
            
            label: Text {
                text: parent.title
                color: "#FFD700"
                font.pixelSize: 14
                font.bold: true
            }
            
            background: Rectangle {
                color: "#1a1a1a"
                border.color: "#444"
                radius: 5
            }
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                
                Text {
                    text: "Fichier: config.js"
                    color: "#bbb"
                    font.pixelSize: 13
                }
                
                Text {
                    text: "Mode actuel: " + (configController?.mode || "N/A")
                    color: "#bbb"
                    font.pixelSize: 13
                }
                
                Text {
                    text: "Sirène active: " + (configController?.primarySiren?.name || "N/A")
                    color: "#bbb"
                    font.pixelSize: 13
                }
                
                Text {
                    text: "Nombre de sirènes: " + (configController?.config?.sirenConfig?.sirens?.length || 0)
                    color: "#bbb"
                    font.pixelSize: 13
                }
            }
        }
        
        // Actions
        GroupBox {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            title: "Actions"
            
            label: Text {
                text: parent.title
                color: "#FFD700"
                font.pixelSize: 14
                font.bold: true
            }
            
            background: Rectangle {
                color: "#1a1a1a"
                border.color: "#444"
                radius: 5
            }
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                
                Button {
                    text: "Recharger la configuration"
                    Layout.preferredWidth: 200
                    
                    onClicked: {
                    }
                }
                
                Button {
                    text: "Exporter la configuration"
                    Layout.preferredWidth: 200
                    enabled: false
                    
                    onClicked: {
                    }
                }
                
                Button {
                    text: "Réinitialiser aux valeurs par défaut"
                    Layout.preferredWidth: 200
                    enabled: false
                    
                    onClicked: {
                    }
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}