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

    readonly property var _spec: SirenSpec.SPEC

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
