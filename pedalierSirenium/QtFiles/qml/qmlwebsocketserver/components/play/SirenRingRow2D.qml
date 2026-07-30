pragma ComponentBehavior: Bound

import QtQuick
import "../../sirenSpec.js" as SirenSpec

// Les sept sirènes, en ordre d'étiquette (stable). Chaque anneau : couleur = identité,
// progression = temps, halo = enregistrement, opacité = présence.
// Le centre porte l'identité et une ligne d'état neutre (mot ou rapport).
Item {
    id: root

    // 7 entrées : { progress, halo (bool), haloOpacity, meta (string), present (0..1) }
    property var states: []

    // Sirène mise en mono par la pédale key (1..7, 0 = aucune). Marquée par une
    // forme sous l'anneau : la couleur dit déjà qui, la forme dit quoi.
    property int selectedSiren: 0

    // 7 entrées : { note, velocity, attacks } — ce que chaque sirène joue, reçu
    // par le canal binaire (immédiat, non lissé). Voir LiveState.applyMidi.
    property var midi: []

    readonly property var _spec: SirenSpec.SPEC

    // Convention française, Do3 = MIDI 60 — comme SireniumMonitor2D.
    readonly property var _names: ["Do", "Do♯", "Ré", "Ré♯", "Mi", "Fa", "Fa♯", "Sol", "Sol♯", "La", "La♯", "Si"]

    Row {
        id: row
        anchors.fill: parent
        spacing: 10

        Repeater {
            model: 7
            delegate: Item {
                id: cell
                required property int index
                width: (root.width - row.spacing * 6) / 7
                height: root.height

                readonly property var _s: root._spec["siren" + (index + 1)] || ({})
                readonly property color _color: _s.color || "#FFFFFF"
                readonly property var _state: (root.states && root.states[index]) ? root.states[index] : ({})

                // Ce que joue cette sirène. `attackCount` sans souligné : c'est lui
                // qui porte le handler d'animation (onAttackCountChanged).
                readonly property var _midi: (root.midi && root.midi[index]) ? root.midi[index] : ({})
                readonly property int _velocity: cell._midi.velocity !== undefined ? cell._midi.velocity : 0
                readonly property bool _sounding: cell._velocity > 1   // 1 = note fantôme, moteur muet
                // La note fantôme reste VISIBLE, en atténué : une sirène parquée est
                // prête, moteur en rotation à cette hauteur, et c'est une information
                // de jeu. Seule l'opacité distingue « ça sonne » de « c'est prêt ».
                readonly property string _noteText: cell._velocity > 0
                    ? root._names[((cell._midi.note % 12) + 12) % 12] + " " + (Math.floor(cell._midi.note / 12) - 2)
                    : ""
                readonly property int attackCount: cell._midi.attacks !== undefined ? cell._midi.attacks : 0

                onAttackCountChanged: pulse.restart()

                opacity: (_state.present !== undefined) ? _state.present : 1.0

                // Cerclage de la sirène principale : sa propre couleur, donc rien
                // de neuf à décoder — c'est le second cercle qui dit « c'est elle ».
                Rectangle {
                    anchors.centerIn: ring
                    width: ring.width + 12
                    height: width
                    radius: width / 2
                    visible: root.selectedSiren === cell.index + 1
                    color: "transparent"
                    border.width: 1.5
                    border.color: cell._color
                    opacity: 0.75
                }

                // Pulsation d'attaque : un cercle qui s'écarte brièvement à chaque
                // Note On. Distinct du halo de Ring2D, qui dit l'enregistrement —
                // deux informations, deux formes.
                Rectangle {
                    id: pulseRing
                    anchors.centerIn: ring
                    width: ring.width
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: cell._color
                    opacity: 0

                    SequentialAnimation {
                        id: pulse
                        PropertyAction { target: pulseRing; property: "scale"; value: 1.0 }
                        PropertyAction { target: pulseRing; property: "opacity"; value: 0.9 }
                        ParallelAnimation {
                            NumberAnimation { target: pulseRing; property: "scale"; to: 1.35; duration: 260; easing.type: Easing.OutCubic }
                            NumberAnimation { target: pulseRing; property: "opacity"; to: 0; duration: 260; easing.type: Easing.OutCubic }
                        }
                    }
                }

                Ring2D {
                    id: ring
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 0
                    width: Math.min(cell.width, cell.height - 14)
                    height: width
                    lineWidth: 5
                    ringColor: cell._color
                    progress: cell._state.progress !== undefined ? cell._state.progress : 0
                    showHalo: cell._state.halo === true
                    haloOpacity: cell._state.haloOpacity !== undefined ? cell._state.haloOpacity : 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell._s.label || ("S" + (cell.index + 1))
                            color: cell._color
                            font.family: "monospace"
                            font.pixelSize: Math.max(12, ring.width * 0.18)
                            font.bold: true
                        }
                        // La note jouée. Hauteur réservée même à vide : la ligne
                        // meta ne doit pas monter et descendre au fil du jeu.
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell._noteText
                            color: "#FFFFFF"
                            opacity: cell._sounding ? 1.0 : 0.45
                            font.family: "monospace"
                            font.pixelSize: Math.max(9, ring.width * 0.11)
                            font.bold: true
                            height: Math.max(9, ring.width * 0.11) * 1.3
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell._state.meta || ""
                            color: "#64737F"
                            font.family: "monospace"
                            font.pixelSize: Math.max(8, ring.width * 0.09)
                        }
                    }
                }
            }
        }
    }
}
