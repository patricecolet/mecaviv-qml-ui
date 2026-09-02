pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Un motif du séquenceur, vu comme une bande de temps.
// Chaque pas est une barre : sa position dit quand, sa largeur combien de temps
// (le gate), sa hauteur la vélocité, et son décalage vertical l'intervalle en
// demi-tons ajouté à la note tenue. Attack et release se lisent sous la barre.
Item {
    id: root

    // steps[i] = { tick, velocite, hauteur, gate, attack, release }
    property var steps: []
    property int lengthTicks: 1920
    property int seqIndex: 0
    property bool actif: false

    readonly property int _ticksParMesure: 1920
    readonly property int _demiTons: 12          // amplitude verticale, ±12

    function _x(tick)  { return grille.width * (tick / Math.max(1, lengthTicks)); }
    function _w(gate)  { return Math.max(3, grille.width * (gate / Math.max(1, lengthTicks))); }
    function _y(haut)  { return grille.height * (0.5 - haut / (2 * _demiTons)); }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                text: root.seqIndex > 0 ? "séquence " + root.seqIndex : "aucune séquence"
                color: root.actif ? "#FFFFFF" : "#64737F"
                font.family: "monospace"; font.pixelSize: 13; font.bold: true
            }
            Text {
                text: (root.lengthTicks / root._ticksParMesure).toFixed(2) + " mesure"
                      + (root.lengthTicks > root._ticksParMesure ? "s" : "")
                color: "#3B4855"; font.family: "monospace"; font.pixelSize: 10
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.steps.length + " pas"
                color: "#3B4855"; font.family: "monospace"; font.pixelSize: 10
            }
        }

        Rectangle {
            id: grille
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0E141B"
            border.color: "#171F28"
            border.width: 1
            clip: true

            // la ligne d'unisson : hauteur 0, la note telle qu'elle est tenue
            Rectangle {
                x: 0; width: parent.width
                y: root._y(0); height: 1
                color: "#232E3A"
            }

            // une graduation par temps (480 ticks)
            Repeater {
                model: Math.max(1, Math.floor(root.lengthTicks / 480))
                delegate: Rectangle {
                    required property int index
                    x: root._x((index + 1) * 480)
                    y: 0; width: 1; height: grille.height
                    color: ((index + 1) % 4 === 0) ? "#243040" : "#1A2230"
                }
            }

            Repeater {
                model: root.steps
                delegate: Rectangle {
                    id: barre
                    required property var modelData
                    readonly property real _v: Math.max(1, Math.min(127, modelData.velocite))
                    x: root._x(modelData.tick)
                    width: root._w(modelData.gate)
                    height: Math.max(2, (grille.height * 0.42) * (_v / 127))
                    y: root._y(modelData.hauteur) - height / 2
                    radius: 1
                    color: root.actif ? "#6699FF" : "#39506E"
                    opacity: 0.55 + 0.45 * (_v / 127)

                    // l'intervalle, quand il n'est pas nul
                    Text {
                        visible: barre.modelData.hauteur !== 0 && barre.width > 16
                        anchors.centerIn: parent
                        text: (barre.modelData.hauteur > 0 ? "+" : "") + barre.modelData.hauteur
                        color: "#0E141B"
                        font.family: "monospace"; font.pixelSize: 9; font.bold: true
                    }
                }
            }

            Text {
                visible: root.steps.length === 0
                anchors.centerIn: parent
                text: "motif vide"
                color: "#2A3543"; font.family: "monospace"; font.pixelSize: 11
            }
        }

        // l'enveloppe de chaque pas, alignée sous sa barre
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 16
            Repeater {
                model: root.steps
                delegate: Text {
                    required property var modelData
                    x: root._x(modelData.tick)
                    text: "a" + modelData.attack + " r" + modelData.release
                    color: "#3B4855"
                    font.family: "monospace"; font.pixelSize: 9
                }
            }
        }
    }
}
