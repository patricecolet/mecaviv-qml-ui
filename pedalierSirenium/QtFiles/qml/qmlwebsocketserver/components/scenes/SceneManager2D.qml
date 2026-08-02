import QtQuick
import QtQuick.Layouts
import "../play"
import "../../sirenSpec.js" as SirenSpec

// Gestion des scènes, au doigt. On touche pour désigner, jamais pour lancer :
// charger une scène change ce qui sonne, ça reste un geste explicite.
// Deux granularités de sélection — la scène entière, ou une de ses 7 cellules —
// et le presse-papier suit celle qui est active.
Item {
    id: root

    // sections : [{ id, btn, name, modes:[7], cells:[{mode, clipRef}], current, past }]
    property var sections: []
    property string compName: "—"

    signal closed()
    signal newScene()
    signal loadScene(int n)
    signal renameScene(int n, string name)
    signal deleteScene(int n)
    signal copyScene(int src, int dst)
    signal copyCell(int src, int dst, int siren)

    // --- sélection ---
    property int selIndex: 0                       // index dans sections
    property int selSiren: 0                       // 0 = la scène entière, 1..7 = une cellule
    // --- presse-papier ---
    property var clip: null                        // { kind: "scene"|"cell", id, siren, label }
    property bool armDelete: false

    readonly property var _spec: SirenSpec.SPEC
    readonly property var sel: (selIndex >= 0 && selIndex < sections.length) ? sections[selIndex] : null

    onSectionsChanged: {
        if (selIndex >= sections.length) selIndex = Math.max(0, sections.length - 1);
        armDelete = false;
    }

    function _select(i, siren) {
        selIndex = i;
        selSiren = siren;
        armDelete = false;
    }

    function _copy() {
        if (!sel) return;
        if (selSiren > 0) {
            clip = { kind: "cell", id: sel.id, siren: selSiren,
                     label: "S" + selSiren + " de « " + (sel.name || "sans nom") + " »" };
        } else {
            clip = { kind: "scene", id: sel.id, siren: 0,
                     label: "scène « " + (sel.name || "sans nom") + " »" };
        }
    }

    function _paste() {
        if (!clip || !sel) return;
        if (clip.kind === "cell") {
            // Un clip enregistré sur une sirène l'a été dans son ambitus : il se
            // repose sur la même sirène, jamais sur une autre (SCENES_SPEC §19).
            var siren = selSiren > 0 ? selSiren : clip.siren;
            root.copyCell(clip.id, sel.id, siren);
        } else {
            root.copyScene(clip.id, sel.id);
        }
    }

    readonly property bool canPaste: clip !== null && sel !== null
                                     && !(clip.kind === "scene" && clip.id === sel.id)

    Rectangle { anchors.fill: parent; color: "#0A0D11" }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        // ---- en-tête ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            ColumnLayout {
                spacing: 4
                Text { text: "SCÈNES — PETIT PÉDALIER"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.5 }
                Text { text: root.compName; color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 22; font.bold: true }
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: root.clip !== null
                text: "PRESSE-PAPIER · " + (root.clip ? root.clip.label : "")
                color: "#66E4F2"; font.family: "monospace"; font.pixelSize: 11
                Layout.alignment: Qt.AlignVCenter
            }

            ActionButton {
                label: "RETOUR"; wide: true
                onActivated: root.closed()
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: "#171F28" }

        // ---- la grille des scènes ----
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: grid.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Flow {
                id: grid
                width: parent.width
                spacing: 12

                Repeater {
                    model: root.sections
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property var sc: modelData
                        readonly property bool picked: index === root.selIndex

                        // quatre par rangée : la tuile doit rester une cible au doigt,
                        // pas une vignette. Les cellules en héritent.
                        width: (grid.width - 3 * 12) / 4
                        height: 172
                        radius: 4
                        color: picked ? "#1B242E" : "#151D26"
                        border.width: picked ? 2 : 1
                        border.color: picked ? "#66E4F2" : (sc.current ? "#3B4855" : "#171F28")

                        // toucher la tuile ailleurs que sur une cellule = la scène entière
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root._select(tile.index, 0)
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            RowLayout {
                                width: parent.width
                                Text {
                                    text: tile.sc.btn
                                    color: tile.picked ? "#FFFFFF" : "#64737F"
                                    font.family: "monospace"; font.pixelSize: 34; font.bold: true
                                }
                                Item { Layout.fillWidth: true }
                                // la scène chargée en ce moment
                                Rectangle {
                                    visible: tile.sc.current === true
                                    implicitWidth: 8; implicitHeight: 8; radius: 4; color: "#FFFFFF"
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            Text {
                                width: parent.width
                                text: tile.sc.name || "sans nom"
                                color: tile.sc.name ? (tile.picked ? "#C7D2DC" : "#64737F") : "#2A3742"
                                elide: Text.ElideRight
                                font.family: "monospace"; font.pixelSize: 15
                            }

                            Item { width: 1; height: 10 }

                            // les 7 cellules — cibles tactiles élargies autour de la marque
                            Row {
                                spacing: 2
                                Repeater {
                                    model: 7
                                    delegate: Item {
                                        required property int index
                                        readonly property int siren: index + 1
                                        readonly property bool pickedCell: tile.picked && root.selSiren === siren
                                        width: (tile.width - 24 - 12) / 7
                                        height: 52

                                        Rectangle {
                                            visible: pickedCell
                                            anchors.fill: parent
                                            radius: 3
                                            color: "transparent"
                                            border.width: 1; border.color: "#66E4F2"
                                        }

                                        ModeMark2D {
                                            anchors.centerIn: parent
                                            scale: 1.7
                                            mode: (tile.sc.modes && tile.sc.modes[index]) ? tile.sc.modes[index] : "empty"
                                            markColor: (root._spec["siren" + (index + 1)] || {}).color || "#FFFFFF"
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: root._select(tile.index, siren)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: "#171F28" }

        // ---- ce qui est désigné ----
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            spacing: 10

            Text {
                text: root.sel
                      ? (root.selSiren > 0
                         ? "cellule S" + root.selSiren + " · scène " + root.sel.btn
                         : "scène " + root.sel.btn)
                      : "aucune scène"
                color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 13; font.bold: true
            }
            Text {
                visible: root.sel !== null
                text: root.sel
                      ? (root.selSiren > 0
                         ? ((root.sel.cells && root.sel.cells[root.selSiren - 1] && root.sel.cells[root.selSiren - 1].clipRef)
                            ? root.sel.cells[root.selSiren - 1].clipRef + " · " + root.sel.modes[root.selSiren - 1]
                            : "vide")
                         : (root.sel.name || "sans nom"))
                      : ""
                color: "#64737F"; font.family: "monospace"; font.pixelSize: 12
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: root.armDelete
                text: "la suppression fait remonter les scènes suivantes d'un cran"
                color: "#E4776C"; font.family: "monospace"; font.pixelSize: 11
            }
        }

        // ---- les actions ----
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            spacing: 10

            ActionButton {
                label: "NOUVELLE"
                onActivated: root.newScene()
            }
            ActionButton {
                label: "RENOMMER"
                enabled: root.sel !== null
                onActivated: keyboard.open(root.sel ? root.sel.name : "")
            }
            ActionButton {
                label: root.selSiren > 0 ? "COPIER CELLULE" : "COPIER SCÈNE"
                enabled: root.sel !== null
                onActivated: root._copy()
            }
            ActionButton {
                label: "COLLER"
                enabled: root.canPaste
                accent: root.canPaste
                onActivated: root._paste()
            }
            Item { Layout.fillWidth: true }
            // Deux appuis, parce que la suppression décale tout ce qui suit. Le
            // premier état armé doit être impossible à rater : plein, pas un
            // simple changement de mot (retour de Patrice, 2026-07-31 — il a
            // appuyé une fois et cru que le bouton ne marchait pas).
            ActionButton {
                label: root.armDelete ? "APPUYER ENCORE POUR SUPPRIMER" : "SUPPRIMER"
                enabled: root.sel !== null
                danger: true
                armed: root.armDelete
                onActivated: {
                    if (root.armDelete) { root.deleteScene(root.sel.id); root.armDelete = false; }
                    else { root.armDelete = true; disarm.restart(); }
                }
            }
            ActionButton {
                label: "CHARGER"
                enabled: root.sel !== null && root.sel.current !== true
                accent: true
                onActivated: root.loadScene(root.sel.id)
            }
        }
    }

    // Le doigt qui a effleuré SUPPRIMER ne doit pas rester armé indéfiniment.
    Timer { id: disarm; interval: 8000; onTriggered: root.armDelete = false }

    TouchKeyboard2D {
        id: keyboard
        anchors.fill: parent
        visible: false
        onAccepted: function(name) { if (root.sel) root.renameScene(root.sel.id, name); }
    }

    component ActionButton: Rectangle {
        id: btn
        property string label: ""
        property bool enabled: true
        property bool accent: false
        property bool danger: false
        property bool armed: false
        property bool wide: false
        signal activated()

        implicitWidth: wide ? 130 : Math.max(150, txt.implicitWidth + 40)
        implicitHeight: wide ? 46 : 70
        radius: 3
        color: !btn.enabled ? "#101720"
                            : btn.armed ? "#E4776C"
                            : bma.pressed ? (btn.danger ? "#E4776C" : btn.accent ? "#66E4F2" : "#2A3742")
                                          : (btn.danger ? "#241A19" : btn.accent ? "#132A31" : "#1B242E")
        border.width: 1
        border.color: !btn.enabled ? "#171F28"
                                   : btn.danger ? "#E4776C" : btn.accent ? "#66E4F2" : "#212B36"

        Text {
            id: txt
            anchors.centerIn: parent
            text: btn.label
            color: !btn.enabled ? "#2A3742"
                                : (btn.armed || bma.pressed) ? "#0A0D11"
                                              : (btn.danger ? "#E4776C" : btn.accent ? "#66E4F2" : "#C7D2DC")
            font.family: "monospace"; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1.2
        }

        MouseArea {
            id: bma
            anchors.fill: parent
            enabled: btn.enabled
            onClicked: btn.activated()
        }
    }
}
