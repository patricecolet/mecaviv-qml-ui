import QtQuick

Item {
    id: root
    implicitWidth: 280
    implicitHeight: 36

    property int phase: 0
    property color activeColor: "#6bb6ff"
    property color inactiveColor: "#444"

    readonly property var phaseLabels: ["Partielle", "Tempéré", "Bend plein"]

    Row {
        anchors.fill: parent
        spacing: 8
        Repeater {
            model: 3
            delegate: Rectangle {
                required property int index
                width: (parent.width - 16) / 3
                height: parent.height
                radius: 4
                color: root.phase === index ? root.activeColor : root.inactiveColor
                border.color: root.phase === index ? "#fff" : "#666"
                border.width: root.phase === index ? 2 : 1
                Text {
                    anchors.centerIn: parent
                    text: root.phaseLabels[index]
                    color: "#fff"
                    font.pixelSize: 12
                    font.bold: root.phase === index
                }
            }
        }
    }
}
