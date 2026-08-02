import QtQuick

// Clavier tactile, pour nommer une scène sans clavier physique — l'écran du
// pédalier n'en a pas. Les noms proposés couvrent le cas courant.
Item {
    id: root

    property string value: ""
    property string title: "NOMMER LA SCÈNE"
    readonly property int maxLength: 18

    signal accepted(string name)
    signal cancelled()

    function open(initial) {
        value = initial || "";
        visible = true;
    }

    readonly property var _rows: [
        ["A","Z","E","R","T","Y","U","I","O","P"],
        ["Q","S","D","F","G","H","J","K","L","M"],
        ["W","X","C","V","B","N","-","_"],
        ["1","2","3","4","5","6","7","8","9","0"]
    ]

    // Le vocabulaire d'une structure de morceau. Nommer une section, c'est
    // presque toujours piocher là-dedans — le clavier reste pour le reste.
    readonly property var suggestions: [
        "intro", "couplet", "refrain", "pont", "break", "thème",
        "partie A", "partie B", "partie C", "montée", "creux", "plein",
        "reprise", "solo", "coda", "outro", "fin", "silence"
    ]

    // Le fond mange les appuis : rien derrière le clavier ne doit réagir.
    MouseArea { anchors.fill: parent; onClicked: {} }
    Rectangle { anchors.fill: parent; color: "#0A0D11"; opacity: 0.94 }

    Column {
        anchors.centerIn: parent
        spacing: 22

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.title
            color: "#3B4855"; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 1.6
        }

        // le nom en cours, avec un curseur qui clignote
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 700; height: 62; radius: 3
            color: "#151D26"; border.width: 1; border.color: "#212B36"
            Row {
                anchors.centerIn: parent
                spacing: 2
                Text {
                    text: root.value.length ? root.value : "sans nom"
                    color: root.value.length ? "#FFFFFF" : "#3B4855"
                    font.family: "monospace"; font.pixelSize: 26; font.bold: true
                }
                Rectangle {
                    width: 2; height: 28; color: "#66E4F2"
                    anchors.verticalCenter: parent.verticalCenter
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0; duration: 480 }
                        NumberAnimation { to: 1; duration: 480 }
                    }
                }
            }
        }

        // ---- les noms proposés ----
        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 6
            spacing: 7
            Repeater {
                model: root.suggestions
                delegate: KeyCap {
                    required property var modelData
                    label: modelData
                    fixedWidth: 112
                    suggestion: true
                    onPressed: root.value = String(modelData)
                }
            }
        }

        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 700; height: 1; color: "#171F28" }

        Repeater {
            model: root._rows
            delegate: Row {
                id: keyRow
                required property var modelData
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 7
                Repeater {
                    model: keyRow.modelData
                    delegate: KeyCap {
                        required property var modelData
                        label: modelData
                        onPressed: {
                            if (root.value.length < root.maxLength) root.value += String(modelData).toLowerCase();
                        }
                    }
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 7
            KeyCap {
                label: "ESPACE"; wide: 2
                onPressed: { if (root.value.length && root.value.length < root.maxLength) root.value += " "; }
            }
            KeyCap {
                label: "EFFACER"; wide: 2
                onPressed: root.value = root.value.slice(0, -1)
            }
            KeyCap {
                label: "ANNULER"; wide: 2
                onPressed: { root.visible = false; root.cancelled(); }
            }
            KeyCap {
                label: "VALIDER"; wide: 2; accent: true
                enabled: root.value.length > 0
                onPressed: { root.visible = false; root.accepted(root.value); }
            }
        }
    }

    component KeyCap: Rectangle {
        id: key
        property string label: ""
        property int wide: 1
        property int fixedWidth: 0
        property bool accent: false
        property bool suggestion: false
        property bool enabled: true
        signal pressed()

        width: fixedWidth > 0 ? fixedWidth : 64 * wide + 7 * (wide - 1)
        height: suggestion ? 46 : 58
        radius: 3
        color: !key.enabled ? "#101720"
                            : ma.pressed ? (key.accent ? "#66E4F2" : "#2A3742")
                                         : (key.accent ? "#1D3239" : key.suggestion ? "#151D26" : "#1B242E")
        border.width: 1
        border.color: key.accent ? "#66E4F2" : "#212B36"

        Text {
            anchors.centerIn: parent
            text: key.label
            color: !key.enabled ? "#2A3742"
                                : (ma.pressed && key.accent) ? "#0A0D11"
                                                             : (key.accent ? "#66E4F2" : "#C7D2DC")
            font.family: "monospace"
            font.pixelSize: key.suggestion ? 13 : (key.label.length > 1 ? 11 : 20)
            font.bold: true
            font.letterSpacing: (key.label.length > 1 && !key.suggestion) ? 1.2 : 0
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            enabled: key.enabled
            onClicked: key.pressed()
        }
    }
}
