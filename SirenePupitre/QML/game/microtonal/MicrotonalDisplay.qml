import QtQuick
import "."

/**
 * Affichage microtonal partagé (mode normal et mode jeu).
 * layoutPreset "normal" : vue dirigée seule.
 * "game" : vue séquencée (une seule implémentation) + marges plus compactes.
 */
Item {
    id: root
    anchors.fill: parent

    property var viewModel: null
    /** "normal" | "game" */
    property string layoutPreset: "normal"

    readonly property int _margin: root.layoutPreset === "game" ? 8 : 16

    MicrotonalTypes {
        id: typesRef
    }

    Item {
        anchors.fill: parent
        anchors.margins: root._margin

        Item {
            id: modeContent
            anchors.fill: parent

            MicrotonalDirectedView {
                id: directedView
                anchors.fill: parent
                visible: root.viewModel && root.layoutPreset === "normal"
                viewModel: root.viewModel
            }
            MicrotonalSequencedStrictView {
                id: sequencedView
                anchors.fill: parent
                visible: root.viewModel && root.layoutPreset === "game"
                        && root.viewModel.subMode === typesRef.modeSequencedStrict
                viewModel: root.viewModel
            }
        }
    }

    Component.onCompleted: {
        if (!root.viewModel)
            return
        var v = root.viewModel
        if (root.layoutPreset === "game") {
            if (v.subMode === 2)
                v.subMode = typesRef.modeSequencedStrict
            if (v.subMode !== typesRef.modeSequencedStrict)
                v.subMode = typesRef.modeSequencedStrict
        }
    }
}
