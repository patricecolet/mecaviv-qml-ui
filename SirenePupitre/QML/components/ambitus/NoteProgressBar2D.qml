import QtQuick
import "."

/**
 * Barre de progression 2D : fond + remplissage animé + curseur circulaire.
 * Équivalent 2D de NoteProgressBar3D (Rectangle au lieu de Model 3D).
 */
Item {
    id: root

    required property real currentNoteMidi
    required property real ambitusMin
    required property real ambitusMax
    required property real barStartX
    required property real barWidth
    required property real centerY

    property real lineSpacing: 20
    property string clef: "treble"
    property int octaveOffset: 0

    property real barHeight: 5
    property real barOffsetY: 30
    property color backgroundColor: Qt.rgba(0.2, 0.2, 0.2, 0.5)
    property color progressColor: Qt.rgba(0.2, 0.8, 0.2, 0.8)
    property color cursorColor: Qt.rgba(1, 1, 1, 0.9)
    property real cursorSize: 10
    property bool showPercentage: true

    NotePositionCalculator2D {
        id: noteCalc2D
    }

    readonly property real firstNoteY: noteCalc2D.calculateNoteY(ambitusMin + (octaveOffset * 12), lineSpacing, clef)
    readonly property real normalizedProgress: Math.max(0, Math.min(1, (currentNoteMidi - ambitusMin) / (ambitusMax - ambitusMin)))
    readonly property real barY: centerY + firstNoteY + barOffsetY
    readonly property real progressWidth: normalizedProgress * barWidth
    readonly property real cursorCenterX: barStartX + normalizedProgress * barWidth

    x: 0
    y: 0
    width: barStartX + barWidth + cursorSize
    height: Math.max(barY + barHeight, barY + cursorSize)

    // Barre de fond
    Rectangle {
        x: root.barStartX
        y: root.barY
        width: root.barWidth
        height: root.barHeight
        radius: root.barHeight / 2
        color: root.backgroundColor
    }

    // Barre de progression (jusqu'à la position actuelle)
    Rectangle {
        visible: root.normalizedProgress > 0
        x: root.barStartX
        y: root.barY
        width: root.progressWidth
        height: root.barHeight
        radius: root.barHeight / 2
        color: root.progressColor
        Behavior on width { NumberAnimation { duration: 120 } }
    }

    // Curseur circulaire sur la barre
    Rectangle {
        x: root.cursorCenterX - root.cursorSize / 2
        y: root.barY + root.barHeight / 2 - root.cursorSize / 2
        width: root.cursorSize
        height: root.cursorSize
        radius: root.cursorSize / 2
        color: root.cursorColor
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.3)
        Behavior on x { NumberAnimation { duration: 120 } }
    }
}
