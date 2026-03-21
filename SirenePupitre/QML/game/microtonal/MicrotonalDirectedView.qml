import QtQuick
import QtQuick.Layouts
import "."

ColumnLayout {
    id: root
    spacing: 10
    anchors.fill: parent

    property var viewModel: null

    // ── Panneau ruban + indicateurs instantanés ──────────────────────────
    MicrotonalPitchPanel {
        Layout.fillWidth: true
        viewModel: root.viewModel
    }

    // ── Espace flexible : pousse la phase strip vers le bas ──────────────
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 16
    }

    // ── Indicateur de phase, juste au-dessus des consignes ───────────────
    MicrotonalPhaseStrip {
        Layout.fillWidth: true
        phase: root.viewModel ? root.viewModel.phase : 0
    }

    // ── Rectangle de consignes du chef ───────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(72, conductorText.implicitHeight + 16)
        radius: 4
        color: "#252525"
        border.color: "#555"
        border.width: 1
        Text {
            id: conductorText
            anchors.fill: parent
            anchors.margins: 8
            wrapMode: Text.WordWrap
            text: root.viewModel ? root.viewModel.conductorCue : ""
            color: "#ddd"
            font.pixelSize: 13
        }
    }
}
