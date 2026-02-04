import QtQuick
import "../utils"

/**
 * Note en chute 2D — Option A : Canvas + gradient, animation de chute manuelle.
 * Même API que FallingNoteCustomGeo (targetX, targetY, fallSpeed, fixedFallTime,
 * velocity, duration, attack/release, vibrato/tremolo). L'esthétique 2D (forme,
 * gradient, modulation visuelle) sera affinée et validée étape par étape.
 */
Item {
    id: root

    MusicUtils {
        id: musicUtils
    }

    // API compatible avec FallingNoteCustomGeo (coordonnées 2D en pixels)
    property real targetY: 0
    property real targetX: 0
    // Debug : affiche le nom de note (Do3, etc.) si >= 0
    property real midiNote: -1
    property real fallSpeed: 150
    property real fixedFallTime: 5000
    // Si > 0 : durée de chute en ms (séquenceur lookahead) — la note atteint le curseur à temps
    property real fallDurationMs: 0

    property color cubeColor: "#00CED1"
    property real velocity: 127
    property real duration: 1000
    property real attackTime: 0
    property real releaseTime: 0

    property real vibratoAmount: 0.0
    property real vibratoRate: 5.0
    property real tremoloAmount: 0.0
    property real tremoloRate: 4.0

    // Hauteurs en pixels. Minimum 18 px pour que les notes courtes restent visibles.
    readonly property real totalDurationHeight: Math.max(18, (duration / 1000.0) * fallSpeed)
    readonly property real releaseHeight: (releaseTime / 1000.0) * fallSpeed
    readonly property real totalHeight: totalDurationHeight + releaseHeight

    // bottomY = position du bas de la note (note on), qui doit atteindre targetY
    // spawnY = position initiale du bas de la note
    readonly property real spawnY: targetY - (fallSpeed * (fallDurationMs / 1000))
    property real bottomY: spawnY

    // Largeur visuelle (liée à la vélocité)
    readonly property real noteWidth: 16 + (velocity / 127) * 16

    x: targetX - noteWidth / 2
    y: bottomY - totalHeight  // Le haut de la note = bas - hauteur totale
    width: noteWidth
    height: totalHeight

    // Animation : le bas de la note tombe de spawnY à targetY + totalHeight (pour que toute la note passe)
    NumberAnimation on bottomY {
        id: fallAnimation
        from: root.spawnY
        to: root.targetY + root.totalHeight
        duration: root.fallDurationMs + (root.totalHeight / root.fallSpeed * 1000)
        running: false
        onFinished: root.destroy()
    }

    // Debug : libellé note (Do3, etc.) au-dessus du bloc
    Text {
        visible: root.midiNote >= 0
        text: musicUtils.midiToNoteName(root.midiNote)
        font.pixelSize: Math.max(10, root.noteWidth * 0.6)
        color: "#FFFFFF"
        style: Text.Outline
        styleColor: "#000000"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 2
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width
            var h = height
            // Gradient vertical : plus clair en haut (attack), couleur en bas (sustain)
            var grad = ctx.createLinearGradient(0, 0, 0, h)
            var c = root.cubeColor
            grad.addColorStop(0, Qt.rgba(c.r * 1.2, c.g * 1.2, c.b * 1.2, 0.9))
            grad.addColorStop(0.3, Qt.rgba(c.r, c.g, c.b, 1))
            grad.addColorStop(1, Qt.rgba(c.r * 0.8, c.g * 0.8, c.b * 0.8, 0.95))
            ctx.fillStyle = grad
            ctx.fillRect(0, 0, w, h)
        }
    }

    Component.onCompleted: {
        fallAnimation.start()
    }
}
