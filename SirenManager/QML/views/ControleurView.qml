import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SirenManager

Rectangle {
    id: root
    color: "#1e1e1e"

    // 0..6 → MIDI channel S1..S7
    property int currentSiren: 0

    // CCs displayed (number, label, color)
    readonly property var ccList: [
        { num: 1,  label: "CC1\nMod",       color: "#7FFFD4" },
        { num: 5,  label: "CC5",            color: "#EEC900" },
        { num: 6,  label: "CC6",            color: "#EEA2AD" },
        { num: 7,  label: "CC7\nVol",       color: "#9AFF9A" },
        { num: 9,  label: "CC9",            color: "#7FFFD4" },
        { num: 11, label: "CC11\nExpr",     color: "#7FFFD4" },
        { num: 15, label: "CC15",           color: "#FFD39B" },
        { num: 17, label: "CC17",           color: "#EEC900" },
        { num: 18, label: "CC18",           color: "#EEA2AD" },
        { num: 72, label: "CC72\nRel",      color: "#FFEC8B" },
        { num: 73, label: "CC73\nAtk",      color: "#EEDD82" },
        { num: 74, label: "CC74\nCutoff",   color: "#FFD39B" },
        { num: 92, label: "CC92\nTrem",     color: "#FFD39B" }
    ]

    function midiChannel() { return currentSiren + 1 }       // 1..7
    function ccStatus()    { return 0xB0 + currentSiren }
    function pbStatus()    { return 0xE0 + currentSiren }
    function noteStatus()  { return 0x90 + currentSiren }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // ==================== SIREN SELECTOR ====================
        TabBar {
            id: sirenTabs
            Layout.fillWidth: true
            currentIndex: root.currentSiren
            onCurrentIndexChanged: root.currentSiren = currentIndex

            Repeater {
                model: 7
                TabButton { text: "S" + (index + 1) }
            }
        }

        // ==================== CC SLIDERS ====================
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
                text: "CONTROL CHANGES"
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
                spacing: 4

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
                            onMoved: ccThrottle.restart()
                            onPressedChanged: if (!pressed) {
                                ccThrottle.stop()
                                UdpManager.sendMidiIn(midiChannel(), ccStatus(),
                                                      modelData.num, Math.round(value))
                            }
                            Timer {
                                id: ccThrottle
                                interval: 150
                                onTriggered: UdpManager.sendMidiIn(midiChannel(), ccStatus(),
                                                                   modelData.num, Math.round(ccSlider.value))
                            }
                        }
                    }
                }
            }
        }

        // ==================== PITCH BEND ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: "#2a2a2a"
            border.color: "#444"
            radius: 6

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "PITCH BEND"; color: "#888"; font.pixelSize: 11; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: Math.round(pitchSlider.value).toString()
                        color: "#aaa"; font.pixelSize: 11
                    }
                    Button {
                        text: "Center"
                        Layout.preferredHeight: 22
                        onClicked: {
                            pitchSlider.value = 8192
                            UdpManager.sendMidiIn(midiChannel(), pbStatus(), 0, 64)
                        }
                    }
                }

                Slider {
                    id: pitchSlider
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    from: 0; to: 16383; stepSize: 1; value: 8192
                    onMoved: pbThrottle.restart()
                    onPressedChanged: if (!pressed) {
                        pbThrottle.stop()
                        var v = Math.round(value)
                        UdpManager.sendMidiIn(midiChannel(), pbStatus(),
                                              v & 0x7F, (v >> 7) & 0x7F)
                    }
                    Timer {
                        id: pbThrottle
                        interval: 150
                        onTriggered: {
                            var v = Math.round(pitchSlider.value)
                            UdpManager.sendMidiIn(midiChannel(), pbStatus(),
                                                  v & 0x7F, (v >> 7) & 0x7F)
                        }
                    }
                }
            }
        }

        // ==================== NOTE + CLAPET (velocity) ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            color: "#2a2a2a"
            border.color: "#444"
            radius: 6

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 16

                Label {
                    text: "NOTE ON"
                    color: "#888"; font.pixelSize: 11; font.bold: true
                    Layout.alignment: Qt.AlignTop
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        Label { text: "Note:"; color: "#aaa"; font.pixelSize: 11 }
                        Label {
                            text: Math.round(noteSlider.value).toString()
                            color: "white"; font.pixelSize: 12; font.bold: true
                            Layout.preferredWidth: 30
                        }
                    }
                    Slider {
                        id: noteSlider
                        Layout.fillWidth: true
                        from: 0; to: 127; stepSize: 1; value: 60   // C4
                        onMoved: noteThrottle.restart()
                        onPressedChanged: if (!pressed) {
                            noteThrottle.stop()
                            UdpManager.sendMidiIn(midiChannel(), noteStatus(),
                                                  Math.round(value), Math.round(velocitySlider.value))
                        }
                        Timer {
                            id: noteThrottle
                            interval: 150
                            onTriggered: UdpManager.sendMidiIn(midiChannel(), noteStatus(),
                                                               Math.round(noteSlider.value),
                                                               Math.round(velocitySlider.value))
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        Label { text: "Vélocité (clapet):"; color: "#aaa"; font.pixelSize: 11 }
                        Label {
                            text: Math.round(velocitySlider.value).toString()
                            color: "white"; font.pixelSize: 12; font.bold: true
                            Layout.preferredWidth: 30
                        }
                    }
                    Slider {
                        id: velocitySlider
                        Layout.fillWidth: true
                        from: 0; to: 127; stepSize: 1; value: 100
                        onMoved: velThrottle.restart()
                        onPressedChanged: if (!pressed) {
                            velThrottle.stop()
                            UdpManager.sendMidiIn(midiChannel(), noteStatus(),
                                                  Math.round(noteSlider.value), Math.round(value))
                        }
                        Timer {
                            id: velThrottle
                            interval: 150
                            onTriggered: UdpManager.sendMidiIn(midiChannel(), noteStatus(),
                                                               Math.round(noteSlider.value),
                                                               Math.round(velocitySlider.value))
                        }
                    }
                }
            }
        }
    }
}
