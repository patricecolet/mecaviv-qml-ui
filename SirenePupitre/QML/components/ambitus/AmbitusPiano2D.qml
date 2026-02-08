import QtQuick
import "../../utils"
import "."

/**
 * Vue clavier piano de l'ambitus : touches blanches et noires, note courante mise en évidence.
 * Même plage MIDI que la portée (ambitusMin..ambitusMax), graves à gauche, aiguës à droite.
 * Fausse 3D : dégradés, reflets, ombres latérales et bord supérieur rétréci pour la perspective.
 */
Item {
    id: root

    property real currentNoteMidi: 60
    /** Vélocité 0–127 pour moduler l'intensité de la touche courante (volume). */
    property real currentVelocity: 127
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
    // Position verticale du clavier : fixe (0) pour ne pas bouger quand l'ambitus admin change
    readonly property real _pianoOffsetY: 0
    readonly property real _keyHeight: height
    // Pas d'un demi-ton sur la grille (distance entre deux notes consécutives)
    readonly property real _semitoneStep: (ambitusMax > ambitusMin) ? _ambitusWidth / (ambitusMax - ambitusMin) : _ambitusWidth
    // Largeur visuelle d'une touche noire ≈ un demi-ton
    readonly property real _blackKeyWidth: _semitoneStep

    // ── Position X du centre d'une note ──
    function keyCenterX(midiNote) {
        if (ambitusMax <= ambitusMin) return _startX
        return _startX + (midiNote - ambitusMin) / (ambitusMax - ambitusMin) * _ambitusWidth
    }

    // ── Limites d'une touche blanche ──
    function whiteKeyBounds(midiNote) {
        var center = keyCenterX(midiNote)

        var prevNat = midiNote - 1
        while (prevNat >= ambitusMin && !noteCalc2D.isNaturalNote(prevNat))
            prevNat--

        var nextNat = midiNote + 1
        while (nextNat <= ambitusMax && !noteCalc2D.isNaturalNote(nextNat))
            nextNat++

        var leftEdge, rightEdge

        if (prevNat >= ambitusMin)
            leftEdge = (keyCenterX(prevNat) + center) / 2
        else
            leftEdge = (nextNat <= ambitusMax)
                ? center - (keyCenterX(nextNat) - center) / 2
                : _startX

        if (nextNat <= ambitusMax)
            rightEdge = (center + keyCenterX(nextNat)) / 2
        else
            rightEdge = (prevNat >= ambitusMin)
                ? center + (center - keyCenterX(prevNat)) / 2
                : _startX + _ambitusWidth

        return { x: leftEdge, width: rightEdge - leftEdge }
    }

    // Conteneur décalé vers le bas
    Item {
        id: keysContainer
        y: root._pianoOffsetY
        width: root.width
        height: root._keyHeight

        // ════════════════════════════════════════════
        //  Touches blanches
        // ════════════════════════════════════════════
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

                // Corps de la touche avec dégradé vertical (lumière en haut → ombre en bas)
                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    border.width: 1
                    border.color: parent.isCurrent ? Qt.darker(root.accentColor, 1.2) : root.whiteKeyBorder
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: parent.parent.isCurrent ? Qt.lighter(root.accentColor, 1.30) : Qt.lighter(root.whiteKeyColor, 1.12) }
                        GradientStop { position: 0.08; color: parent.parent.isCurrent ? Qt.lighter(root.accentColor, 1.15) : root.whiteKeyColor }
                        GradientStop { position: 0.85; color: parent.parent.isCurrent ? root.accentColor : Qt.darker(root.whiteKeyColor, 1.04) }
                        GradientStop { position: 1.0; color: parent.parent.isCurrent ? Qt.darker(root.accentColor, 1.2) : Qt.darker(root.whiteKeyColor, 1.15) }
                    }
                    opacity: parent.isCurrent ? (0.65 + 0.35 * Math.min(1, root.currentVelocity / 127)) : 1
                }

                // Ombre latérale gauche (perspective)
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(1, parent.width * 0.06)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: parent.parent.isCurrent ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(0, 0, 0, 0.08) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Ombre latérale droite (perspective)
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(1, parent.width * 0.06)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: parent.parent.isCurrent ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(0, 0, 0, 0.08) }
                    }
                }

                // Reflet brillant en haut (surface surélevée = plus de lumière)
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 1
                    anchors.leftMargin: Math.max(1, parent.width * 0.08)
                    anchors.rightMargin: Math.max(1, parent.width * 0.08)
                    height: Math.max(2, parent.height * 0.06)
                    radius: 1
                    color: parent.isCurrent ? Qt.rgba(1, 1, 0.8, 0.35) : Qt.rgba(1, 1, 1, 0.5)
                }

                // Ligne sombre en bas (bord avant de la touche)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.max(2, parent.height * 0.04)
                    radius: 1
                    color: parent.isCurrent ? Qt.darker(root.accentColor, 1.4) : Qt.rgba(0.55, 0.55, 0.55, 1)
                }
            }
        }

        // ════════════════════════════════════════════
        //  Touches noires
        // ════════════════════════════════════════════
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

                // Corps de la touche noire (dégradé vertical + bords assombris)
                Rectangle {
                    anchors.fill: parent
                    radius: 1
                    border.width: 1
                    border.color: parent.isCurrent ? Qt.lighter(root.accentColor, 1.3) : root.blackKeyBorder
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: parent.parent.isCurrent ? Qt.lighter(root.accentColor, 1.25) : Qt.lighter(root.blackKeyColor, 1.5) }
                        GradientStop { position: 0.12; color: parent.parent.isCurrent ? root.accentColor : Qt.lighter(root.blackKeyColor, 1.15) }
                        GradientStop { position: 0.75; color: parent.parent.isCurrent ? Qt.darker(root.accentColor, 1.1) : root.blackKeyColor }
                        GradientStop { position: 1.0; color: parent.parent.isCurrent ? Qt.darker(root.accentColor, 1.35) : Qt.darker(root.blackKeyColor, 1.35) }
                    }
                    opacity: parent.isCurrent ? (0.65 + 0.35 * Math.min(1, root.currentVelocity / 127)) : 1
                }

                // Reflet brillant en haut de la touche noire (laque)
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 1
                    anchors.leftMargin: Math.max(1, parent.width * 0.15)
                    anchors.rightMargin: Math.max(1, parent.width * 0.15)
                    height: Math.max(2, parent.height * 0.12)
                    radius: 1
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: parent.parent.isCurrent ? Qt.rgba(1, 1, 0.7, 0.4) : Qt.rgba(1, 1, 1, 0.25) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Ombre latérale gauche
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(1, parent.width * 0.1)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.3) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Ombre latérale droite
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(1, parent.width * 0.1)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.3) }
                    }
                }

                // Bord avant (bas) de la touche noire
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.max(2, parent.height * 0.06)
                    radius: 1
                    color: parent.isCurrent ? Qt.darker(root.accentColor, 1.5) : Qt.rgba(0.05, 0.05, 0.05, 1)
                }
            }
        }
    }
}
