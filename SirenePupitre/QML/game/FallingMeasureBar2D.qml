import QtQuick
import "GameSequencer.js" as GameSequencer

/**
 * Barre de mesure en chute 2D — similaire à FallingNote2D mais pour une barre horizontale avec le numéro de mesure.
 * Créée dynamiquement par GameMode quand une nouvelle mesure commence.
 */
Item {
    id: root

    // API similaire à FallingNote2D
    property real targetY: 0  // Position Y du curseur (cursorBarY)
    property real fallSpeed: 150
    property real fixedFallTime: 5000
    // Si > 0 : durée de chute en ms (séquenceur lookahead) — la barre atteint le curseur à temps
    property real fallDurationMs: 0
    
    property int measureNumber: 1
    property color accentColor: '#d1ab00'
    property real lineHeight: 2

    // Calcul de la position de spawn (même logique que FallingNote2D)
    readonly property real fixedDistance: fallSpeed * (fixedFallTime / 1000)
    readonly property real barHeight: lineHeight
    
    readonly property real spawnY: fallDurationMs > 0
        ? (targetY - (fallSpeed * (fallDurationMs / 1000)))
        : (targetY - fixedDistance)
    property real currentY: spawnY

    // Position et taille
    anchors.left: parent.left
    anchors.right: parent.right
    y: currentY - barHeight / 2
    height: barHeight

    // Chute : durée = fallDurationMs si séquenceur, sinon fixedFallTime
    readonly property real _fallDuration: root.fallDurationMs > 0
        ? root.fallDurationMs
        : root.fixedFallTime
    NumberAnimation on currentY {
        id: fallAnimation
        from: root.spawnY
        to: root.targetY
        duration: root._fallDuration
        running: false
        onFinished: root.destroy()
    }

    // Barre horizontale
    Rectangle {
        anchors.fill: parent
        color: root.accentColor
    }

    // Numéro de mesure à gauche
    Text {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        text: root.measureNumber.toString()
        color: root.accentColor
        font.pixelSize: 24
        font.bold: true
    }

    Component.onCompleted: {
        fallAnimation.start()
    }
}
