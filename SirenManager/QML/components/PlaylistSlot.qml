import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    
    property int slotIndex: 0
    property string filename: ""
    property string pseudo: ""
    property bool boucle: false
    property bool enchain: false
    property bool isSelected: false
    property bool isActive: false  // Si la séquence est en cours de lecture
    
    signal slotClicked(int index)
    signal slotDoubleClicked(int index)
    
    width: 160
    height: 130
    
    // Couleurs selon l'état (d'après viewSeq.m)
    color: {
        if (isSelected) return "#E67E00"  // Orange RGB(0.9, 0.5, 0) quand sélectionné
        if (isActive) return "#E63333"     // Rouge RGB(0.9, 0.2, 0.2) quand en lecture
        return "#333333"                   // Gris foncé RGB(0.2, 0.2, 0.2) par défaut
    }
    
    border.color: boucle ? "#FF0000" : "#FFFFFF"  // Rouge si boucle, blanc sinon
    border.width: 1
    radius: 15  // Rayon de 15px comme dans le code original
    
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.slotClicked(root.slotIndex)
        }
        onDoubleClicked: {
            root.slotDoubleClicked(root.slotIndex)
        }
    }
    
    // Numéro en haut à droite (brun, police 15pt)
    Text {
        id: numberText
        anchors.top: parent.top
        anchors.topMargin: 5
        anchors.right: parent.right
        anchors.rightMargin: 10
        text: (slotIndex + 1).toString()
        color: "#8B4513"  // Brown
        font.pixelSize: 15
        font.family: "AmericanTypewriter-Condensed"
    }
    
    // Nom de la séquence au centre (blanc, police 40pt)
    Text {
        id: nameText
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 10
        text: filename || ("seq" + slotIndex)
        color: "#FFFFFF"
        font.pixelSize: 40
        font.family: "AmericanTypewriter-Condensed"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideMiddle
        width: parent.width - 20
    }
    
    // Icône de boucle (60x60px) si activée
    Rectangle {
        id: loopIcon
        anchors.centerIn: parent
        width: 60
        height: 60
        color: "transparent"
        visible: boucle
        
        Text {
            anchors.centerIn: parent
            text: "⟲"
            color: "#FF0000"
            font.pixelSize: 40
        }
    }
    
    // Barre brune verticale (10x100px) si enchaînée
    Rectangle {
        id: chainBar
        anchors.left: parent.right
        anchors.leftMargin: 0
        anchors.verticalCenter: parent.verticalCenter
        width: 10
        height: 100
        color: "#8B4513"  // Brown
        visible: enchain
    }
}
