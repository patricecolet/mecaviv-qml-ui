import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SirenManager

Rectangle {
    id: root
    color: "#1e1e1e"

    // 0..6 = S1..S7 (Trompe S8 not implemented — legacy uses a custom UI for it)
    property int currentSiren: 0
    property int velocity: 100
    property bool octaveUp: false   // +12 transpo when ON

    // Per-siren auto-transposition (legacy PianoViewController.m:54-65)
    readonly property var perSirenTranspose: [0, 0, -12, -12, 12, 12, 12]

    function midiChannel() { return currentSiren + 1 }
    function noteOnStatus() { return 0x90 + currentSiren }

    function sendNoteOn(chromIdx) {
        var note = chromIdx + 48 + (octaveUp ? 12 : 0) + perSirenTranspose[currentSiren]
        UdpManager.sendMidiIn(midiChannel(), noteOnStatus(),
                              Math.max(0, Math.min(127, note)),
                              Math.max(1, velocity))
    }
    function sendNoteOff(chromIdx) {
        var note = chromIdx + 48 + (octaveUp ? 12 : 0) + perSirenTranspose[currentSiren]
        // Legacy convention: velocity=1 means "release"; firmware treats it as note-off.
        UdpManager.sendMidiIn(midiChannel(), noteOnStatus(),
                              Math.max(0, Math.min(127, note)), 1)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

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

        Label {
            text: "Transpose actuelle: " + (perSirenTranspose[currentSiren] + (octaveUp ? 12 : 0)) + " demi-tons"
            color: "#888"
            font.pixelSize: 11
            Layout.alignment: Qt.AlignHCenter
        }

        // ==================== KEYBOARD ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#222"
            border.color: "#444"
            radius: 6

            Item {
                id: keyboard
                anchors.centerIn: parent
                width: Math.min(parent.width - 20, 14 * 70)
                height: Math.min(parent.height - 20, 280)

                readonly property real whiteWidth: width / 14
                readonly property real blackWidth: whiteWidth * 0.6
                readonly property real blackHeight: height * 0.62

                // White keys positions in semitones within a 7-white-key octave
                readonly property var whiteToChromatic: [0, 2, 4, 5, 7, 9, 11]

                // Black keys: chromatic note index + position-after-white-key (0-based within row)
                readonly property var blackKeys: [
                    // octave 1
                    { chrom: 1,  afterWhite: 0 },   // C#
                    { chrom: 3,  afterWhite: 1 },   // D#
                    { chrom: 6,  afterWhite: 3 },   // F#
                    { chrom: 8,  afterWhite: 4 },   // G#
                    { chrom: 10, afterWhite: 5 },   // A#
                    // octave 2
                    { chrom: 13, afterWhite: 7 },
                    { chrom: 15, afterWhite: 8 },
                    { chrom: 18, afterWhite: 10 },
                    { chrom: 20, afterWhite: 11 },
                    { chrom: 22, afterWhite: 12 }
                ]

                // White keys
                Repeater {
                    model: 14
                    Rectangle {
                        x: index * keyboard.whiteWidth
                        y: 0
                        width: keyboard.whiteWidth - 1
                        height: keyboard.height
                        radius: 3
                        property bool isPressed: false
                        property int chromIdx: keyboard.whiteToChromatic[index % 7] + Math.floor(index / 7) * 12
                        color: isPressed ? "#3399FF" : "white"
                        border.color: "#666"
                        border.width: 1

                        Label {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (index % 7 === 0) ? "C" + (Math.floor(index / 7) + 3) : ""
                            color: "#888"
                            font.pixelSize: 10
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: {
                                parent.isPressed = true
                                sendNoteOn(parent.chromIdx)
                            }
                            onReleased: {
                                parent.isPressed = false
                                sendNoteOff(parent.chromIdx)
                            }
                            onCanceled: {
                                parent.isPressed = false
                                sendNoteOff(parent.chromIdx)
                            }
                        }
                    }
                }

                // Black keys (rendered after, so on top of whites)
                Repeater {
                    model: keyboard.blackKeys
                    Rectangle {
                        x: modelData.afterWhite * keyboard.whiteWidth
                            + keyboard.whiteWidth - keyboard.blackWidth / 2
                        y: 0
                        width: keyboard.blackWidth
                        height: keyboard.blackHeight
                        radius: 2
                        property bool isPressed: false
                        property int chromIdx: modelData.chrom
                        color: isPressed ? "#3399FF" : "#1a1a1a"
                        border.color: "#000"
                        border.width: 1

                        MouseArea {
                            anchors.fill: parent
                            onPressed: {
                                parent.isPressed = true
                                sendNoteOn(parent.chromIdx)
                            }
                            onReleased: {
                                parent.isPressed = false
                                sendNoteOff(parent.chromIdx)
                            }
                            onCanceled: {
                                parent.isPressed = false
                                sendNoteOff(parent.chromIdx)
                            }
                        }
                    }
                }
            }
        }

        // ==================== VELOCITY + TRANSPO ====================
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

                Label { text: "Vélocité"; color: "#aaa"; font.pixelSize: 12 }
                Label {
                    text: velocity.toString()
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                    Layout.preferredWidth: 30
                }
                Slider {
                    Layout.fillWidth: true
                    from: 0; to: 127; stepSize: 1; value: 100
                    onValueChanged: root.velocity = Math.round(value)
                }

                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: "#444" }

                Label { text: "Octave +1"; color: "#aaa"; font.pixelSize: 12 }
                Switch {
                    checked: root.octaveUp
                    onToggled: root.octaveUp = checked
                }
            }
        }
    }
}
