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

    // Hauteurs en pixels (même formules que 3D)
    readonly property real fixedDistance: fallSpeed * (fixedFallTime / 1000)
    readonly property real totalDurationHeight: Math.max(0.1, (duration / 1000.0) * fallSpeed)
    readonly property real releaseHeight: Math.max(0.05, (releaseTime / 1000.0) * fallSpeed)
    readonly property real totalHeight: totalDurationHeight + releaseHeight

    readonly property real spawnY: fallDurationMs > 0
        ? (targetY + totalHeight / 2 - (fallSpeed * (fallDurationMs / 1000)))
        : (targetY - fixedDistance - totalHeight / 2)
    property real currentY: spawnY

    // Troncature monophonique : hauteur visible depuis le bas (coordonnée locale comme en 3D)
    property real clipYTopLocal: totalDurationHeight / 2.0 + releaseHeight + 100

    // Largeur visuelle (esthétique à affiner : pour l'instant liée à la vélocité)
    readonly property real noteWidth: 16 + (velocity / 127) * 16

    readonly property real _visibleHeight: Math.min(totalHeight, Math.max(0, clipYTopLocal + totalHeight / 2))
    readonly property real _drawY: currentY + totalHeight / 2 - _visibleHeight

    x: targetX - noteWidth / 2
    y: _drawY
    width: noteWidth
    height: _visibleHeight

    function truncateNote(atLocalY) {
        clipYTopLocal = atLocalY
    }

    // Chute : durée = fallDurationMs si séquenceur, sinon fixedFallTime + déplacement
    readonly property real _fallDuration: root.fallDurationMs > 0
        ? root.fallDurationMs
        : (root.fixedFallTime + (root.totalHeight / root.fallSpeed * 1000))
    NumberAnimation on currentY {
        id: fallAnimation
        from: root.spawnY
        to: root.targetY + root.totalHeight / 2
        duration: root._fallDuration
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
