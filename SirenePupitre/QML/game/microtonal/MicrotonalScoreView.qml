pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../utils"

/**
 * Zone de jeu microtonale : symboles (pas de phrases), anticipation volet, texte en bas.
 */
ColumnLayout {
    id: root
    spacing: 4
    /** Parent = cellule ColumnLayout : pas d’anchors (Layout gère la taille). */
    width: parent ? parent.width : implicitWidth
    height: parent ? parent.height : implicitHeight

    property var viewModel: null

    MusicUtils {
        id: mu
    }

    readonly property real midiFloat: {
        if (!root.viewModel)
            return 69
        return root.viewModel.midiAnchor + root.viewModel.targetCents / 100.0
    }

    readonly property real glissTargetMidiFloat: root.viewModel ? root.viewModel.glissTargetMidi : -1
    readonly property bool hasGlissTarget: root.glissTargetMidiFloat >= 0

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 8
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 200
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: "Glissando: " + (root.viewModel ? root.viewModel.glissSpeedLabel : "—")
                color: "#9ad4a8"
                font.pixelSize: 14
                font.bold: true
                font.family: "monospace"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            MicrotonalPitchRibbon {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                targetCents: root.viewModel ? root.viewModel.targetCents : 0
                currentCents: root.viewModel ? root.viewModel.currentCents : 0
                rangeCents: 100
                glissTargetCents: root.hasGlissTarget
                    ? (root.glissTargetMidiFloat - (root.viewModel ? root.viewModel.midiAnchor : 69)) * 100.0
                    : NaN
            }
        }

        Column {
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            // Note de départ (consigne courante)
            Text {
                text: mu.midiToNoteName(Math.round(root.midiFloat))
                color: "#FFD700"
                font.pixelSize: root.hasGlissTarget ? 32 : 44
                font.bold: true
                font.family: "monospace"
            }

            // Note d'arrivée du glissando
            Row {
                visible: root.hasGlissTarget
                spacing: 4
                Text {
                    text: "\u2192"
                    color: "#4ade80"
                    font.pixelSize: 22
                    font.bold: true
                    font.family: "monospace"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.hasGlissTarget ? mu.midiToNoteName(Math.round(root.glissTargetMidiFloat)) : ""
                    color: "#4ade80"
                    font.pixelSize: 32
                    font.bold: true
                    font.family: "monospace"
                }
            }

            MicrotonalCentsReadout {
                cents: root.viewModel ? root.viewModel.targetCents : 0
                showDeltaLabel: false
                implicitHeight: 48
                implicitWidth: 120
            }
        }
    }

    MicrotonalVoletAnticipation {
        Layout.fillWidth: true
        currentOpen: root.viewModel ? root.viewModel.voletOpenLive : 0
        nextOpen: root.viewModel ? root.viewModel.sequencedNextVoletOpen : 0
        noteSegments: root.viewModel && root.viewModel.sequencedNoteSegments
                ? root.viewModel.sequencedNoteSegments : []
        showAnticipationLane: root.viewModel
                && root.viewModel.subMode === 1
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 188
        color: "#111"
        radius: 6
        border.color: "#333"
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 2

            Row {
                width: parent.width
                height: 18
                spacing: 8
                Text {
                    width: 72
                    text: "Mesure"
                    color: "#666"
                    font.pixelSize: 10
                    font.family: "monospace"
                }
                Text {
                    width: 56
                    text: "Temps"
                    color: "#666"
                    font.pixelSize: 10
                    font.family: "monospace"
                }
                Text {
                    width: 56
                    text: "Tick"
                    color: "#666"
                    font.pixelSize: 10
                    font.family: "monospace"
                }
                Text {
                    width: parent.width - 72 - 56 - 56 - 24
                    text: "Texte"
                    color: "#666"
                    font.pixelSize: 10
                    font.family: "monospace"
                }
            }

            ScrollView {
                id: cueScroll
                width: parent.width
                height: parent.height - 22
                clip: true

                ListView {
                id: cueList
                width: cueScroll.availableWidth
                model: root.viewModel ? root.viewModel.cueBookLines : []
                spacing: 2
                delegate: Rectangle {
                    id: rowDelegate
                    required property var modelData
                    required property int index
                    readonly property var rowData: modelData
                    readonly property string measureCol: {
                        if (!rowDelegate.rowData)
                            return "—"
                        if (rowDelegate.rowData.measure !== undefined)
                            return String(rowDelegate.rowData.measure)
                        if (rowDelegate.rowData.pos !== undefined)
                            return String(rowDelegate.rowData.pos)
                        return "—"
                    }
                    readonly property string timeCol: rowDelegate.rowData && rowDelegate.rowData.time !== undefined
                            ? String(rowDelegate.rowData.time)
                            : "—"
                    readonly property string tickCol: {
                        if (!rowDelegate.rowData)
                            return "—"
                        if (rowDelegate.rowData.tick !== undefined)
                            return String(rowDelegate.rowData.tick)
                        var p = rowDelegate.rowData.pos !== undefined ? String(rowDelegate.rowData.pos) : ""
                        if (p.length > 1 && p.charAt(0) === "t") {
                            var rest = p.substring(1)
                            if (rest.length > 0 && !isNaN(Number(rest)))
                                return rest
                        }
                        return "—"
                    }
                    width: cueList.width
                    height: 26
                    color: index % 2 === 0 ? "#171717" : "#1d1d1d"
                    radius: 3

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 8
                        Text {
                            width: 72
                            text: rowDelegate.measureCol
                            color: "#6bb6ff"
                            font.pixelSize: 11
                            font.family: "monospace"
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: 56
                            text: rowDelegate.timeCol
                            color: "#9ad4a8"
                            font.pixelSize: 11
                            font.family: "monospace"
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: 56
                            text: rowDelegate.tickCol
                            color: "#c9a86c"
                            font.pixelSize: 11
                            font.family: "monospace"
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: parent.width - 72 - 56 - 56 - 24
                            text: rowDelegate.rowData && rowDelegate.rowData.text !== undefined ? String(rowDelegate.rowData.text) : ""
                            color: "#ddd"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
            }
        }
    }
}

