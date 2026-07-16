import QtQuick
import QtQuick.Layouts

// Cartouche d'accord, compact : la forme du voicing (grave → aigu), en une bande courte.
// Notes NEUTRES — la couleur reste réservée à l'identité des sirènes. La sirène qui porte
// chaque note est un label texte, pas une couleur.
Item {
    id: root

    property string chordName: "—"
    property string chordSub: ""
    // voicing en ordre de hauteur : [{ label:"S3", deg:0, fund:bool }]
    property var voicing: []
    property int maxDeg: 7

    implicitHeight: 54

    RowLayout {
        anchors.fill: parent
        spacing: 18

        // nom + sous-titre
        ColumnLayout {
            spacing: 1
            Layout.alignment: Qt.AlignVCenter
            Text { text: root.chordName; color: "#FFFFFF"; font.family: "monospace"; font.pixelSize: 14; font.bold: true }
            Text { text: root.chordSub; color: "#64737F"; font.family: "monospace"; font.pixelSize: 10 }
        }

        // la forme de l'accord : points neutres à hauteur d'intervalle
        Item {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.bottomMargin: 8; height: 1; color: "#171F28" }

            Repeater {
                model: root.voicing
                delegate: Item {
                    id: note
                    required property var modelData
                    required property int index
                    readonly property real _frac: modelData.deg / root.maxDeg
                    width: 30
                    height: parent.height
                    x: root.voicing.length > 1
                       ? (index * ((stack.width - 30) / (root.voicing.length - 1)))
                       : (stack.width / 2 - 15)

                    // point de note, positionné en hauteur (grave bas, aigu haut)
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: (parent.height - 20) * (1 - note._frac)
                        width: 9; height: 9; radius: 4.5
                        color: note.modelData.fund ? "#FFFFFF" : "#C7D2DC"
                        border.width: note.modelData.fund ? 2 : 0
                        border.color: "#FFFFFF"
                    }
                    // label sirène sous la ligne
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        text: note.modelData.label
                        color: "#3B4855"; font.family: "monospace"; font.pixelSize: 8
                    }
                }
            }
        }

        Text {
            text: "GRAVE → AIGU"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 8; font.letterSpacing: 1.2
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
