import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SirenManager

Rectangle {
    id: root
    color: "#1e1e1e"

    ScrollView {
        anchors.fill: parent
        anchors.margins: 10
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 12

            // ==================== VOLUMES (master + 7 channels with mutes) ====================
            SectionFrame {
                title: "VOLUMES"
                Layout.preferredHeight: 280

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Master ALL — fixed narrow width
                    ChannelStrip {
                        Layout.preferredWidth: 80
                        Layout.fillWidth: false
                        label: "ALL"
                        labelColor: "#66CDAA"
                        from: 0; to: 127
                        initialValue: 127
                        showMute: true
                        onValueCommitted: function(v) {
                            for (var i = 0; i < 7; i++) volRep.itemAt(i).setValue(v)
                            var arr = []
                            for (var j = 0; j < 7; j++) arr.push(v)
                            UdpManager.sendVolumeAll(arr)
                        }
                        onMuteRequested: function(m) {
                            isMuted = m
                            for (var i = 0; i < 7; i++) volRep.itemAt(i).setMuted(m)
                            trompeMute.setMuted(m)
                            UdpManager.sendMute(0, m)
                        }
                    }

                    Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: "#444" }

                    // 7 individual channels — share remaining horizontal space
                    Repeater {
                        id: volRep
                        model: 7
                        ChannelStrip {
                            Layout.fillWidth: true
                            property int sirenIdx: index + 1
                            label: "S" + sirenIdx
                            labelColor: "#00FFFF"
                            from: 0; to: 127
                            initialValue: 127
                            showMute: true
                            onValueCommitted: function(v) {
                                UdpManager.sendSirenVolume(sirenIdx, v)
                            }
                            onMuteRequested: function(m) {
                                isMuted = m
                                UdpManager.sendMute(sirenIdx, m)
                            }
                        }
                    }

                    // S8 = Trompe — mute only (no volume slider in legacy)
                    ColumnLayout {
                        id: trompeMute
                        Layout.preferredWidth: 70
                        Layout.fillHeight: true
                        Layout.fillWidth: false
                        property bool isMuted: false
                        function setMuted(m) { isMuted = m }
                        spacing: 2

                        Label {
                            text: "S8"
                            color: "#00FFFF"
                            font.pixelSize: 14
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "trompe"
                            color: "#777"
                            font.pixelSize: 9
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Item { Layout.fillHeight: true }
                        Button {
                            text: trompeMute.isMuted ? "MUTED" : "MUTE"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            background: Rectangle {
                                color: trompeMute.isMuted ? "#AA3333" : "#444"
                                border.color: "#666"; border.width: 1; radius: 4
                            }
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                font.pixelSize: 10; font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: {
                                trompeMute.isMuted = !trompeMute.isMuted
                                UdpManager.sendMute(8, trompeMute.isMuted)
                            }
                        }
                    }
                }
            }

            // ==================== LEDS + LUMIÈRES (side-by-side, single row each) ====================
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                SectionFrame {
                    title: "LEDS"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 8     // weight: 8 strips
                    Layout.preferredHeight: 200

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        Repeater {
                            model: 7
                            ChannelStrip {
                                Layout.fillWidth: true
                                property int ch: index + 1
                                label: "S" + ch
                                labelColor: "#00FFFF"
                                from: 0; to: 250
                                initialValue: 0
                                showMute: false
                                onValueCommitted: function(v) {
                                    UdpManager.sendLED(ch, 0, v)
                                }
                            }
                        }
                        ChannelStrip {
                            Layout.fillWidth: true
                            label: "S8"
                            sublabel: "trompe"
                            labelColor: "#00FFFF"
                            from: 0; to: 250
                            initialValue: 0
                            showMute: false
                            onValueCommitted: function(v) {
                                UdpManager.sendLEDTrompe(v)
                            }
                        }
                    }
                }

                SectionFrame {
                    title: "LUMIÈRES"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 4     // weight: 4 strips
                    Layout.preferredHeight: 200

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        ChannelStrip {
                            Layout.fillWidth: true
                            label: "AP1"; labelColor: "#FFD700"
                            from: 0; to: 127; initialValue: 0; showMute: false
                            onValueCommitted: function(v) { UdpManager.sendLumiere(0x9C, 1, v) }
                        }
                        ChannelStrip {
                            Layout.fillWidth: true
                            label: "AP2"; labelColor: "#FFD700"
                            from: 0; to: 127; initialValue: 0; showMute: false
                            onValueCommitted: function(v) { UdpManager.sendLumiere(0x9D, 1, v) }
                        }
                        ChannelStrip {
                            Layout.fillWidth: true
                            label: "BP1"; labelColor: "#FFA500"
                            from: 0; to: 99; initialValue: 0; showMute: false
                            onValueCommitted: function(v) { UdpManager.sendLumiere(0x9C, 2, v) }
                        }
                        ChannelStrip {
                            Layout.fillWidth: true
                            label: "BP2"; labelColor: "#FFA500"
                            from: 0; to: 99; initialValue: 0; showMute: false
                            onValueCommitted: function(v) { UdpManager.sendLumiere(0x9D, 2, v) }
                        }
                    }
                }
            }

            // ==================== SOURDINES + TIMBRE (bottom) ====================
            SectionFrame {
                title: "SOURDINES + TIMBRE"
                Layout.preferredHeight: 240

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Repeater {
                        model: 7
                        ChannelStrip {
                            Layout.fillWidth: true
                            property int sirenIdx: index + 1
                            label: "S" + sirenIdx
                            labelColor: "#FFF68F"
                            from: 0
                            to: sirenIdx <= 4 ? 127 : 255
                            initialValue: 0
                            showMute: false
                            onValueCommitted: function(v) {
                                UdpManager.sendSourdine(sirenIdx, 1, v)
                            }
                        }
                    }

                    Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: "#444" }

                    Repeater {
                        model: 3
                        ChannelStrip {
                            Layout.fillWidth: true
                            property int sirenIdx: index + 5
                            label: "S" + sirenIdx
                            sublabel: "timbre"
                            labelColor: "#66CDAA"
                            from: 0; to: 255
                            initialValue: 0
                            showMute: false
                            onValueCommitted: function(v) {
                                UdpManager.sendSourdine(sirenIdx, 2, v)
                            }
                        }
                    }
                }
            }
        }
    }

    // ----- nested components -----

    component SectionFrame: Rectangle {
        property string title: ""
        default property alias content: contentArea.data
        Layout.fillWidth: true
        color: "#2a2a2a"
        border.color: "#444"
        radius: 6

        Label {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 6
            anchors.leftMargin: 12
            text: title
            color: "#888"
            font.pixelSize: 11
            font.bold: true
        }
        Item {
            id: contentArea
            anchors.fill: parent
            anchors.topMargin: 24
        }
    }

    // Self-contained channel strip with vertical slider, value label, optional
    // mute button. Owns its slider value; setValue() updates it from outside
    // (won't override during user drag). Emits valueCommitted on user release
    // or after a 150ms throttle window during drag.
    component ChannelStrip: ColumnLayout {
        property string label: ""
        property string sublabel: ""
        property color labelColor: "white"
        property real from: 0
        property real to: 127
        property real initialValue: 0
        property bool showMute: false
        property bool isMuted: false

        signal valueCommitted(int v)
        signal muteRequested(bool muted)

        function setValue(v) {
            if (!stripSlider.pressed) stripSlider.value = v
        }
        function setMuted(m) { isMuted = m }

        Layout.preferredWidth: 60
        Layout.fillHeight: true
        spacing: 2

        Label {
            text: label
            color: labelColor
            font.pixelSize: 14
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
        Label {
            text: sublabel
            color: "#777"
            font.pixelSize: 9
            visible: sublabel.length > 0
            Layout.alignment: Qt.AlignHCenter
        }
        Label {
            text: Math.round(stripSlider.value).toString()
            color: labelColor
            font.pixelSize: 11
            Layout.alignment: Qt.AlignHCenter
        }
        Slider {
            id: stripSlider
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignHCenter
            orientation: Qt.Vertical
            from: parent.from
            to: parent.to
            stepSize: 1
            Component.onCompleted: value = parent.initialValue
            onMoved: throttle.restart()
            onPressedChanged: if (!pressed) {
                throttle.stop()
                parent.valueCommitted(Math.round(stripSlider.value))
            }
            Timer {
                id: throttle
                interval: 150
                onTriggered: parent.parent.valueCommitted(Math.round(stripSlider.value))
            }
        }
        Button {
            visible: showMute
            text: isMuted ? "MUTED" : "MUTE"
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            background: Rectangle {
                color: isMuted ? "#AA3333" : "#444"
                border.color: "#666"; border.width: 1; radius: 4
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.pixelSize: 9; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: muteRequested(!isMuted)
        }
    }
}
