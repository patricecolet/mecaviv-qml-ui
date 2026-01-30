import QtQuick
import "../../utils"
import "."

Item {
    id: root

    // Zone ambitus 2D : démarre après la clé, graves à gauche, aiguës à droite
    property int ambitusMin: 48
    property int ambitusMax: 84
    property real ambitusStartX: 0
    property real ambitusWidth: 1800
    property real lineSpacing: 20
    property real lineThickness: 1
    property string clef: "treble"
    property int octaveOffset: 0

    property color noteColor: Qt.rgba(0.9, 0.6, 0.6, 0.9)
    property real noteScale: 0.15
    property bool showOnlyNaturals: true
    property bool showLedgerLines: true
    property bool showDebugLabels: false

    // Centre Y de la portée (ligne du milieu) pour positionner les notes
    property real centerY: height / 2

    NotePositionCalculator2D {
        id: noteCalc2D
    }

    MusicUtils {
        id: musicUtils
    }

    // Rayon des cercles en pixels (équivalent visuel au scale 3D)
    readonly property real _noteRadius: Math.max(2, lineSpacing * noteScale * 2)

    Repeater {
        model: root.ambitusMax - root.ambitusMin + 1

        Item {
            id: noteItem
            property int noteMidi: root.ambitusMin + index
            property real offsetNote: noteMidi + (root.octaveOffset * 12)
            property real noteY: noteCalc2D.calculateNoteY(offsetNote, root.lineSpacing, root.clef)
            property real noteX: noteCalc2D.calculateNoteX2D(noteMidi, root.ambitusMin, root.ambitusMax, root.ambitusStartX, root.ambitusWidth)
            property bool isNatural: noteCalc2D.isNaturalNote(noteMidi)
            property string noteName: musicUtils.noteNames[noteMidi % 12]

            visible: !root.showOnlyNaturals || isNatural

            x: noteX - root._noteRadius
            y: root.centerY + noteY - root._noteRadius

            Rectangle {
                width: root._noteRadius * 2
                height: root._noteRadius * 2
                radius: root._noteRadius
                color: root.noteColor
                border.width: 0
            }

            Text {
                visible: root.showDebugLabels
                text: noteItem.noteName
                color: "#FFFF80"
                font.pixelSize: 10
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 2
            }
        }
    }
}
