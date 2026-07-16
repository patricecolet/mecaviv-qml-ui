import QtQuick
import QtQuick.Layouts

// Zone focus : la boucle en cours, toujours au même endroit, en grand.
// Grand anneau + graduations de mesure (midi = départ), état, métriques,
// et l'échelle des paliers d'atterrissage (puissances de 2).
Item {
    id: root

    // anneau
    property string label: "—"
    property color ringColor: "#66E4F2"
    property real progress: 0
    property real haloOpacity: 0
    property bool showHalo: false
    property string sub: ""
    property int ticks: 4               // subdivisions (mesures du cycle) ; 0 = aucune

    // état
    property string statusWord: "AU REPOS"
    property color statusColor: "#3B4855"
    property string statusNote: ""

    // métriques (chaînes déjà formatées)
    property string mBar: "—"
    property string mLen: "—"
    property string mRatio: "—"
    property string mRev: "—"

    // échelle des paliers
    property bool ladderActive: false
    property var ladderStops: []        // { label, bars, passed (bool), landing (bool) }
    property string ladderVerdict: "—"

    implicitHeight: 160

    RowLayout {
        anchors.fill: parent
        spacing: 30

        // ---- le cadran ----
        Item {
            Layout.preferredWidth: 150
            Layout.preferredHeight: 150
            Layout.alignment: Qt.AlignVCenter

            // graduations de mesure : chaque Item remplit le cadran et tourne autour
            // de son centre ; la graduation est posée en haut (midi).
            Repeater {
                model: root.ticks
                delegate: Item {
                    required property int index
                    readonly property bool down: index === 0
                    anchors.fill: parent
                    rotation: (index / Math.max(root.ticks, 1)) * 360
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -3
                        width: parent.down ? 2.5 : 1
                        height: parent.down ? 26 : 16
                        color: parent.down ? "#C7D2DC" : "#212B36"
                    }
                }
            }

            Ring2D {
                id: dial
                anchors.fill: parent
                lineWidth: 8
                ringColor: root.ringColor
                progress: root.progress
                showHalo: root.showHalo
                haloOpacity: root.haloOpacity

                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.label
                        color: root.ringColor
                        font.family: "monospace"; font.pixelSize: 30; font.bold: true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.sub
                        color: "#64737F"
                        font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.2
                    }
                }
            }
        }

        // ---- le relevé ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            Item { Layout.fillHeight: true }   // centre le contenu verticalement

            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Text {
                    text: root.statusWord
                    color: root.statusColor
                    font.family: "monospace"; font.pixelSize: 26; font.bold: true
                }
                Text {
                    text: root.statusNote
                    color: "#64737F"
                    font.family: "monospace"; font.pixelSize: 13
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                spacing: 32
                Repeater {
                    model: [
                        { k: "MESURE", v: root.mBar },
                        { k: "LONGUEUR", v: root.mLen },
                        { k: "RAPPORT", v: root.mRatio },
                        { k: "TOURS", v: root.mRev }
                    ]
                    delegate: ColumnLayout {
                        required property var modelData
                        spacing: 3
                        Text { text: modelData.k; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.2 }
                        Text { text: modelData.v; color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 20 }
                    }
                }
            }

            // échelle des paliers
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                opacity: root.ladderActive ? 1 : 0.28

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "PALIERS D'ATTERRISSAGE"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 1.4 }
                    Item { Layout.fillWidth: true }
                    Text { text: root.ladderVerdict; color: "#FFFFFF"; font.family: "monospace"; font.pixelSize: 12 }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: "#212B36" }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: root.ladderStops
                            delegate: Item {
                                required property var modelData
                                width: parent.width / Math.max(root.ladderStops.length, 1)
                                height: parent.height
                                Column {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label
                                        color: modelData.landing ? "#FFFFFF" : (modelData.passed ? "#64737F" : "#3B4855")
                                        font.family: "monospace"; font.pixelSize: 13
                                        font.bold: modelData.landing === true
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.bars > 0 ? modelData.bars.toString() : "—"
                                        color: modelData.landing ? "#C7D2DC" : "#3B4855"
                                        font.family: "monospace"; font.pixelSize: 10
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }   // centre le contenu verticalement
        }
    }
}
