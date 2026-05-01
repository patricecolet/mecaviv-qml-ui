import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SirenManager

Rectangle {
    id: root
    color: "#1e1e1e"

    readonly property int linuxMaitre: 0   // MachineType::LinuxMaitre
    readonly property var sirenMachine: [
        2, 3, 4, 5, 6, 7, 8   // MachineType S1..S7 are 2..8
    ]

    // Live state from Linux Maître TRAMPRESENCE heartbeats
    property var kebPresent: [false, false, false, false, false, false, false]
    property bool trompePresent: false

    // Slider max per siren — S1-S4: 2000 RPM, S5-S7: 7200 RPM (legacy values)
    readonly property var motorMax: [2000, 2000, 2000, 2000, 7200, 7200, 7200]
    readonly property int valveMax: 500

    Connections {
        target: UdpManager

        function onKebPresenceReceived(sirenIdx, present) {
            if (sirenIdx < 1 || sirenIdx > 7) return
            var copy = kebPresent.slice()
            copy[sirenIdx - 1] = present
            kebPresent = copy
        }

        function onTrompePresenceReceived(present) {
            trompePresent = present
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // ==================== GLOBALS ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            color: "#2a2a2a"
            border.color: "#444"
            radius: 6

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 30

                // ST toggle
                ColumnLayout {
                    spacing: 2
                    Label { text: "ST"; color: "#aaa"; font.pixelSize: 11 }
                    Switch {
                        id: stSwitch
                        onToggled: UdpManager.sendST(linuxMaitre, checked)
                    }
                }

                // Trompe presence (read-only)
                ColumnLayout {
                    spacing: 2
                    Label { text: "Trompe"; color: "#aaa"; font.pixelSize: 11 }
                    Rectangle {
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 24
                        color: trompePresent ? "#33AA33" : "#555"
                        radius: 4
                        Label {
                            anchors.centerIn: parent
                            text: trompePresent ? "OK" : "—"
                            color: "white"
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }

                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: "#444" }

                // Transpo stepper
                ColumnLayout {
                    spacing: 2
                    Label { text: "Transpo (demi-tons)"; color: "#aaa"; font.pixelSize: 11 }
                    SpinBox {
                        id: transpoSpin
                        from: -64
                        to: 63
                        value: 0
                        editable: true
                        Layout.preferredWidth: 100
                        onValueModified: UdpManager.sendTranspoGlobal(value)
                    }
                }

                // Clic stepper
                ColumnLayout {
                    spacing: 2
                    Label { text: "Clic latence"; color: "#aaa"; font.pixelSize: 11 }
                    SpinBox {
                        id: clicSpin
                        from: 0
                        to: 255
                        value: 0
                        editable: true
                        Layout.preferredWidth: 100
                        onValueModified: UdpManager.sendClicLatency(value)
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        // ==================== 7 COLONNES SIRÈNES ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#2a2a2a"
            border.color: "#444"
            radius: 6

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                Repeater {
                    model: 7

                    ColumnLayout {
                        id: col
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 4
                        property int sirenIdx: index + 1     // 1..7

                        // Header: siren name + alive dot (TRAMPRESENCE-driven)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                radius: 4
                                color: kebPresent[index] ? "#33CC33" : "#555"
                            }
                            Label {
                                text: "S" + col.sirenIdx
                                color: kebPresent[index] ? "white" : "#777"
                                font.pixelSize: 16
                                font.bold: true
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        // Moteur slider — throttled at 150ms while dragging
                        // (legacy mSlider.m:203 uses 200ms NSTimer; without
                        // throttling, ~60 cmd/s flood the firmware and the
                        // motor can't keep up → visible oscillation).
                        Label {
                            text: "Moteur"
                            color: "#8DEEEE"
                            font.pixelSize: 10
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Slider {
                            id: motorSlider
                            Layout.fillHeight: true
                            Layout.alignment: Qt.AlignHCenter
                            orientation: Qt.Vertical
                            from: 0
                            to: motorMax[index]
                            stepSize: 1
                            onMoved: motorThrottle.restart()
                            onPressedChanged: if (!pressed) {
                                motorThrottle.stop()
                                UdpManager.sendSetKEB(col.sirenIdx, Math.round(value))
                            }
                            Timer {
                                id: motorThrottle
                                interval: 150
                                onTriggered: UdpManager.sendSetKEB(col.sirenIdx, Math.round(motorSlider.value))
                            }
                        }
                        Label {
                            text: Math.round(motorSlider.value).toString()
                            color: "#8DEEEE"
                            font.pixelSize: 11
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // Clapet slider — same throttle
                        Label {
                            text: "Clapet"
                            color: "#FF6464"
                            font.pixelSize: 10
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Slider {
                            id: valveSlider
                            Layout.preferredHeight: 130
                            Layout.alignment: Qt.AlignHCenter
                            orientation: Qt.Vertical
                            from: 0
                            to: valveMax
                            stepSize: 1
                            onMoved: valveThrottle.restart()
                            onPressedChanged: if (!pressed) {
                                valveThrottle.stop()
                                UdpManager.sendSetVolet(col.sirenIdx, Math.round(value))
                            }
                            Timer {
                                id: valveThrottle
                                interval: 150
                                onTriggered: UdpManager.sendSetVolet(col.sirenIdx, Math.round(valveSlider.value))
                            }
                        }
                        Label {
                            text: Math.round(valveSlider.value).toString()
                            color: "#FF6464"
                            font.pixelSize: 11
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // KEB presence indicator (read-only, driven by TRAMPRESENCE).
                        // The legacy switch was bidirectional but its user-click
                        // just sent a generic ST=ON regardless of which siren —
                        // not actually useful, dropped here.
                        Switch {
                            text: "KEB"
                            Layout.alignment: Qt.AlignHCenter
                            enabled: false
                            checked: kebPresent[index]
                        }
                    }
                }
            }
        }

        // ==================== CHANGE VOLET ====================
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

                Label { text: "Change volet"; color: "#aaa"; font.pixelSize: 13 }

                Label { text: "Sirène:"; color: "#aaa"; font.pixelSize: 11 }
                ComboBox {
                    id: voletSiren
                    model: ["S1", "S2", "S3", "S4", "S5", "S6", "S7"]
                    currentIndex: 0
                    Layout.preferredWidth: 80
                }

                Label { text: "Volet n°:"; color: "#aaa"; font.pixelSize: 11 }
                Row {
                    spacing: 4
                    Repeater {
                        model: 4
                        RadioButton {
                            text: (index + 1).toString()
                            checked: index === 0
                            ButtonGroup.group: voletGroup
                        }
                    }
                }

                Button {
                    text: "Activer"
                    onClicked: {
                        var sirenMachineId = sirenMachine[voletSiren.currentIndex]
                        var idx = 0
                        for (var i = 0; i < voletGroup.buttons.length; i++) {
                            if (voletGroup.buttons[i].checked) { idx = i; break }
                        }
                        UdpManager.sendChangeVolet(sirenMachineId, idx)
                    }
                }

                Item { Layout.fillWidth: true }

                ButtonGroup { id: voletGroup }
            }
        }
    }
}
