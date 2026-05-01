import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SirenManager

// Two pavillons side-by-side: rotation Dial (0..359 degrees) + vitesse +
// acceleration + deceleration sliders + ST switch + Zero / New Zero buttons.
// Wire format reproduced from ViewPavillon.m. The legacy uses a custom circle
// hit-test view; we use Qt Quick Dial which exposes the same angle semantics.
Rectangle {
    id: root
    color: "#1e1e1e"

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        PavillonStrip {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: "PAVILLON 1"
            sidePos: 0x9C       // legacy ViewPavillon.m:271
            sideParam: 0xBC     // legacy: vitesse/accel/decel uses different side
        }
        PavillonStrip {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: "PAVILLON 2"
            sidePos: 0x9D
            sideParam: 0xBD
        }
    }

    component PavillonStrip: Rectangle {
        property string title: ""
        property int sidePos: 0x9C
        property int sideParam: 0xBC
        property bool stActive: false

        color: "#2a2a2a"
        border.color: "#444"
        radius: 6

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Label {
                text: title
                color: "#888"
                font.pixelSize: 13
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            // Rotation dial — sends position on commit (release).
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Dial {
                    id: rotDial
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 20, parent.height - 20, 280)
                    height: width
                    from: 0
                    to: 360
                    stepSize: 1
                    wrap: true
                    onPressedChanged: if (!pressed) {
                        // Map angle 0..360 → position 0..32 (legacy formula:
                        // (int)(angle * 16 / 360) + 12, with 0..40 range).
                        var angleDeg = Math.round(value)
                        var position = Math.round(angleDeg * 16 / 360) + 12
                        var positifor = stActive ? 0x70 : 0x01
                        if (!stActive) position = 40 - position
                        UdpManager.sendTourelle(sidePos, position, positifor)
                    }
                }

                Label {
                    anchors.centerIn: rotDial
                    text: Math.round(rotDial.value) + "°"
                    color: "white"
                    font.pixelSize: 22
                    font.bold: true
                }
            }

            // ST + zero buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Switch {
                    text: "ST"
                    checked: stActive
                    onToggled: stActive = checked
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: "Zero"
                    Layout.preferredHeight: 32
                    onClicked: UdpManager.sendTourelle(sidePos, 0x00, 100)
                }
                Button {
                    text: "New Zero"
                    Layout.preferredHeight: 32
                    onClicked: UdpManager.sendTourelle(sidePos, 0x03, 100)
                }
            }

            // Vitesse / Accélération / Décélération sliders
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                ParamSlider {
                    Layout.fillWidth: true
                    label: "Vitesse"
                    color: "#8DEEEE"
                    onCommit: function(v) { UdpManager.sendTourelle(sideParam, 7, v) }
                }
                ParamSlider {
                    Layout.fillWidth: true
                    label: "Accélération"
                    color: "#70DB93"
                    onCommit: function(v) { UdpManager.sendTourelle(sideParam, 73, v) }
                }
                ParamSlider {
                    Layout.fillWidth: true
                    label: "Décélération"
                    color: "#FF8C69"
                    onCommit: function(v) { UdpManager.sendTourelle(sideParam, 72, v) }
                }
            }
        }
    }

    component ParamSlider: RowLayout {
        property string label: ""
        property color color: "white"
        signal commit(int v)

        spacing: 8

        Label {
            text: label
            color: color
            font.pixelSize: 11
            Layout.preferredWidth: 90
        }
        Slider {
            id: paramSlider
            Layout.fillWidth: true
            from: 0; to: 127; stepSize: 1
            onMoved: paramThrottle.restart()
            onPressedChanged: if (!pressed) {
                paramThrottle.stop()
                parent.commit(Math.round(value))
            }
            Timer {
                id: paramThrottle
                interval: 150
                onTriggered: parent.parent.commit(Math.round(paramSlider.value))
            }
        }
        Label {
            text: Math.round(paramSlider.value).toString()
            color: color
            font.pixelSize: 11
            Layout.preferredWidth: 30
            horizontalAlignment: Text.AlignRight
        }
    }
}
