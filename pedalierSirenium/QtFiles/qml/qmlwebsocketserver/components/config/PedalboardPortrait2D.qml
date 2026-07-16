import QtQuick
import QtQuick.Layouts

// Portrait du pédalier réel : 8 poussoirs, 3 pédales d'expression (avec leurs
// interrupteurs), clavier PK-6 (13 touches). On touche un contrôle pour le sélectionner.
// Configurer = montrer du doigt, pas traduire un pedalId abstrait.
Item {
    id: root

    // sélection courante : kind ∈ "push" | "expr" | "sw" | "key", plus un index
    property string selKind: "expr"
    property int selIndex: 0

    signal selected(string kind, int index)

    function _pick(kind, index) { selKind = kind; selIndex = index; selected(kind, index); }

    readonly property var _exprSwitches: [2, 1, 1]   // A a 2 interrupteurs, B et C un chacun
    readonly property var _noteNames: ["Do","","Ré","","Mi","Fa","","Sol","","La","","Si","Do"]
    readonly property var _isSharp: [0,1,0,1,0,0,1,0,1,0,1,0,0]

    ColumnLayout {
        anchors.fill: parent
        spacing: 22

        // ---- poussoirs ----
        ColumnLayout {
            spacing: 8
            Text { text: "POUSSOIRS ASSIGNABLES"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.5 }
            Row {
                spacing: 10
                Repeater {
                    model: 8
                    delegate: Rectangle {
                        required property int index
                        width: 62; height: 46; radius: 3
                        color: (root.selKind === "push" && root.selIndex === index) ? "#1D2732" : "#151D26"
                        border.color: (root.selKind === "push" && root.selIndex === index) ? "#FFFFFF" : "#212B36"
                        border.width: 1
                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: index + 1; color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 14; font.bold: true }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "ÉTAT " + (index + 1); color: "#3B4855"; font.family: "monospace"; font.pixelSize: 8 }
                        }
                        MouseArea { anchors.fill: parent; onClicked: root._pick("push", parent.index) }
                    }
                }
            }
        }

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

        // ---- clavier PK-6 ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: "CLAVIER PK-6 — 13 TOUCHES"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.5 }
            Item {
                Layout.fillWidth: true
                height: 108
                property real natW: width / 8
                Repeater {
                    model: 13
                    delegate: Rectangle {
                        required property int index
                        readonly property bool sharp: root._isSharp[index] === 1
                        readonly property int natIndex: [0,2,4,5,7,9,11,12].indexOf(index)
                        readonly property real _natW: parent.natW
                        readonly property int _natPos: {
                            var n = 0;
                            for (var i = 0; i < index; i++) if (root._isSharp[i] === 0) n++;
                            return n;
                        }
                        width: sharp ? _natW * 0.58 : _natW
                        height: sharp ? 62 : 104
                        y: 0
                        x: sharp ? (_natPos * _natW - width / 2) : (_natPos * _natW)
                        z: sharp ? 2 : 1
                        radius: 2
                        color: (root.selKind === "key" && root.selIndex === index)
                               ? "#1D2732" : (sharp ? "#0C1116" : "#151D26")
                        border.color: (root.selKind === "key" && root.selIndex === index) ? "#FFFFFF" : "#212B36"
                        border.width: 1
                        Text {
                            visible: !parent.sharp
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottomMargin: 7
                            text: root._noteNames[parent.index]
                            color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9
                        }
                        MouseArea { anchors.fill: parent; onClicked: root._pick("key", parent.index) }
                    }
                }
            }
        }
    }
}
