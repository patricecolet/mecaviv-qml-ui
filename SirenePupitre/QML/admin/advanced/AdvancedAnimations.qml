import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: root
    
    property var configController: null
    property var webSocketController: null
    
    ColumnLayout {
        width: parent.width
        spacing: 15
        
        Item { height: 10 }
        
        // Section Transitions
        GroupBox {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            title: "Transitions"
            
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
                    text: "Durée et type des transitions - À implémenter"
                    color: "#888"
                }
            }
        }
        
        // Section Effets visuels
        GroupBox {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            title: "Effets visuels"
            
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
                    text: "Paramètres des effets - À implémenter"
                    color: "#888"
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}