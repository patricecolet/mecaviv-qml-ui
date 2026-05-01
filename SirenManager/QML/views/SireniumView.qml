import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SirenManager

Rectangle {
    id: root
    color: "#1e1e1e"

    // Selected siren for the pedal: 0 = none, 1..8 = S1..S8
    property int selectedSiren: 0
    property bool isAutomating: true
    property bool sireniumActive: false       // driven by 0x26 firmware echo
    property int currentNote: 0               // 0..11 chromatic
    property int currentVelocity: 0
    property bool defretActive: false

    // CC sliders shown for the selected siren (legacy ViewControllerSirenium.m)
    readonly property var ccList: [
        { num: 1,  label: "CC1\nMod",     color: "#EED8AE" },
        { num: 5,  label: "CC5",          color: "#FF4040" },
        { num: 9,  label: "CC9",          color: "#EED8AE" },
        { num: 11, label: "CC11\nExpr",   color: "#CDBA96" },
        { num: 15, label: "CC15",         color: "#FF8C69" },
        { num: 72, label: "CC72\nRel",    color: "#8DEEEE" },
        { num: 73, label: "CC73\nAtk",    color: "#70DB93" },
        { num: 92, label: "CC92\nTrem",   color: "#FF8C69" }
    ]

    readonly property var noteNames: [
        "Do", "Do#", "Ré", "Ré#", "Mi", "Fa",
        "Fa#", "Sol", "Sol#", "La", "La#", "Si"
    ]

    function ccStatus() { return 0xB0 + selectedSiren - 1 }
    function pbStatus() { return 0xE0 + selectedSiren - 1 }

    function selectSiren(idx) {
        // Radio-style: enabling one disables the others.
        if (selectedSiren === idx) {
            // Toggle off
            UdpManager.sendSirSelect(idx, false)
            selectedSiren = 0
        } else {
            if (selectedSiren !== 0) UdpManager.sendSirSelect(selectedSiren, false)
            selectedSiren = idx
            UdpManager.sendSirSelect(idx, true)
        }
    }

    Connections {
        target: UdpManager

        function onSireniumStateReceived(active, midiNote, velocity) {
            sireniumActive = active
            currentNote = midiNote % 12
            currentVelocity = velocity
        }
        function onSirenSelectionReceived(sirenIdx, selected) {
            // Echo from firmware — sync UI but don't re-emit.
            if (selected && sirenIdx >= 1 && sirenIdx <= 8) {
                selectedSiren = sirenIdx
            } else if (!selected && selectedSiren === sirenIdx) {
                selectedSiren = 0
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // ==================== TOP: state switches + selectors ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: "#2a2a2a"
            border.color: "#444"
            radius: 6

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16

                ColumnLayout {
                    spacing: 2
                    Label { text: "Automating"; color: "#aaa"; font.pixelSize: 11 }
                    Switch {
                        checked: isAutomating
                        onToggled: {
                            isAutomating = checked
                            UdpManager.sendAutomating(checked)
                        }
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Label { text: "Sirenium"; color: "#aaa"; font.pixelSize: 11 }
                    Rectangle {
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 24
                        color: sireniumActive ? "#33AA33" : "#555"
                        radius: 4
                        Label {
                            anchors.centerIn: parent
                            text: sireniumActive ? "ON" : "OFF"
                            color: "white"
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Label { text: "Pitch Bend"; color: "#aaa"; font.pixelSize: 11 }
                    Switch {
                        id: pbSwitch
                        enabled: selectedSiren !== 0
                        onToggled: {
                            // Legacy sends a single PB value (8192 = mid) when toggled.
                            var pb = checked ? 16383 : 0
                            UdpManager.sendMidiIn(selectedSiren, pbStatus(),
                                                  pb & 0x7F, (pb >> 7) & 0x7F)
                        }
                    }
                }

                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: "#444" }

                ColumnLayout {
                    spacing: 2
                    Label { text: "Defret"; color: "#aaa"; font.pixelSize: 11 }
                    Button {
                        text: defretActive ? "ON" : "OFF"
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        background: Rectangle {
                            color: defretActive ? "#FFD700" : "#444"
                            border.color: "#666"; border.width: 1; radius: 4
                        }
                        contentItem: Text {
                            text: parent.text
                            color: defretActive ? "black" : "white"
                            font.pixelSize: 11; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            defretActive = !defretActive
                            UdpManager.sendDefret(defretActive)
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: "Sirène pédalier:"
                    color: "#aaa"
                    font.pixelSize: 11
                }
                Label {
                    text: selectedSiren === 0 ? "—" : "S" + selectedSiren
                    color: "#FFD700"
                    font.pixelSize: 18
                    font.bold: true
                    Layout.preferredWidth: 40
                }
            }
        }

        // ==================== SIREN SELECTION (radio S1..S8) ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            color: "#2a2a2a"
            border.color: "#444"
            radius: 6

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Repeater {
                    model: 8
                    Button {
                        property int sirenIdx: index + 1
                        text: sirenIdx === 8 ? "Trompe" : "S" + sirenIdx
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        background: Rectangle {
                            color: selectedSiren === sirenIdx ? "#33AA33" : "#444"
                            border.color: "#666"; border.width: 1; radius: 4
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 13; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: selectSiren(sirenIdx)
                    }
                }
            }
        }

        // ==================== LIVE NOTE/VELOCITY DISPLAY ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            color: "#1a1a1a"
            border.color: "#444"
            radius: 6

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 30

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label { text: "NOTE"; color: "#666"; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                    Label {
                        text: noteNames[currentNote]
                        color: "#19FF33"
                        font.pixelSize: 64
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: "#333" }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label { text: "VÉLOCITÉ"; color: "#666"; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                    Label {
                        text: currentVelocity.toString()
                        color: "#19FF33"
                        font.pixelSize: 64
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }

        // ==================== 8 CC SLIDERS ====================
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
                text: "CONTROL CHANGES" + (selectedSiren === 0 ? "  (sélectionne une sirène)" : "")
                color: "#888"
                font.pixelSize: 11
                font.bold: true
            }

            RowLayout {
                anchors.fill: parent
                anchors.topMargin: 28
                anchors.bottomMargin: 12
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 6

                Repeater {
                    model: ccList

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2

                        Label {
                            text: modelData.label
                            color: modelData.color
                            font.pixelSize: 11
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }
                        Label {
                            text: Math.round(ccSlider.value).toString()
                            color: modelData.color
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }
                        Slider {
                            id: ccSlider
                            Layout.fillHeight: true
                            Layout.alignment: Qt.AlignHCenter
                            orientation: Qt.Vertical
                            from: 0; to: 127; stepSize: 1
                            enabled: selectedSiren !== 0
                            opacity: enabled ? 1.0 : 0.4
                            onMoved: ccThrottle.restart()
                            onPressedChanged: if (!pressed && selectedSiren !== 0) {
                                ccThrottle.stop()
                                UdpManager.sendMidiIn(selectedSiren, ccStatus(),
                                                      modelData.num, Math.round(value))
                            }
                            Timer {
                                id: ccThrottle
                                interval: 150
                                onTriggered: if (selectedSiren !== 0) {
                                    UdpManager.sendMidiIn(selectedSiren, ccStatus(),
                                                          modelData.num, Math.round(ccSlider.value))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
