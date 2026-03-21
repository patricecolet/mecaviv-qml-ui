import QtQuick
import QtQuick.Controls
import "."

/**
 * Affichage microtonal partagé (mode normal et mode jeu).
 * layoutPreset "normal" : vue dirigée seule (pas de barre de sous-mode).
 * "game" : choix Séq. strict / Séq. continu + marges plus compactes.
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

        Row {
            id: modeToolbar
            visible: root.layoutPreset === "game"
            anchors.top: parent.top
            anchors.left: parent.left
            spacing: 8
            Text {
                text: "Séquence :"
                color: "#888"
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
            Button {
                text: "Séq. strict"
                highlighted: root.viewModel && root.viewModel.subMode === typesRef.modeSequencedStrict
                onClicked: if (root.viewModel) root.viewModel.subMode = typesRef.modeSequencedStrict
            }
            Button {
                text: "Séq. continu"
                highlighted: root.viewModel && root.viewModel.subMode === typesRef.modeSequencedContinuous
                onClicked: if (root.viewModel) root.viewModel.subMode = typesRef.modeSequencedContinuous
            }
        }

        Item {
            id: modeContent
            anchors.top: root.layoutPreset === "game" ? modeToolbar.bottom : parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: root.layoutPreset === "game" ? 8 : 0

            MicrotonalDirectedView {
                id: directedView
                anchors.fill: parent
                visible: root.viewModel && root.layoutPreset === "normal"
                viewModel: root.viewModel
            }
            MicrotonalSequencedStrictView {
                id: strictView
                anchors.fill: parent
                visible: root.viewModel && root.layoutPreset === "game"
                        && root.viewModel.subMode === typesRef.modeSequencedStrict
                viewModel: root.viewModel
            }
            MicrotonalSequencedContinuousView {
                id: continuousView
                anchors.fill: parent
                visible: root.viewModel && root.layoutPreset === "game"
                        && root.viewModel.subMode === typesRef.modeSequencedContinuous
                viewModel: root.viewModel
            }
        }
    }

    Component.onCompleted: {
        if (!root.viewModel)
            return
        var v = root.viewModel
        if (root.layoutPreset === "game") {
            if (v.subMode !== typesRef.modeSequencedStrict
                    && v.subMode !== typesRef.modeSequencedContinuous)
                v.subMode = typesRef.modeSequencedStrict
        }
    }
}
