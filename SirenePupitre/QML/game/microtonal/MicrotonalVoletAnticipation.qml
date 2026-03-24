pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

/**
 * Gauche : bleu = volet réel (vélocité) ; trait jaune = cible d’ouverture consigne suivante.
 * Droite : fenêtre anticipation ; chaque note = rectangle jaune qui défile de droite à gauche (playhead = bord gauche).
 */
RowLayout {
    id: root
    spacing: 10

    /** 0–1 ouverture volet réelle (ex. vélocité /127) */
    property real currentOpen: 0
    /** 0–1 cible volet de la prochaine consigne (repère jaune) */
    property real nextOpen: 0
    /** Segments { leftNorm, widthNorm, heightNorm } : largeur = temps, hauteur 0–1 = ouverture volet (vélocité). */
    property var noteSegments: []
    property real anticipationWindowMs: 5000
    property bool showAnticipationLane: true

    MicrotonalVoletIndicator {
        Layout.preferredWidth: 120
        openAmount: root.currentOpen
        targetMarker: root.showAnticipationLane ? root.nextOpen : -1
        showLabel: false
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        visible: root.showAnticipationLane

        Rectangle {
            id: trackBg
            anchors.fill: parent
            radius: 4
            color: "#2a2a2a"
            border.color: "#555"
            border.width: 1
            clip: true

            Repeater {
                model: root.noteSegments || []
                delegate: Rectangle {
                    required property var modelData
                    anchors.bottom: parent.bottom
                    readonly property real segW: parent.width * (modelData ? modelData.widthNorm : 0)
                    readonly property real hNorm: {
                        if (!modelData || modelData.heightNorm === undefined)
                            return 0.5
                        return Math.max(0, Math.min(1, modelData.heightNorm))
                    }
                    x: parent.width * (modelData ? modelData.leftNorm : 0)
                    width: Math.max(0, segW)
                    height: Math.max(1, parent.height * hNorm)
                    radius: 4
                    color: "#FFD700"
                    opacity: 0.9
                    visible: modelData && modelData.widthNorm > 1e-9 && hNorm > 1e-6
                }
            }
        }
    }
}
