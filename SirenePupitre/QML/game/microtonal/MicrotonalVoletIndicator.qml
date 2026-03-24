import QtQuick

Item {
    id: root
    implicitWidth: 120
    implicitHeight: 44

    /** 0 = fermé, 1 = ouvert (position courante) */
    property real openAmount: 0
    /** 0–1 : repère vertical jaune (cible d’ouverture) ; −1 = masqué */
    property real targetMarker: -1
    property bool showLabel: true
    property color fillColor: "#6bb6ff"
    property color trackColor: "#2a2a2a"

    Rectangle {
        id: track
        anchors.fill: parent
        radius: 4
        color: root.trackColor
        border.color: "#666"
        border.width: 1
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1, root.openAmount))
            radius: 4
            color: root.fillColor
        }
        /** Repère degré d’ouverture cible (même échelle que le remplissage bleu). */
        Rectangle {
            z: 2
            visible: root.targetMarker >= 0 && root.targetMarker <= 1
            width: 2
            radius: 1
            x: Math.max(0, Math.min(parent.width - width, parent.width * root.targetMarker - width / 2))
            anchors.top: parent.top
            anchors.topMargin: 3
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            color: "#FFD700"
        }
        Text {
            anchors.centerIn: parent
            visible: root.showLabel
            text: "Volet " + Math.round(root.openAmount * 100) + "%"
            color: "#eee"
            font.pixelSize: 12
        }
    }
}
