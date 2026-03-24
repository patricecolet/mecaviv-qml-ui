import QtQuick
import QtQuick.Layouts
import "."

/**
 * Vue dirigée / lecture : symboles (MicrotonalScoreView), pas de phrases en zone principale.
 */
ColumnLayout {
    id: root
    spacing: 0
    anchors.fill: parent

    property var viewModel: null

    MicrotonalScoreView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 200
        viewModel: root.viewModel
    }
}
