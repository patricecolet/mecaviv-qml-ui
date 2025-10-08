import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../utils"  // Pour accéder à ColorPicker

ScrollView {
    id: root
    
    property var configController: null
    property var webSocketController: null

    ColumnLayout {
        width: parent.width
        spacing: 15
        
        Item { height: 10 }
        
        // Section Afficheurs LED
        GroupBox {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            title: "Couleurs des afficheurs LED"
            
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
                
                ColorPicker {
                    label: "Couleur LED:"
                    configPath: ["displayConfig", "components", "rpm", "ledSettings", "color"]
                    defaultColor: "#FFFF99"
                    configController: root.configController
                    webSocketController: root.webSocketController
                }
            }
        }
        
        // Section Portée musicale
        GroupBox {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            title: "Couleurs de la portée musicale"
            
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
                
                ColorPicker {
                    label: "Notes:"
                    configPath: ["displayConfig", "components", "musicalStaff", "ambitus", "noteColor"]
                    defaultColor: "#E69696"
                    configController: root.configController
                    webSocketController: root.webSocketController
                }
                
                ColorPicker {
                    label: "Lignes:"  // Changé pour inclure toutes les lignes
                    configPath: ["displayConfig", "components", "musicalStaff", "lines", "color"]  // Chemin unifié
                    defaultColor: "#CCCCCC"
                    configController: root.configController
                    webSocketController: root.webSocketController
                }
                                
                ColorPicker {
                    label: "Curseur de note:"  // Changer le label pour différencier
                    configPath: ["displayConfig", "components", "musicalStaff", "cursor", "color"]
                    defaultColor: "#FF3333"
                    configController: root.configController
                    webSocketController: root.webSocketController
                }
                
                ColorPicker {
                    label: "Highlight note actuelle:"
                    configPath: ["displayConfig", "components", "musicalStaff", "cursor", "highlightColor"]
                    defaultColor: "#FFFF00"  // Jaune par défaut
                    configController: root.configController
                    webSocketController: root.webSocketController
                }
                // Barre de progression
                Text {
                    text: "Barre de progression:"
                    color: "#FFD700"
                    font.pixelSize: 13
                    font.bold: true
                    topPadding: 10
                }
                
                ColumnLayout {
                    Layout.leftMargin: 20
                    spacing: 10
                    
                    ColorPicker {
                        label: "Fond:"
                        configPath: ["displayConfig", "components", "musicalStaff", "progressBar", "colors", "background"]
                        defaultColor: "#333333"
                        configController: root.configController
                        webSocketController: root.webSocketController
                    }
                    
                    ColorPicker {
                        label: "Progression:"
                        configPath: ["displayConfig", "components", "musicalStaff", "progressBar", "colors", "progress"]
                        defaultColor: "#33CC33"
                        configController: root.configController
                        webSocketController: root.webSocketController
                    }
                    
                    ColorPicker {
                        label: "Curseur:"  // Garder comme ça
                        configPath: ["displayConfig", "components", "musicalStaff", "progressBar", "colors", "cursor"]
                        defaultColor: "#FFFFFF"
                        configController: root.configController
                        webSocketController: root.webSocketController
                    }
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}
