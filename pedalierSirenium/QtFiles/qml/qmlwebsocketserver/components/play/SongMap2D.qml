import QtQuick
import QtQuick.Layouts
import "../../sirenSpec.js" as SirenSpec

// La carte du morceau : les sections dans l'ordre, sur un rail. La section courante
// en avant, le passé estompé. Chaque station porte son numéro de bouton (le pédalier),
// son nom, et les 7 marques de mode (le contenu). C'est un affichage, pas un lanceur.
Item {
    id: root

    property string compName: "—"
    property int compButton: 0
    property int banks: 1
    property int currentBank: 1
    // sections : [{ btn, name, modes:[7], current (bool), past (bool) }]
    property var sections: []

    readonly property var _spec: SirenSpec.SPEC

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // ---- en-tête : morceau (gauche) + banque (droite) ----
        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                spacing: 5
                Text { text: "MORCEAU — GRAND PÉDALIER"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.5 }
                RowLayout {
                    spacing: 10
                    Text { text: root.compName; color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 22; font.bold: true }
                    Rectangle {
                        visible: root.compButton > 0
                        border.color: "#212B36"; border.width: 1; color: "transparent"; radius: 2
                        implicitHeight: btn.implicitHeight + 5; implicitWidth: btn.implicitWidth + 12
                        Text { id: btn; anchors.centerIn: parent; text: "bouton " + root.compButton; color: "#64737F"; font.family: "monospace"; font.pixelSize: 10 }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            ColumnLayout {
                spacing: 5
                Text { Layout.alignment: Qt.AlignRight; text: "BANQUE — PETIT PÉDALIER"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.5 }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 10
                    Text { text: root.currentBank.toString(); color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 22; font.bold: true }
                    Row {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter
                        Repeater {
                            model: root.banks
                            delegate: Rectangle {
                                required property int index
                                width: 5; height: 5; radius: 2.5
                                color: (index + 1) === root.currentBank ? "#C7D2DC" : "#3B4855"
                            }
                        }
                    }
                }
            }
        }

        // ---- la timeline ----
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // le rail
            Rectangle { x: 8; y: 12; width: parent.width - 16; height: 1; color: "#212B36" }

            Row {
                anchors.fill: parent
                spacing: 6

                Repeater {
                    model: root.sections
                    delegate: Item {
                        id: station
                        required property var modelData
                        readonly property var section: modelData
                        width: (root.width - (Math.max(root.sections.length, 1) - 1) * 6) / Math.max(root.sections.length, 1)
                        height: parent.height
                        opacity: section.past ? 0.42 : 1

                        Rectangle {
                            visible: station.section.current === true
                            anchors.fill: parent
                            anchors.margins: -2
                            radius: 4
                            color: "#1B242E"
                        }

                        Column {
                            anchors.fill: parent
                            spacing: 7

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 10; height: 10; radius: 5
                                color: station.section.current ? "#FFFFFF" : "#3B4855"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: station.section.btn
                                color: station.section.current ? "#FFFFFF" : "#64737F"
                                font.family: "monospace"; font.pixelSize: 12; font.bold: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: station.section.name
                                color: station.section.current ? "#C7D2DC" : "#64737F"
                                font.family: "monospace"; font.pixelSize: 11
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 3
                                Repeater {
                                    model: 7
                                    delegate: ModeMark2D {
                                        required property int index
                                        mode: (station.section.modes && station.section.modes[index]) ? station.section.modes[index] : "empty"
                                        markColor: (root._spec["siren" + (index + 1)] || {}).color || "#FFFFFF"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
