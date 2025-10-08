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
            text: "À propos"
            color: "#FFD700"
            font.pixelSize: 18
            font.bold: true
        }
        
        // Logo et titre
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.preferredHeight: 150
            color: "#2a2a2a"
            border.color: "#444"
            radius: 5
            
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20
                
                Text {
                    text: "MÉCANIQUE VIVANTE M645"
                    color: "#FFD700"
                    font.pixelSize: 24
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Text {
                    text: "Visualiseur Musical"
                    color: "#bbb"
                    font.pixelSize: 18
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Text {
                    text: "Version 1.0.0"
                    color: "#888"
                    font.pixelSize: 14
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
        
        // Informations
        GroupBox {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            title: "Informations système"
            
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
            
            GridLayout {
                anchors.fill: parent
                columns: 2
                columnSpacing: 20
                rowSpacing: 10
                
                Text {
                    text: "Framework:"
                    color: "#888"
                    font.pixelSize: 13
                }
                Text {
                    text: "Qt 6 avec Qt Quick 3D"
                    color: "#bbb"
                    font.pixelSize: 13
                }
                
                Text {
                    text: "Plateforme:"
                    color: "#888"
                    font.pixelSize: 13
                }
                Text {
                    text: Qt.platform.os
                    color: "#bbb"
                    font.pixelSize: 13
                }
                
                Text {
                    text: "Mode de rendu:"
                    color: "#888"
                    font.pixelSize: 13
                }
                Text {
                    text: "WebGL / OpenGL"
                    color: "#bbb"
                    font.pixelSize: 13
                }
            }
        }
        
        // Crédits
        Text {
            Layout.leftMargin: 20
            Layout.topMargin: 20
            text: "© 2024 Mécanique Vivante - Tous droits réservés"
            color: "#666"
            font.pixelSize: 12
        }
        
        Item { Layout.fillHeight: true }
    }
}