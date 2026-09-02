import QtQuick
import QtQuick.Layouts

// Portrait des trois pédales d'expression et de leurs interrupteurs.
// On touche un contrôle pour le sélectionner : configurer, c'est montrer du doigt.
// Poussoirs et clavier PK-6 retirés — ils ne se configurent pas depuis cette page.
Item {
    id: root

    // sélection courante : kind ∈ "expr" | "sw", plus un index
    property string selKind: "expr"
    property int selIndex: 0

    signal selected(string kind, int index)

    function _pick(kind, index) { selKind = kind; selIndex = index; selected(kind, index); }

    readonly property var _exprSwitches: [2, 1, 1]   // A a 2 interrupteurs, B et C un chacun

    ColumnLayout {
        anchors.fill: parent
        spacing: 22

        // ---- pédales d'expression ----
        ColumnLayout {
            spacing: 8
            Text { text: "PÉDALES D'EXPRESSION"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.5 }
            Row {
                spacing: 26
                Repeater {
                    model: 3
                    delegate: Column {
                        required property int index
                        spacing: 7
                        readonly property string _name: ["A","B","C"][index]

                        // corps de la pédale (rectangle incliné simulé par un dégradé)
                        Rectangle {
                            width: 74; height: 60; radius: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            border.color: (root.selKind === "expr" && root.selIndex === parent.index) ? "#FFFFFF" : "#212B36"
                            border.width: 1
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: (root.selKind === "expr" && root.selIndex === index) ? "#26333F" : "#1B242E" }
                                GradientStop { position: 1.0; color: "#151D26" }
                            }
                            MouseArea { anchors.fill: parent; onClicked: root._pick("expr", index) }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent._name; color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 12; font.bold: true }

                        // interrupteurs de la pédale
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 5
                            Repeater {
                                model: root._exprSwitches[index]
                                delegate: Rectangle {
                                    required property int index
                                    readonly property int _swId: parent.parent.index * 10 + index
                                    width: 15; height: 15; radius: 7.5
                                    color: (root.selKind === "sw" && root.selIndex === _swId) ? "#26333F" : "#151D26"
                                    border.color: (root.selKind === "sw" && root.selIndex === _swId) ? "#FFFFFF" : "#212B36"
                                    border.width: 1
                                    MouseArea { anchors.fill: parent; onClicked: root._pick("sw", parent._swId) }
                                }
                            }
                        }
                    }
                }
            }
        }

    }
}
