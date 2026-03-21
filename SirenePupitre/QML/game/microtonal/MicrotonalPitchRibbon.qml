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

    property color trackColor: "#333"
    property color centerColor: "#6bb6ff"
    property color targetColor: "#FFD700"
    property color cursorColor: "#4ade80"

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

    // Cible micro
    Rectangle {
        width: 4
        height: parent.height - 8
        anchors.verticalCenter: parent.verticalCenter
        x: parent.width / 2 + root.normC(root.targetCents) * (parent.width / 2 - 12) - width / 2
        radius: 2
        color: root.targetColor
    }

    // Curseur actuel
    Rectangle {
        width: 10
        height: parent.height - 4
        anchors.verticalCenter: parent.verticalCenter
        x: parent.width / 2 + root.normC(root.currentCents) * (parent.width / 2 - 14) - width / 2
        radius: 3
        color: root.cursorColor
        border.color: "#fff"
        border.width: 1
    }
}
