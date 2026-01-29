import QtQuick

Item {
    id: root
    width: 600
    height: 100

    property color accentColor: '#d1ab00'
    property real rpm: 0
    property int frequency: 0
    property string noteName: "---"
    property real midiNote: 0
    property int velocity: 0
    property real bend: 0.0

    property real uiScale: 0.8

    NumberDisplay2D {
        x: -100
        y: 20
        width: 200
        height: 80
        value: root.rpm
        label: "RPM"
        digitColor: root.accentColor
        inactiveColor: "#003333"
        frameColor: root.accentColor
        scaleX: 2 * root.uiScale
        scaleY: 0.8 * root.uiScale
    }

    Rectangle {
        x: 150
        y: 20
        width: 200
        height: 80
        color: "#1a1a1a"
        border.color: root.accentColor
        border.width: 2
        radius: 4

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.noteName || "---"
                font.pixelSize: 32
                font.bold: true
                color: root.accentColor
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Text {
                    text: "MIDI: " + Math.round(root.midiNote)
                    font.pixelSize: 12
                    color: "#CCCCCC"
                }

                Text {
                    text: "Vel: " + (root.velocity || 0)
                    font.pixelSize: 12
                    color: "#CCCCCC"
                }

                Text {
                    text: "Bend: " + (root.bend || 0).toFixed(1)
                    font.pixelSize: 12
                    color: "#CCCCCC"
                }
            }
        }
    }

    NumberDisplay2D {
        x: 450
        y: 20
        width: 200
        height: 80
        value: root.frequency
        label: "Hz"
        digitColor: root.accentColor
        inactiveColor: "#003333"
        frameColor: root.accentColor
        scaleX: 1.8 * root.uiScale
        scaleY: 0.7 * root.uiScale
    }
}
