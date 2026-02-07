import QtQuick
import "../../utils"
import "."

/**
 * Vue clavier piano de l'ambitus : touches blanches et noires, note courante mise en évidence.
 * Même plage MIDI que la portée (ambitusMin..ambitusMax), graves à gauche, aiguës à droite.
 */
Item {
    id: root

    property real currentNoteMidi: 60
    property var sirenInfo: null
    property var configController: null
    property real lineSpacing: 20
    property real staffWidth: width
    property color accentColor: "#d1ab00"

    property int ambitusMin: sirenInfo ? sirenInfo.ambitus.min : 48
    property int ambitusMax: sirenInfo ? (sirenInfo.mode === "restricted" && sirenInfo.restrictedMax !== undefined ? sirenInfo.restrictedMax : sirenInfo.ambitus.max) : 84
    property string clef: sirenInfo && sirenInfo.clef ? sirenInfo.clef : "treble"
    property int octaveOffset: (sirenInfo && sirenInfo.octaveOffset !== undefined) ? sirenInfo.octaveOffset : 0

    property color whiteKeyColor: Qt.rgba(0.98, 0.98, 0.98, 1)
    property color blackKeyColor: Qt.rgba(0.15, 0.15, 0.15, 1)
    property color whiteKeyBorder: Qt.rgba(0.75, 0.75, 0.75, 1)
    property color blackKeyBorder: Qt.rgba(0.05, 0.05, 0.05, 1)

    NotePositionCalculator2D {
        id: noteCalc2D
    }

    // Même géométrie que la portée : zone utile après la clé et les marges (_barStartX / _barWidth)
    property var staffConfig: {
        if (!configController) return {}
        var d = configController.updateCounter
        return configController.getConfigValue("displayConfig.components.musicalStaff", {})
    }
    readonly property real _clefSizeScale: 0.7
    readonly property real _clefDisplayWidth: lineSpacing * 5.2 * 0.5 * _clefSizeScale
    readonly property real _clefWidth: (staffConfig.clef && staffConfig.clef.width) ? staffConfig.clef.width : _clefDisplayWidth
    readonly property real _marginX: lineSpacing * 2
    readonly property real _startX: _clefWidth + _marginX
    readonly property real _ambitusWidth: Math.max(1, (staffWidth > 0 ? staffWidth : width) - _clefWidth - _marginX * 2)
    readonly property int _numNotes: Math.max(1, ambitusMax - ambitusMin + 1)
    // Hauteur de la zone où les notes atterrissent en mode animation (même formule que MelodicLine2D)
    readonly property real _animationKeysHeight: Math.max(0,
        noteCalc2D.calculateNoteY(ambitusMin + (octaveOffset * 12), lineSpacing, clef)
        - noteCalc2D.calculateNoteY(ambitusMax + (octaveOffset * 12), lineSpacing, clef))
    readonly property real _keyHeight: height
    readonly property real _pianoOffsetY: _animationKeysHeight
    // Pas d'un demi-ton sur la grille (distance entre deux notes consécutives)
    readonly property real _semitoneStep: (ambitusMax > ambitusMin) ? _ambitusWidth / (ambitusMax - ambitusMin) : _ambitusWidth
    // Largeur visuelle d'une touche noire ≈ un demi-ton
    readonly property real _blackKeyWidth: _semitoneStep

    // ── Position X du centre d'une note ──
    // Grille identique à calculateNoteX2D : ambitusMin → _startX, ambitusMax → _startX + _ambitusWidth.
    // Chaque demi-ton est espacé de _semitoneStep, ce qui aligne le piano avec l'animation.
    function keyCenterX(midiNote) {
        if (ambitusMax <= ambitusMin) return _startX
        return _startX + (midiNote - ambitusMin) / (ambitusMax - ambitusMin) * _ambitusWidth
    }

    // ── Limites d'une touche blanche ──
    // Chaque touche s'étend du milieu vers la blanche précédente au milieu vers la blanche suivante.
    // Les touches adjacentes sans noire entre elles (Si-Do, Mi-Fa) sont plus étroites,
    // les touches avec des noires des deux côtés (Ré, Sol, La) sont plus larges — comme un vrai piano.
    function whiteKeyBounds(midiNote) {
        var center = keyCenterX(midiNote)

        // Blanche précédente
        var prevNat = midiNote - 1
        while (prevNat >= ambitusMin && !noteCalc2D.isNaturalNote(prevNat))
            prevNat--

        // Blanche suivante
        var nextNat = midiNote + 1
        while (nextNat <= ambitusMax && !noteCalc2D.isNaturalNote(nextNat))
            nextNat++

        var leftEdge, rightEdge

        if (prevNat >= ambitusMin)
            leftEdge = (keyCenterX(prevNat) + center) / 2
        else
            // Première touche : étendre par symétrie du côté droit
            leftEdge = (nextNat <= ambitusMax)
                ? center - (keyCenterX(nextNat) - center) / 2
                : _startX

        if (nextNat <= ambitusMax)
            rightEdge = (center + keyCenterX(nextNat)) / 2
        else
            // Dernière touche : étendre par symétrie du côté gauche
            rightEdge = (prevNat >= ambitusMin)
                ? center + (center - keyCenterX(prevNat)) / 2
                : _startX + _ambitusWidth

        return { x: leftEdge, width: rightEdge - leftEdge }
    }

    // Conteneur décalé vers le bas : la hauteur des "touches" en mode animation (zone d'atterrissage des notes)
    Item {
        id: keysContainer
        y: root._pianoOffsetY
        width: root.width
        height: root._keyHeight

        // Touches blanches : largeur variable selon les voisins (comme un vrai piano)
        Repeater {
            model: root._numNotes
            delegate: Item {
                property int noteMidi: root.ambitusMin + index
                property bool isNatural: noteCalc2D.isNaturalNote(noteMidi)
                property bool isCurrent: Math.round(root.currentNoteMidi) === noteMidi
                visible: isNatural
                x: root.whiteKeyBounds(noteMidi).x
                width: root.whiteKeyBounds(noteMidi).width
                height: keysContainer.height
                Rectangle {
                    anchors.fill: parent
                    color: parent.isCurrent ? root.accentColor : root.whiteKeyColor
                    border.width: 1
                    border.color: parent.isCurrent ? Qt.darker(root.accentColor, 1.2) : root.whiteKeyBorder
                    radius: 2
                }
            }
        }

        // Touches noires : un demi-ton de large, centrées sur la grille uniforme
        Repeater {
            model: root._numNotes
            delegate: Item {
                property int noteMidi: root.ambitusMin + index
                property bool isBlack: !noteCalc2D.isNaturalNote(noteMidi)
                property bool isCurrent: Math.round(root.currentNoteMidi) === noteMidi
                visible: isBlack
                x: keyCenterX(noteMidi) - root._blackKeyWidth / 2
                y: 0
                width: root._blackKeyWidth
                height: keysContainer.height * 0.6
                Rectangle {
                    anchors.fill: parent
                    color: parent.isCurrent ? root.accentColor : root.blackKeyColor
                    border.width: 1
                    border.color: parent.isCurrent ? Qt.lighter(root.accentColor, 1.3) : root.blackKeyBorder
                    radius: 1
                }
            }
        }
    }
}
