pragma ComponentBehavior: Bound

import QtQuick

// Une ligne de réglage du niveau de log pour une catégorie du Logger.
// Le DebugPanel en aligne une par catégorie ; chacune expose les six niveaux
// de Logger.qml et remonte le choix au parent, qui écrit dans le logger.
//
// Le composant ne touche pas au logger lui-même : il reçoit `level` et émet
// levelChangeRequested, pour que le parent reste seul responsable de l'écriture
// (c'est lui qui doit aussi rafraîchir l'historique filtré).
Item {
    id: root

    property string name: ""
    property string emoji: ""
    property string iconName: ""
    property int level: 0

    signal levelChangeRequested(int newLevel)

    // Les six niveaux de Logger.qml, dans l'ordre : l'indice EST la valeur.
    readonly property var _levels: ["OFF", "ERROR", "WARN", "INFO", "DEBUG", "TRACE"]

    width: parent ? parent.width : 0
    implicitHeight: 26
    height: implicitHeight

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // L'icône, avec l'emoji en secours : les png sont dans data.qrc, mais un
        // nom mal orthographié ne doit pas laisser la ligne sans repère visuel.
        Item {
            width: 16; height: 16
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: icon
                anchors.fill: parent
                source: root.iconName ? "qrc:/qml/icons/" + root.iconName : ""
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                text: root.emoji
                font.pixelSize: 12
                visible: !icon.visible
            }
        }

        Text {
            text: root.name
            color: "white"
            font.pixelSize: 12
            width: 110
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }

        Repeater {
            model: root._levels

            Rectangle {
                id: chip
                required property int index
                required property string modelData

                readonly property bool current: chip.index === root.level

                width: 52; height: 20
                radius: 3
                color: chip.current ? "#2a2a2a" : "#141414"
                border.color: chip.current ? "#8899aa" : "#444444"
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: chip.modelData
                    color: chip.current ? "white" : "#888888"
                    font.pixelSize: 9
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.levelChangeRequested(chip.index)
                }
            }
        }
    }

    Rectangle {   // séparateur discret, comme entre les sections du panneau
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: "#222222"
    }
}
