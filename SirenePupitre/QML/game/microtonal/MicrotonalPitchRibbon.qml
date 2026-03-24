import QtQuick

/**
 * Ruban type accordeur : repère tempéré (centre), cible micro (tick), position actuelle (curseur).
 * centsTemperedAnchor = 0 au centre ; targetCents et currentCents en ±cents dans [-rangeCents, rangeCents].
 */
Item {
    id: root
    implicitHeight: 56
    implicitWidth: 320

    property real targetCents: 12
    property real currentCents: 3
    property real rangeCents: 100
    /** Note d'arrivée du glissando en cents (même référence que targetCents). NaN = inactif. */
    property real glissTargetCents: NaN

    property color trackColor: "#333"
    property color centerColor: "#6bb6ff"
    property color targetColor: "#FFD700"
    property color cursorOffTargetColor: "#ff4d4f"
    property color cursorOnTargetColor: "#4ade80"
    property real onTargetToleranceCents: 5
    readonly property bool onTarget: Math.abs(root.currentCents - root.targetCents) <= Math.max(0, root.onTargetToleranceCents)

    function normC(c) {
        var r = Math.max(1, root.rangeCents)
        return Math.max(-1, Math.min(1, c / r))
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: root.trackColor
        border.color: "#555"
        border.width: 1
    }

    // Centre = tempéré
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 3
        radius: 1
        color: root.centerColor
    }

    // Cible micro (note de départ de la consigne)
    Rectangle {
        width: 4
        height: parent.height - 8
        anchors.verticalCenter: parent.verticalCenter
        x: parent.width / 2 + root.normC(root.targetCents) * (parent.width / 2 - 12) - width / 2
        radius: 2
        color: root.targetColor
    }

    // Flèche d'arrivée du glissando (tirets + pastille)
    Item {
        visible: !isNaN(root.glissTargetCents) && isFinite(root.glissTargetCents)
        anchors.verticalCenter: parent.verticalCenter
        readonly property real _xCenter: parent.width / 2
                + root.normC(root.glissTargetCents) * (parent.width / 2 - 12)

        // Ligne en tirets (simulée par deux rectangles)
        Rectangle {
            x: parent._xCenter - 1
            y: 0
            width: 2
            height: (parent.parent.height - 8) * 0.45
            color: "#4ade80"
            opacity: 0.9
            radius: 1
        }
        Rectangle {
            x: parent._xCenter - 1
            y: (parent.parent.height - 8) * 0.55
            width: 2
            height: (parent.parent.height - 8) * 0.45
            color: "#4ade80"
            opacity: 0.9
            radius: 1
        }
        // Pastille ronde sur la cible d'arrivée
        Rectangle {
            x: parent._xCenter - 5
            y: parent.parent.height / 2 - 5
            width: 10
            height: 10
            radius: 5
            color: "transparent"
            border.color: "#4ade80"
            border.width: 2
        }
    }

    // Curseur actuel
    Rectangle {
        width: 10
        height: parent.height - 4
        anchors.verticalCenter: parent.verticalCenter
        x: parent.width / 2 + root.normC(root.currentCents) * (parent.width / 2 - 14) - width / 2
        radius: 3
        color: root.onTarget ? root.cursorOnTargetColor : root.cursorOffTargetColor
        border.color: "#fff"
        border.width: 1
    }
}
