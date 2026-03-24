import QtQuick
import QtQuick.Layouts
import "."

/**
 * Séquencé quantifié : symboles + anticipation volet + consignes texte en bas (pas de rail temporel).
 */
ColumnLayout {
    id: root
    spacing: 0
    anchors.fill: parent

    property var viewModel: null

    MicrotonalScoreView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        viewModel: root.viewModel
    }
}
