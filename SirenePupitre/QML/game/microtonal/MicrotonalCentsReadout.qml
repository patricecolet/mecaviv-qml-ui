import QtQuick

Item {
    id: root
    implicitWidth: 160
    implicitHeight: 64

    property real cents: 0
    property real okBandCents: 8
    property color textColor: "#fff"
    property color okColor: "#4ade80"
    property color warnColor: "#fbbf24"

    readonly property bool inOkBand: Math.abs(root.cents) <= root.okBandCents

    Column {
        anchors.centerIn: parent
        spacing: 4
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Δ cents"
            color: "#888"
            font.pixelSize: 11
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (root.cents >= 0 ? "+" : "") + root.cents.toFixed(1)
            color: root.inOkBand ? root.okColor : root.warnColor
            font.pixelSize: 28
            font.bold: true
            font.family: "monospace"
        }
    }
}
