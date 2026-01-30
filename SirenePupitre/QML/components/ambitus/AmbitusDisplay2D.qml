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

    property color noteColor: Qt.rgba(0.97, 0.96, 0.96, 0.9)
    property real noteScale: 0.15
    property bool showOnlyNaturals: true
    property bool showLedgerLines: true
    property bool showDebugLabels: false
    property color lineColor: Qt.rgba(0.96, 0.96, 0.96)

    // Centre Y de la portée (ligne du milieu) pour positionner les notes
    property real centerY: height / 2

    NotePositionCalculator2D {
        id: noteCalc2D
    }

    MusicUtils {
        id: musicUtils
    }

    // Tête de note en ovale (comme en solfège : ellipse, pas cercle)
    readonly property real _noteRadius: Math.max(2, lineSpacing * noteScale * 2.1)
    readonly property real _noteHeadWidth: _noteRadius * 2 * 1.25
    readonly property real _noteHeadHeight: _noteRadius * 2
    readonly property real _noteHeadRotation: 12
    readonly property real _noteHeadOffsetY: -1
    property color noteBorderColor: Qt.rgba(0.65, 0.4, 0.4, 1)

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

            x: noteX - root._noteHeadWidth / 2
            y: root.centerY + noteY - root._noteHeadHeight / 2 + root._noteHeadOffsetY
            width: root._noteHeadWidth
            height: root._noteHeadHeight

            // Lignes supplémentaires : même couleur que la portée, pas de rotation (rester horizontales)
            LedgerLines2D {
                width: root._noteHeadWidth
                visible: root.showLedgerLines && (noteItem.noteY < -2 * root.lineSpacing || noteItem.noteY > 2 * root.lineSpacing)
                noteY: noteItem.noteY
                lineSpacing: root.lineSpacing
                lineThickness: root.lineThickness
                lineColor: root.lineColor
                staffCenterLocal: -noteItem.noteY + root._noteHeadHeight / 2 - root._noteHeadOffsetY
            }

            // Tête de note (ovale) + label : seuls éléments rotés
            Item {
                id: noteHeadItem
                anchors.centerIn: parent
                width: root._noteHeadWidth
                height: root._noteHeadHeight
                rotation: root._noteHeadRotation
                transformOrigin: Item.Center

                Rectangle {
                    width: root._noteHeadWidth
                    height: root._noteHeadHeight
                    radius: root._noteRadius
                    color: root.noteColor
                    border.width: 1
                    border.color: root.noteBorderColor
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
}
