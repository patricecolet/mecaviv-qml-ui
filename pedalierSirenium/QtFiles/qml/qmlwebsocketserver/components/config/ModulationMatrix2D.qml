import QtQuick
import QtQuick.Layouts
import "../../config.js" as Config
import "../../sirenSpec.js" as SirenSpec

// Matrice de modulation d'une pédale virtuelle : 7 sirènes × 8 contrôleurs.
// Chaque case = la profondeur en butée (barre depuis le centre : gauche retire, droite ajoute).
// Couleur des sirènes = identité (lignes) ; couleur de section = les contrôleurs (colonnes).
Item {
    id: root

    // matrix[sirenIndex 0..6][controllerName] = valeur (-100..100)
    property var matrix: ({})

    readonly property var _order: Config.controllers.order
    readonly property var _defs: Config.controllers.definitions
    readonly property var _spec: SirenSpec.SPEC

    function _sectionColor(name) {
        var secs = Config.controllers.sections;
        for (var i = 0; i < secs.length; i++)
            if (secs[i].controllers.indexOf(name) >= 0) return secs[i].color;
        return "#64737F";
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        // en-tête : libellés des contrôleurs
        RowLayout {
            Layout.fillWidth: true
            spacing: 3
            Item { Layout.preferredWidth: 34 }
            Repeater {
                model: root._order
                delegate: Text {
                    required property var modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: (root._defs[modelData] ? root._defs[modelData].label : modelData)
                    color: root._sectionColor(modelData)
                    opacity: 0.8
                    font.family: "monospace"; font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }
        }

        // 7 lignes de sirènes
        Repeater {
            model: 7
            delegate: RowLayout {
                id: rowItem
                required property int index
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 3
                readonly property color _sColor: (root._spec["siren" + (index + 1)] || {}).color || "#FFFFFF"
                readonly property string _sLabel: (root._spec["siren" + (index + 1)] || {}).label || ("S" + (index + 1))

                Text {
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                    rightPadding: 6
                    text: rowItem._sLabel
                    color: rowItem._sColor
                    font.family: "monospace"; font.pixelSize: 11; font.bold: true
                }

                Repeater {
                    model: root._order
                    delegate: Item {
                        id: cell
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        readonly property real _val: (root.matrix[rowItem.index] && root.matrix[rowItem.index][modelData] !== undefined)
                                                     ? root.matrix[rowItem.index][modelData] : 0

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            color: "#0C1116"
                            border.color: "#171F28"
                            border.width: 1
                            radius: 2

                            // trait central
                            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: "#212B36" }

                            // barre de valeur
                            Rectangle {
                                visible: cell._val !== 0
                                anchors.verticalCenter: parent.verticalCenter
                                height: parent.height - 8
                                radius: 1
                                color: rowItem._sColor
                                opacity: 0.55
                                width: Math.min(Math.abs(cell._val) / 100, 1) * (parent.width / 2 - 1)
                                x: cell._val > 0 ? parent.width / 2 : parent.width / 2 - width
                            }

                            Text {
                                anchors.centerIn: parent
                                text: cell._val === 0 ? "·" : (cell._val > 0 ? "+" + cell._val : "" + cell._val)
                                color: cell._val === 0 ? "#3B4855" : "#C7D2DC"
                                font.family: "monospace"; font.pixelSize: 9
                            }
                        }
                    }
                }
            }
        }
    }
}
