import QtQuick
import QtQuick3D

Node {
    id: root
    // Identité/liaisons
    property int sirenId: 1
    property int channel: 0
    property var spec: ({}) // entrée de sirenSpec pour cette sirène
    // Données live
    property int note: 60
    property int velocity: 0
    property int bend: 4096
    property int bendCenter: 4096
    property color accent: "#FFFFFF"
    // Historique
    property bool historyEnabled: false
    property int measuresCount: 4
    property var events: [] // [{t, note, velocity, bend}]

    // (Fond retiré)

    

    // Portée + éléments (squelette)
    MusicalStaff3D {
        id: staff
        // Forcer la clé de sol pour le premier mapping précis
        clef: "treble"
        ambitus: (root.spec && root.spec.ambitus) ? root.spec.ambitus : ({ min: 48, max: 84 })
        // Adapter la taille au panneau (panel.scale.x ~ 10, y ~ 4)
        width: 9.2
        height: 3.8
        marginX: 0.25
        marginY: 0.1
        // Laisser la hauteur piloter l'espacement (plus grand)
        lineSpacing: 40
        position: Qt.vector3d(0, 0, 0.5)
    }

    // (Clé de sol retirée pour stabiliser l'affichage — on reviendra avec V2 SDF)

    // Mapping clé de sol (diatonique, sans compression): octave = 7 degrés = 3.5 interlignes
    function noteToY(n) {
        var transpose = (root.spec && root.spec.transpose) ? root.spec.transpose : 0
        var bendSemis = (root.bendCenter > 0) ? ((root.bend - root.bendCenter) / root.bendCenter) : 0

        // Degrés diatoniques relatifs à C5
        var nInt = Math.round(n + transpose)
        var semitoneFromC5 = nInt - 72 // C5 = 72
        var m = ((semitoneFromC5 % 12) + 12) % 12
        var stepTable = [0,0,1,1,2,3,3,4,4,5,5,6]
        var octSteps = Math.floor(semitoneFromC5 / 12) * 7
        var degreeSteps = octSteps + stepTable[m]
        // B4 (71) = ligne médiane -> avec repère C5, steps(B4) = -1
        // Ajustement fin: décale d'un degré vers le bas pour corriger C5 posé trop haut
        var stepsFromB4 = degreeSteps

        var yMin = -staff.effectiveHeight/2 + staff.marginY
        var yMidLine = yMin + (2 * staff.spacing)

        // 1 degré = 1/2 interligne; bend 1 demi‑ton ≈ 1 degré/2
        var unit = staff.spacing * 0.5
        return yMidLine + (stepsFromB4 + bendSemis) * unit
    }

    function pitchClass(n) {
        var transpose = (root.spec && root.spec.transpose) ? root.spec.transpose : 0
        var nInt = Math.round(n + transpose)
        var pc = ((nInt % 12) + 12) % 12
        return pc
    }

    function isSharp(n) {
        var pc = pitchClass(n)
        return (pc === 1 || pc === 3 || pc === 6 || pc === 8 || pc === 10)
    }

    // Positionneur (non-scalé) + correcteur d'échelle pour garder la sphère ronde
    Node {
        id: markerPos
        // Position calculée (auto‑échelle ambitus)
        position: Qt.vector3d(0, noteToY(root.note), 0.6)

        // Corrige la déformation due au scale non-uniforme du panneau
        Node {
            id: markerShapeScale
            scale: Qt.vector3d(1, root.scale.x / root.scale.y, 1)

            NoteMarker3D {
                id: marker
                note: root.note
                color: root.accent
                size: 0.8
            }
        }

        // Dièse (accidental) conditionnel, légèrement à gauche de la note (unités en spacing)
        AccidentalSharp3D {
            id: sharpSymbol
            visible: isSharp(root.note)
            size: staff.spacing * 0.9
            color: root.accent
            // Placer à ~2.2 interlignes à gauche et devant la sphère
            position: Qt.vector3d(-2.2 * staff.spacing, 0, 1.0)
        }
    }

    VelocityBar3D {
        id: vbar
        velocity: root.velocity
        // Sous la portée, à l'intérieur du panneau
        position: Qt.vector3d(0, -2.1, 0.8)
        scale: Qt.vector3d(Math.max(0.2, (velocity / 127.0) * 4.5), 0.14, 0.2)
    }

    BendMeter3D {
        id: bmeter
        bend: root.bend
        center: root.bendCenter
        // À droite, dans le panneau
        position: Qt.vector3d(4.3, 0, 0.8)
        scale: Qt.vector3d(0.18, 2.0, 0.2)
    }

    
}


