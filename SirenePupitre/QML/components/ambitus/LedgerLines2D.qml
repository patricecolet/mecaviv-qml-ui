import QtQuick

/**
 * Lignes supplémentaires (au-dessus ou en-dessous de la portée) pour une note.
 * Même logique que LedgerLines3D, en 2D : Repeater + Rectangle horizontal.
 */
Item {
    id: root

    property real noteY: 0
    property real lineSpacing: 20
    property real lineThickness: 1
    property real lineLength: 40
    property color lineColor: Qt.rgba(0.8, 0.8, 0.8, 1)
    property real staffCenterLocal: 0

    Repeater {
        model: {
            if (root.noteY >= -2 * root.lineSpacing && root.noteY <= 2 * root.lineSpacing) return 0
            if (root.noteY < -2 * root.lineSpacing) {
                var firstLedgerLine = -3 * root.lineSpacing
                if (root.noteY > firstLedgerLine) return 0
                return Math.floor((firstLedgerLine - root.noteY) / root.lineSpacing) + 1
            } else {
                var firstLedgerLine = 3 * root.lineSpacing
                if (root.noteY < firstLedgerLine) return 0
                return Math.floor((root.noteY - firstLedgerLine) / root.lineSpacing) + 1
            }
        }

        Rectangle {
            width: root.lineLength
            height: root.lineThickness
            color: root.lineColor
            x: (parent ? parent.width : 0) / 2 - root.lineLength / 2
            y: {
                var ledgerY
                if (root.noteY < -2 * root.lineSpacing) {
                    ledgerY = root.staffCenterLocal + (-3 * root.lineSpacing - index * root.lineSpacing)
                } else {
                    ledgerY = root.staffCenterLocal + (3 * root.lineSpacing + index * root.lineSpacing)
                }
                return ledgerY - root.lineThickness / 2
            }
        }
    }
}
