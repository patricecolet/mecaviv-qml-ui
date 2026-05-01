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
    property bool isActive: false

    signal slotClicked(int index)
    signal slotDoubleClicked(int index)

    width: 160
    height: 130
    clip: true

    color: {
        if (mouseArea.pressed) return "#E67E00"
        if (isActive)          return "#E63333"
        return "#333333"
    }

    border.color: boucle ? "#FF0000" : "#FFFFFF"
    border.width: 1
    radius: 15

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        onClicked: root.slotClicked(root.slotIndex)
        onDoubleClicked: root.slotDoubleClicked(root.slotIndex)
    }

    // Slot number (top-right)
    Text {
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.right: parent.right
        anchors.rightMargin: 8
        text: (slotIndex + 1).toString()
        color: "#8B4513"
        font.pixelSize: 13
    }

    // Loop indicator (top-left, doesn't overlap title)
    Text {
        anchors.top: parent.top
        anchors.topMargin: 2
        anchors.left: parent.left
        anchors.leftMargin: 6
        text: "↻"           // clockwise arrow
        color: "#FF3333"
        font.pixelSize: 18
        visible: boucle
    }

    // Title — auto-shrinks to fit width (legacy used a condensed font that's
    // not on macOS, so fallback fonts are wider than the original sizing
    // assumed). HorizontalFit avoids any ellipsis truncation.
    Text {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: enchain ? 12 : 8
        anchors.topMargin: 22
        anchors.bottomMargin: 6
        text: filename
        color: "#FFFFFF"
        font.pixelSize: 28
        font.bold: true
        minimumPixelSize: 9
        fontSizeMode: Text.HorizontalFit
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
    }

    // Chain indicator: thin brown stripe on the right edge, INSIDE the slot
    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 4
        height: parent.height - 20
        color: "#8B4513"
        visible: enchain
    }
}
