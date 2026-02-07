import QtQuick
import QtQuick.Controls

/**
 * Barre de mesure animée qui descend verticalement avec le numéro de mesure.
 * En mode monitoring 0x01 uniquement (sans tempo map / currentTimeMs), la barre est masquée.
 */
Item {
    id: root

    property var sequencerController: null
    property real cursorBarY: parent.height / 2
    property real fallSpeed: 150
    property real fixedFallTime: 5000
    property color accentColor: '#d1ab00'

    property real lineHeight: 2

    readonly property int currentBar: root.sequencerController && root.sequencerController.isPlaying
        ? (root.sequencerController.currentBar || 1)
        : 1

    function calculateBarY() {
        if (!root.sequencerController || !root.sequencerController.isPlaying) return -1000
        // Désactivé quand le monitor n'expose pas currentTimeMs (mode 0x01 seul, sans séquenceur UI)
        if (typeof root.sequencerController.currentTimeMs !== "number") return -1000

        var currentTimeMs = root.sequencerController.currentTimeMs || 0
        var bpm = root.sequencerController.currentTempoBpm || 120
        var msPerBeat = 60000 / bpm
        var msPerBar = msPerBeat * 4
        var targetTimeMs = (root.currentBar - 1) * msPerBar
        var msUntilTarget = targetTimeMs - currentTimeMs
        var distanceFromCursor = (msUntilTarget / root.fixedFallTime) * (root.fallSpeed * root.fixedFallTime / 1000)
        return root.cursorBarY - distanceFromCursor
    }

    // Barre de mesure unique
    Rectangle {
        id: barRect
        
        anchors.left: parent.left
        anchors.right: parent.right
        y: root.calculateBarY()
        height: root.lineHeight
        color: root.accentColor
        visible: root.sequencerController && root.sequencerController.isPlaying && y > -100 && y < parent.height + 100
        
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentBar.toString()
            color: root.accentColor
            font.pixelSize: 24
            font.bold: true
        }
    }

    // Timer pour animer la position Y
    Timer {
        interval: 50
        running: root.visible && root.sequencerController && root.sequencerController.isPlaying
        repeat: true
        onTriggered: {
            barRect.y = barRect.y  // Force recalculation
        }
    }
}
