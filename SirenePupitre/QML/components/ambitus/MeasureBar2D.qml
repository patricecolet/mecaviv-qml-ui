import QtQuick
import QtQuick.Controls
import "../../game/GameSequencer.js" as GameSequencer

/**
 * Barre de mesure animée qui descend verticalement avec le numéro de mesure.
 * Utilisée pour vérifier l'anticipation du séquenceur UI.
 */
Item {
    id: root

    property var sequencerController: null
    property real cursorBarY: parent.height / 2
    property real fallSpeed: 150
    property real fixedFallTime: 5000
    property color accentColor: '#d1ab00'

    property real lineHeight: 2

    // Mesure actuelle à afficher
    readonly property int currentBar: root.sequencerController && root.sequencerController.isPlaying
        ? (root.sequencerController.currentBar || 1)
        : 1

    // Calculer la position Y de la barre pour la mesure actuelle
    function calculateBarY() {
        if (!root.sequencerController || !root.sequencerController.isPlaying) return -1000
        
        var currentTimeMs = root.sequencerController.currentTimeMs || 0
        var targetTimeMs = 0
        
        // Calculer le temps en ms du début de la mesure actuelle
        if (root.sequencerController.sequencerTempoMap && root.sequencerController.sequencerTempoMap.length > 0) {
            targetTimeMs = GameSequencer.positionToMsWithMaps(
                root.currentBar, 1, 1.0,
                root.sequencerController.sequencerPpq || 480,
                root.sequencerController.sequencerTempoMap,
                root.sequencerController.sequencerTimeSignatureMap || []
            )
        } else {
            // Fallback : calcul simple avec BPM fixe
            var bpm = root.sequencerController.sequencerBpm || root.sequencerController.currentTempoBpm || 120
            var msPerBeat = 60000 / bpm
            var msPerBar = msPerBeat * 4
            targetTimeMs = (root.currentBar - 1) * msPerBar
        }
        
        // Temps jusqu'à cette mesure
        var msUntilTarget = targetTimeMs - currentTimeMs
        
        // Position Y : distance depuis cursorBarY proportionnelle au temps restant
        var distanceFromCursor = (msUntilTarget / root.fixedFallTime) * (root.fallSpeed * root.fixedFallTime / 1000)
        var barY = root.cursorBarY - distanceFromCursor
        
        return barY
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
