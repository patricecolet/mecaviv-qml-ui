import QtQuick

Item {
    id: root
    implicitWidth: 120
    implicitHeight: 44

    /** 0 = fermé, 1 = ouvert */
    property real openAmount: 0
    property color fillColor: "#6bb6ff"
    property color trackColor: "#2a2a2a"

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: root.trackColor
        border.color: "#666"
        border.width: 1
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1, root.openAmount))
            radius: 4
            color: root.fillColor
        }
        Text {
            anchors.centerIn: parent
            text: "Volet " + Math.round(root.openAmount * 100) + "%"
            color: "#eee"
            font.pixelSize: 12
        }
    }
}
