import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SirenManager

// Simplified port of viewVoiture.m: the legacy uses two analog joysticks
// with angle math; here we expose the same direction codes via an 8-way
// directional pad + UP/DN/MONTER/DESCENDRE side controls. A car selector
// chooses which voiture (A/B/...) the commands target.
Rectangle {
    id: root
    color: "#1e1e1e"

    property int selectedCar: 0     // 0 = A, 1 = B, ...
    property bool isPchit: true

    // Direction byte constants from viewVoiture.m
    readonly property int dirAVG: 0xEF        // avant-gauche
    readonly property int dirAVD: 0xBF        // avant-droite
    readonly property int dirARG: 0x7F        // arrière-gauche
    readonly property int dirARD: 0xDF        // arrière-droite
    readonly property int dirUP:  0xFE
    readonly property int dirDN:  0xFD
    readonly property int dirStop: 0xFF       // mouseUp resets to "stop"
    readonly property int dirMonter: 0xFB
    readonly property int dirDescendre: 0xF7

    // Combined diagonals — legacy uses bitwise AND on the masks
    function dirAvant()    { return dirAVG & dirAVD }   // both forward
    function dirArriere()  { return dirARG & dirARD }
    function dirGauche()   { return dirAVG & dirARG }
    function dirDroite()   { return dirAVD & dirARD }

    function send(dir) {
        if (!isPchit) return
        UdpManager.sendVoiture(selectedCar, dir)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // ==================== TOP CONTROLS ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            color: "#2a2a2a"
            border.color: "#444"
            radius: 6

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16

                Label { text: "Voiture:"; color: "#aaa"; font.pixelSize: 12 }
                ComboBox {
                    id: carSelector
                    model: ["A", "B"]
                    Layout.preferredWidth: 80
                    onCurrentIndexChanged: root.selectedCar = currentIndex
                }

                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: "#444" }

                Label { text: "Pchit"; color: "#aaa"; font.pixelSize: 12 }
                Switch {
                    checked: isPchit
                    onToggled: {
                        isPchit = checked
                        UdpManager.sendPchit(checked)
                    }
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: isPchit ? "ENGAGÉ" : "désengagé"
                    color: isPchit ? "#33CC33" : "#888"
                    font.pixelSize: 13
                    font.bold: true
                }
            }
        }

        // ==================== DIRECTIONAL PAD + ELEVATION ====================
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // 8-way directional pad (left)
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#2a2a2a"
                border.color: "#444"
                radius: 6

                Label {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.topMargin: 6
                    anchors.leftMargin: 12
                    text: "DIRECTION (cliquer/maintenir)"
                    color: "#888"; font.pixelSize: 11; font.bold: true
                }

                GridLayout {
                    anchors.centerIn: parent
                    columns: 3
                    rowSpacing: 8
                    columnSpacing: 8

                    DirButton { text: "↖"; dirCode: root.dirAVG; onPressEvent: send(dirCode); onReleaseEvent: send(dirStop) }
                    DirButton { text: "↑"; dirCode: root.dirAvant(); onPressEvent: send(dirCode); onReleaseEvent: send(dirStop) }
                    DirButton { text: "↗"; dirCode: root.dirAVD; onPressEvent: send(dirCode); onReleaseEvent: send(dirStop) }

                    DirButton { text: "←"; dirCode: root.dirGauche(); onPressEvent: send(dirCode); onReleaseEvent: send(dirStop) }
                    Button {
                        text: "STOP"
                        Layout.preferredWidth: 80; Layout.preferredHeight: 80
                        background: Rectangle { color: "#AA3333"; radius: 6 }
                        contentItem: Text {
                            text: parent.text; color: "white"
                            font.pixelSize: 14; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: send(dirStop)
                    }
                    DirButton { text: "→"; dirCode: root.dirDroite(); onPressEvent: send(dirCode); onReleaseEvent: send(dirStop) }

                    DirButton { text: "↙"; dirCode: root.dirARG; onPressEvent: send(dirCode); onReleaseEvent: send(dirStop) }
                    DirButton { text: "↓"; dirCode: root.dirArriere(); onPressEvent: send(dirCode); onReleaseEvent: send(dirStop) }
                    DirButton { text: "↘"; dirCode: root.dirARD; onPressEvent: send(dirCode); onReleaseEvent: send(dirStop) }
                }
            }

            // Elevation pad (right)
            Rectangle {
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                color: "#2a2a2a"
                border.color: "#444"
                radius: 6

                Label {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.topMargin: 6
                    anchors.leftMargin: 12
                    text: "ÉLÉVATION"
                    color: "#888"; font.pixelSize: 11; font.bold: true
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    DirButton { text: "UP";        dirCode: root.dirUP;        onPressEvent: send(dirCode); onReleaseEvent: send(dirStop) }
                    DirButton { text: "MONTER";    dirCode: root.dirMonter;    onPressEvent: send(dirCode); onReleaseEvent: send(dirStop) }
                    DirButton { text: "DESCENDRE"; dirCode: root.dirDescendre; onPressEvent: send(dirCode); onReleaseEvent: send(dirStop) }
                    DirButton { text: "DN";        dirCode: root.dirDN;        onPressEvent: send(dirCode); onReleaseEvent: send(dirStop) }
                }
            }
        }
    }

    // ----- nested directional button component -----
    component DirButton: Button {
        property int dirCode: 0
        signal pressEvent()
        signal releaseEvent()

        Layout.preferredWidth: 80
        Layout.preferredHeight: 80
        background: Rectangle {
            color: parent.pressed ? "#3399FF" : "#444"
            border.color: "#666"; border.width: 1; radius: 6
        }
        contentItem: Text {
            text: parent.text
            color: "white"
            font.pixelSize: 18; font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        onPressedChanged: {
            if (pressed) pressEvent()
            else releaseEvent()
        }
    }
}
