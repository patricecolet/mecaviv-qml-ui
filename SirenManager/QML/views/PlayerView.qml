import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SirenManager
import "../components"

Rectangle {
    id: root
    color: "#000000"

    // MachineType::LinuxMaitre == 0 (see src/Config/MachineType.h)
    readonly property int linuxMaitre: 0

    property int currentPage: 0
    property int selectedSlot: -1
    property int playingSlot: -1
    property bool isPlaying: false
    property bool isLooping: false
    property bool isSynchro: true
    property bool stState: false

    // 48 slots, populated from 'PS' messages
    property var slotsData: []
    property var slotLengths: []

    function defaultSlots() {
        var data = []
        for (var i = 0; i < 48; i++) {
            data.push({ index: i, name: "", loop: false, chain: false })
        }
        return data
    }

    function defaultLengths() {
        var arr = []
        for (var i = 0; i < 48; i++) arr.push(0)
        return arr
    }

    Component.onCompleted: {
        slotsData = defaultSlots()
        slotLengths = defaultLengths()
        // The singleton UdpManager is already connected (see main.cpp). Just
        // ask the Linux Maître to push its current playlist + state.
        UdpManager.sendAskSynchro(linuxMaitre)
    }

    Connections {
        target: UdpManager

        function onPlaylistSlotReceived(slot, filename, isLoop, isChain) {
            if (slot < 0 || slot >= 48) return
            var copy = slotsData.slice()
            copy[slot] = { index: slot, name: filename, loop: isLoop, chain: isChain }
            slotsData = copy
        }

        function onSequenceInfoReceived(name, totalSeconds) {
            currentSeqLabel.text = name.length > 0 ? name : "seq..."
            seqTimeLabel.text = formatMMSS(totalSeconds)
            progressSlider.to = Math.max(1, totalSeconds)
            progressSlider.value = 0
        }

        function onTimingUpdated(currentSeconds) {
            timingLabel.text = formatMMSS(currentSeconds)
            progressSlider.value = currentSeconds
        }

        function onRunningStateChanged(running, slotIndex) {
            root.isPlaying = running
            root.playingSlot = running ? slotIndex : -1
        }

        function onLoopStateChanged(active) {
            root.isLooping = active
        }

        function onSlotLengthReceived(slot, lengthTicks) {
            if (slot < 0 || slot >= 48) return
            var copy = slotLengths.slice()
            copy[slot] = lengthTicks
            slotLengths = copy
        }

        function onErrorOccurred(errorString) {
            console.log("[PlayerView] UDP error:", errorString)
        }
    }

    function formatMMSS(totalSeconds) {
        var m = Math.floor(totalSeconds / 60)
        var s = totalSeconds % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // ==================== HAUT : LABELS DE LECTURE ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: "#1a1a1a"
            border.color: "#444444"
            border.width: 1
            radius: 5

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 30

                Column {
                    spacing: 5
                    Text { text: "Timing"; color: "#888888"; font.pixelSize: 14; font.family: "AmericanTypewriter-Condensed" }
                    Text {
                        id: timingLabel
                        text: "00:00"
                        color: "#FFFFFF"
                        font.pixelSize: 30
                        font.family: "AmericanTypewriter-Condensed"
                        font.bold: true
                    }
                }

                Item { Layout.fillWidth: true }

                Column {
                    spacing: 5
                    Text { text: "Séquence"; color: "#888888"; font.pixelSize: 14; font.family: "AmericanTypewriter-Condensed" }
                    Text {
                        id: currentSeqLabel
                        text: "seq..."
                        color: "#FFFFFF"
                        font.pixelSize: 20
                        font.family: "AmericanTypewriter-Condensed"
                        font.bold: true
                    }
                }

                Item { Layout.fillWidth: true }

                Column {
                    spacing: 5
                    Text { text: "Temps"; color: "#888888"; font.pixelSize: 14; font.family: "AmericanTypewriter-Condensed" }
                    Text {
                        id: seqTimeLabel
                        text: "00:00"
                        color: "#FFFFFF"
                        font.pixelSize: 30
                        font.family: "AmericanTypewriter-Condensed"
                        font.bold: true
                    }
                }
            }
        }

        // ==================== MILIEU : GRILLE DES 48 SLOTS ====================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 10

                TabBar {
                    id: pageTabBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    currentIndex: root.currentPage
                    onCurrentIndexChanged: root.currentPage = currentIndex

                    TabButton { text: "Page 1 (1-24)"; width: pageTabBar.width / 2 }
                    TabButton { text: "Page 2 (25-48)"; width: pageTabBar.width / 2 }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    GridLayout {
                        id: slotsGrid
                        columns: 6
                        rowSpacing: 10
                        columnSpacing: 10

                        Repeater {
                            model: 24

                            PlaylistSlot {
                                property int globalIndex: root.currentPage * 24 + index

                                Layout.preferredWidth: 160
                                Layout.preferredHeight: 130

                                slotIndex: globalIndex
                                filename: slotsData[globalIndex] ? slotsData[globalIndex].name : ""
                                boucle: slotsData[globalIndex] ? slotsData[globalIndex].loop : false
                                enchain: slotsData[globalIndex] ? slotsData[globalIndex].chain : false
                                isSelected: root.selectedSlot === globalIndex
                                isActive: root.playingSlot === globalIndex && root.isPlaying

                                onSlotClicked: function(idx) {
                                    root.selectedSlot = idx
                                    UdpManager.sendSeqSelected(linuxMaitre, idx)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ==================== BAS : SLIDER + BOUTONS ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: "#1a1a1a"
            border.color: "#444444"
            border.width: 1
            radius: 5

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Slider {
                        id: progressSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: 0

                        background: Rectangle {
                            x: progressSlider.leftPadding
                            y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 8
                            width: progressSlider.availableWidth
                            height: implicitHeight
                            radius: 4
                            color: "#333333"

                            Rectangle {
                                width: progressSlider.visualPosition * parent.width
                                height: parent.height
                                color: "#8B4513"
                                radius: 4
                            }
                        }

                        handle: Rectangle {
                            x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                            y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                            implicitWidth: 16
                            implicitHeight: 16
                            radius: 8
                            color: progressSlider.pressed ? "#f0f0f0" : "#f6f6f6"
                            border.color: "#666666"
                            border.width: 2
                        }
                    }

                    BusyIndicator {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        running: root.isPlaying
                        visible: root.isPlaying
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        id: loopButton
                        text: "BOUCLE"
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 35
                        checkable: true
                        checked: root.isLooping

                        background: Rectangle {
                            color: loopButton.checked ? "#FFD700" : "#444444"
                            border.color: "#666666"; border.width: 2; radius: 5
                        }
                        contentItem: Text {
                            text: loopButton.text
                            color: loopButton.checked ? "#000000" : "#FFFFFF"
                            font.pixelSize: 13; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: UdpManager.sendBoucle(linuxMaitre, checked)
                    }

                    Button {
                        id: stopButton
                        text: "STOP"
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: "#444444"
                            border.color: "#666666"; border.width: 2; radius: 5
                        }
                        contentItem: Text {
                            text: stopButton.text; color: "#FFFFFF"
                            font.pixelSize: 13; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            UdpManager.sendStop(linuxMaitre)
                            // Mirror legacy: STOP forces isSynchro back to true (UI-only).
                            root.isSynchro = true
                        }
                    }

                    Button {
                        id: resetButton
                        text: "RESET"
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: "#444444"
                            border.color: "#666666"; border.width: 2; radius: 5
                        }
                        contentItem: Text {
                            text: resetButton.text; color: "#FFFFFF"
                            font.pixelSize: 13; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: UdpManager.sendReset(linuxMaitre)
                    }

                    Button {
                        id: stButton
                        text: "ST"
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 35
                        checkable: true
                        checked: root.stState

                        background: Rectangle {
                            color: stButton.checked ? "#4444FF" : "#444444"
                            border.color: "#666666"; border.width: 2; radius: 5
                        }
                        contentItem: Text {
                            text: stButton.text; color: "#FFFFFF"
                            font.pixelSize: 13; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            root.stState = checked
                            UdpManager.sendST(linuxMaitre, checked)
                        }
                    }

                    Button {
                        id: synchroButton
                        text: "SYNCHRO"
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 35
                        checkable: true
                        checked: root.isSynchro

                        background: Rectangle {
                            color: synchroButton.checked ? "#33AA33" : "#444444"
                            border.color: "#666666"; border.width: 2; radius: 5
                        }
                        contentItem: Text {
                            text: synchroButton.text; color: "#FFFFFF"
                            font.pixelSize: 12; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            root.isSynchro = checked
                            UdpManager.sendIsSynchro(linuxMaitre, checked)
                        }
                    }

                    Button {
                        id: syncButton
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: syncButton.pressed ? "#555555" : "#444444"
                            border.color: "#666666"; border.width: 2; radius: 5
                        }
                        contentItem: Text {
                            text: "↻"
                            color: "#FFFFFF"
                            font.pixelSize: 18
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: UdpManager.sendAskSynchro(linuxMaitre)
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Index:"
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                    }

                    SpinBox {
                        id: indexSpinBox
                        from: 1
                        to: 48
                        value: 1
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 30
                    }

                    Text {
                        text: "Mesure:"
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                    }

                    TextField {
                        id: measureField
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 30
                        text: "1"
                        validator: IntValidator { bottom: 1 }
                    }

                    Button {
                        id: resumeButton
                        text: "REPRENDRE"
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 30

                        background: Rectangle {
                            color: resumeButton.pressed ? "#555555" : "#444444"
                            border.color: "#666666"; border.width: 2; radius: 5
                        }
                        contentItem: Text {
                            text: resumeButton.text; color: "#FFFFFF"
                            font.pixelSize: 12; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            var slotIdx = indexSpinBox.value - 1
                            var measure = parseInt(measureField.text, 10) - 1
                            if (measure < 0) measure = 0
                            if (slotIdx < 0 || slotIdx >= 48) return
                            var entry = slotsData[slotIdx]
                            if (!entry || entry.name.length === 0) return
                            UdpManager.reprendreAtIndex(linuxMaitre, slotIdx, measure)
                        }
                    }
                }
            }
        }
    }
}
