import QtQuick
import QtQuick.Controls

Item {
    id: root
    
    property int value: 0
    property color digitColor: '#d1d100'
    property color inactiveColor: "#003333"
    property color frameColor: "#00CED1"
    property string label: "" // "RPM" ou "Hz"
    property real digitSpacing: 45
    property real scaleX: 2.5
    property real scaleY: 1
    
    // Boîte principale (arrière)
    Rectangle {
        anchors.fill: parent
        color: "#2a2a2a"
        radius: 4
    }
    
    // Cadre intermédiaire
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        color: "#3a3a3a"
        radius: 3
    }
    
    // Écran noir (zone d'affichage)
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.8
        color: "#0a0a0a"
        radius: 2
    }
    
    // Cadre décoratif autour de l'écran
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        color: "transparent"
        border.color: root.frameColor
        border.width: 2
        radius: 4
    }
    
    // Conteneur pour les chiffres
    Row {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -root.digitSpacing * root.scaleX * 0.2
        spacing: root.digitSpacing * root.scaleX * 0.2
        
        // Chiffre des milliers
        Text {
            text: Math.floor(root.value / 1000) % 10
            font.pixelSize: 40 * root.scaleY
            font.family: "monospace"
            font.bold: true
            color: root.digitColor
        }
        
        // Chiffre des centaines
        Text {
            text: Math.floor(root.value / 100) % 10
            font.pixelSize: 40 * root.scaleY
            font.family: "monospace"
            font.bold: true
            color: root.digitColor
        }
        
        // Chiffre des dizaines
        Text {
            text: Math.floor(root.value / 10) % 10
            font.pixelSize: 40 * root.scaleY
            font.family: "monospace"
            font.bold: true
            color: root.digitColor
        }
        
        // Chiffre des unités
        Text {
            text: root.value % 10
            font.pixelSize: 40 * root.scaleY
            font.family: "monospace"
            font.bold: true
            color: root.digitColor
        }
    }
    
    // Label à droite
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font.pixelSize: 22 * root.scaleY
        font.bold: true
        color: '#46f870'
        visible: root.label !== ""
    }
}
