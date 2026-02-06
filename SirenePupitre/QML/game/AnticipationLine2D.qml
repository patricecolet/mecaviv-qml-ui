import QtQuick
import "../components/ambitus"
import "GameSequencer.js" as GameSequencer

/**
 * Ligne d'anticipation 2D : segments « fin de note N → début de note N+1 ».
 *
 * Chaque note en chute est un rectangle qui tombe. À l'instant t :
 *   - bottomY (bas, note-on) = cursorBarY - fallSpeed × (remainingMs / 1000)
 *   - topY (haut, note-off)  = bottomY - noteHeight
 *
 * La ligne relie :
 *   - fin de note N   = (noteToX(N), topY_N)       ← haut du rectangle N
 *   - début de note N+1 = (noteToX(N+1), bottomY_N+1) ← bas du rectangle N+1
 *
 * Même repère que MelodicLine2D / FallingNote2D. Repeater à taille fixe
 * pour éviter les problèmes de modèle dynamique.
 */
Item {
    id: root

    NotePositionCalculator2D {
        id: noteCalc2D
    }

    property var lineSegments: []
    property real currentNoteMidi: 60.0
    property real currentTimeMs: 0
    property real fallSpeed: 150
    property real fixedFallTime: 5000

    property real lineSpacing: 20
    property real ambitusMin: 48.0
    property real ambitusMax: 84.0
    property real staffWidth: 1600
    property real staffPosX: 0
    property real ambitusOffset: 0
    property real centerY: height / 2
    property real cursorOffsetY: 30
    property int octaveOffset: 0
    property string clef: "treble"

    property color lineColor: Qt.rgba(0, 1, 1, 0.85)
    property real lineWidth: 2.5

    // Temps lissé pour éviter les vibrations des segments.
    // SmoothedAnimation suit la cible sans redémarrage, à vitesse constante,
    // contrairement à NumberAnimation qui crée des oscillations de vitesse
    // quand on la relance toutes les 50 ms.
    property real smoothedTimeMs: currentTimeMs
    Behavior on smoothedTimeMs {
        SmoothedAnimation {
            duration: 80
        }
    }

    readonly property real _ambitusMarginX: lineSpacing * 2
    readonly property real _ambitusStartX: staffPosX + ambitusOffset + _ambitusMarginX
    readonly property real _ambitusWidth: (staffWidth - ambitusOffset) - _ambitusMarginX * 2
    readonly property real _firstNoteY: noteCalc2D.calculateNoteY(ambitusMin + (octaveOffset * 12), lineSpacing, clef)
    readonly property real cursorBarY: centerY + _firstNoteY + cursorOffsetY

    function noteToX(note) {
        var flooredMin = Math.floor(ambitusMin)
        var ceiledMax = Math.ceil(ambitusMax)
        return noteCalc2D.calculateNoteX2D(note, flooredMin, ceiledMax, _ambitusStartX, _ambitusWidth)
    }

    // Tableau de points (x, y) pour chaque segment dans la fenêtre :
    //   [0] = { endX, endY }   (fin de seg 0 = topY du rectangle 0)
    //   [1] = { startX, startY, endX, endY }   (début et fin de seg 1)
    //   ...
    // Pré-calculé pour que le Repeater n'ait qu'à lire par index.
    readonly property var _segPoints: {
        var segs = root.lineSegments || []
        if (segs.length === 0) return []
        var barY = root.cursorBarY
        var pts = []
        for (var i = 0; i < segs.length && i < 15; i++) {
            var seg = segs[i]
            if (seg.note === undefined) continue
            var remainMs = GameSequencer.calculateFallDurationMs(seg.timestamp, root.smoothedTimeMs, root.fixedFallTime)
            var bottomY = barY - (root.fallSpeed * (remainMs / 1000))
            var dur = seg.duration || 500
            var noteH = Math.max(18, (dur / 1000) * root.fallSpeed)
            var topY = bottomY - noteH
            var nx = noteToX(seg.note)
            pts.push({ startX: nx, startY: bottomY, endX: nx, endY: topY })
        }
        return pts
    }

    // Repeater à taille fixe : 14 segments max (paire i → i+1)
    // Chaque delegate trace une ligne de la FIN de note i au DÉBUT de note i+1.
    Repeater {
        model: 14
        delegate: Rectangle {
            required property int index
            // Données : fin de note[index] → début de note[index+1]
            readonly property bool hasData: index + 1 < root._segPoints.length
            readonly property var ptA: hasData ? root._segPoints[index] : null
            readonly property var ptB: hasData ? root._segPoints[index + 1] : null
            // Fin de note A = topY (haut du rectangle A)
            readonly property real ax: ptA ? ptA.endX : 0
            readonly property real ay: ptA ? ptA.endY : 0
            // Début de note B = bottomY (bas du rectangle B)
            readonly property real bx: ptB ? ptB.startX : 0
            readonly property real by: ptB ? ptB.startY : 0

            readonly property real dx: bx - ax
            readonly property real dy: by - ay
            readonly property real len: Math.sqrt(dx * dx + dy * dy)
            readonly property real angleDeg: Math.atan2(dy, dx) * 180 / Math.PI

            visible: hasData && len > 0.5
            x: ax
            y: ay - root.lineWidth / 2
            width: len
            height: root.lineWidth
            radius: root.lineWidth / 2
            color: root.lineColor
            opacity: Math.max(0.2, 1.0 - index * 0.06)
            transformOrigin: Item.Left
            rotation: angleDeg
        }
    }
}
