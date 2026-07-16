import QtQuick

// Bande d'horloge : tempo, signature, témoins de battement, temps et mesure.
// Le témoin du temps 1 est plus large et blanc — seul repère du départ de mesure.
// Le bouton de bascule jeu/config fait partie du bandeau — pas un overlay flottant,
// sinon il chevauche les métriques de droite.
Rectangle {
    id: root

    property int bpm: 120
    property int beatsPerBar: 4
    property int beat: 0        // index 0..beatsPerBar-1
    property int bar: 1
    property string signature: "4/4"
    property bool configMode: false

    signal toggleConfig()

    color: "#0C1116"
    implicitHeight: 56

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 28
        anchors.verticalCenter: parent.verticalCenter
        spacing: 26

        Column {
            spacing: 3
            Text { text: "TEMPO"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.5 }
            Text { text: root.bpm + " BPM"; color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 20; font.bold: true }
        }
        Column {
            spacing: 3
            Text { text: "SIGNATURE"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.5 }
            Text { text: root.signature; color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 20; font.bold: true }
        }
    }

    // Témoins de battement, centrés
    Row {
        anchors.centerIn: parent
        spacing: 7
        Repeater {
            model: root.beatsPerBar
            delegate: Rectangle {
                required property int index
                readonly property bool down: index === 0
                readonly property bool on: index === root.beat
                width: down ? 24 : 14
                height: 14
                radius: 2
                color: on ? (down ? "#FFFFFF" : "#64737F") : "#212B36"
            }
        }
    }

    Row {
        id: rightMetrics
        // s'arrête avant le bouton de bascule, jamais sous lui
        anchors.right: toggleBtn.left
        anchors.rightMargin: 26
        anchors.verticalCenter: parent.verticalCenter
        spacing: 26

        Column {
            spacing: 3
            Text { text: "TEMPS"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.5 }
            Text { text: (root.beat + 1).toString(); color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 20; font.bold: true }
        }
        Column {
            spacing: 3
            Text { text: "MESURE"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.5 }
            Text { text: root.bar.toString(); color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 20; font.bold: true }
        }
    }

    // bouton de bascule jeu/config — dans le bandeau, jamais en overlay
    Rectangle {
        id: toggleBtn
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 44; height: 30; radius: 4
        color: root.configMode ? "#1D2732" : "#151D26"
        border.color: "#212B36"; border.width: 1
        Text {
            anchors.centerIn: parent
            text: root.configMode ? "JEU" : "CFG"
            color: "#64737F"; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 1
        }
        MouseArea { anchors.fill: parent; onClicked: root.toggleConfig() }
    }
}
