import QtQuick
import "../../utils"
import "."

/**
 * Curseur de note 2D : barre verticale + pastille sur la note actuelle.
 * Même logique que NoteCursor3D, en 2D (Rectangle vertical, Behavior sur y/height).
 */
Item {
    id: root

    required property real currentNoteMidi
    required property real ambitusStartX
    required property real ambitusWidth
    required property real ambitusMin
    required property real ambitusMax
    required property real lineSpacing
    required property real centerY
    required property string clef
    required property int octaveOffset

    property real lineThickness: 1
    property color cursorColor: Qt.rgba(1, 0.2, 0.2, 0.8)
    property real cursorWidth: 3
    property real cursorOffsetY: 30
    property bool showNoteHighlight: true
    property color highlightColor: Qt.rgba(1, 1, 0, 0.6)
    property real highlightSize: 0.25
    property bool debug: false

    NotePositionCalculator2D {
        id: noteCalc2D
    }

    MusicUtils {
        id: musicUtils
    }

    property real currentNoteY: noteCalc2D.calculateNoteY(currentNoteMidi + (octaveOffset * 12), lineSpacing, clef)
    readonly property real _lowestNoteY: noteCalc2D.calculateNoteY(ambitusMin + (octaveOffset * 12), lineSpacing, clef)
    readonly property real _tailOffset: _lowestNoteY + 4 * lineSpacing
    property real cursorHeight: Math.max(2, _tailOffset - currentNoteY)
    property real cursorX: noteCalc2D.calculateNoteX2D(currentNoteMidi, ambitusMin, ambitusMax, ambitusStartX, ambitusWidth)
    readonly property real _clampedLeft: Math.max(ambitusStartX, Math.min(ambitusStartX + ambitusWidth - cursorWidth, cursorX - cursorWidth / 2))

    x: _clampedLeft
    y: centerY + currentNoteY
    width: cursorWidth
    height: cursorHeight

    Behavior on y { NumberAnimation { duration: 120 } }
    Behavior on height { NumberAnimation { duration: 120 } }
    Behavior on x { NumberAnimation { duration: 120 } }

    Rectangle {
        anchors.fill: parent
        color: root.cursorColor
        radius: Math.min(width, height) / 2
        z: 1
        border.width: root.debug ? 2 : 0
        border.color: root.debug ? "#FFFF00" : "transparent"
    }

    Text {
        visible: root.debug
        z: 10
        text: musicUtils.midiToNoteName(root.currentNoteMidi)
        color: "#FFFF00"
        font.pixelSize: 10
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 2
    }

    Rectangle {
        visible: root.showNoteHighlight
        z: 2
        x: (parent ? parent.width : 0) / 2 - _radius
        y: -_radius
        width: _radius * 2
        height: _radius * 2
        radius: _radius
        color: root.highlightColor
        readonly property real _radius: Math.max(2, root.lineSpacing * root.highlightSize)
    }
}
