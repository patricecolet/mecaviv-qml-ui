import QtQuick

Item {
    id: root
    implicitWidth: 200
    implicitHeight: 28

    property string speedText: "lent"
    property color textColor: "#fff"

    Text {
        anchors.fill: parent
        text: "Glissando : " + root.speedText
        color: root.textColor
        font.pixelSize: 14
        font.bold: true
        verticalAlignment: Text.AlignVCenter
    }
}
