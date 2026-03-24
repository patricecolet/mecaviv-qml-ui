import QtQuick

/**
 * Croix des vitesses (0 / 1 / 12 / 24 / 48). Racine = Column pour éviter
 * width/height implicites circulaires (Item + Column ancrée) qui plaquaient le bloc en haut.
 */
Column {
    id: root
    width: 120
    spacing: 0

    property int currentPosition: 0
    property var configController: null
    property var positions: [0, 1, 12, 24, 48]

    onConfigControllerChanged: {
        if (configController)
            updatePositions()
    }

    function updatePositions() {
        if (!configController)
            return
        var gearShiftConfig = configController.getConfigValue("displayConfig.components.musicalStaff.gearShiftIndicator.positions", [0, 1, 12, 24, 48])
        if (Array.isArray(gearShiftConfig))
            positions = gearShiftConfig
    }

    Item {
        width: 120
        height: 120
        anchors.horizontalCenter: parent.horizontalCenter

        Rectangle {
            id: centerPos
            width: 30
            height: 25
            radius: 3
            color: root.currentPosition === 0 ? "#4A90E2" : "#2A2A2A"
            border.color: root.currentPosition === 0 ? "#6BB6FF" : "#555555"
            border.width: 1
            anchors.centerIn: parent

            Text {
                anchors.centerIn: parent
                text: root.positions[0] !== undefined ? root.positions[0].toString() : "0"
                font.pixelSize: 10
                font.bold: true
                color: root.currentPosition === 0 ? "#FFFFFF" : "#CCCCCC"
            }
        }

        Rectangle {
            id: leftPos
            width: 30
            height: 25
            radius: 3
            color: root.currentPosition === 1 ? "#4A90E2" : "#2A2A2A"
            border.color: root.currentPosition === 1 ? "#6BB6FF" : "#555555"
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: centerPos.left
            anchors.rightMargin: 10

            Text {
                anchors.centerIn: parent
                text: root.positions[1] !== undefined ? root.positions[1].toString() : "1"
                font.pixelSize: 10
                font.bold: true
                color: root.currentPosition === 1 ? "#FFFFFF" : "#CCCCCC"
            }
        }

        Rectangle {
            id: bottomPos
            width: 30
            height: 25
            radius: 3
            color: root.currentPosition === 2 ? "#4A90E2" : "#2A2A2A"
            border.color: root.currentPosition === 2 ? "#6BB6FF" : "#555555"
            border.width: 1
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: centerPos.bottom
            anchors.topMargin: 10

            Text {
                anchors.centerIn: parent
                text: root.positions[2] !== undefined ? root.positions[2].toString() : "12"
                font.pixelSize: 10
                font.bold: true
                color: root.currentPosition === 2 ? "#FFFFFF" : "#CCCCCC"
            }
        }

        Rectangle {
            id: rightPos
            width: 30
            height: 25
            radius: 3
            color: root.currentPosition === 3 ? "#4A90E2" : "#2A2A2A"
            border.color: root.currentPosition === 3 ? "#6BB6FF" : "#555555"
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: centerPos.right
            anchors.leftMargin: 10

            Text {
                anchors.centerIn: parent
                text: root.positions[3] !== undefined ? root.positions[3].toString() : "24"
                font.pixelSize: 10
                font.bold: true
                color: root.currentPosition === 3 ? "#FFFFFF" : "#CCCCCC"
            }
        }

        Rectangle {
            id: topPos
            width: 30
            height: 25
            radius: 3
            color: root.currentPosition === 4 ? "#4A90E2" : "#2A2A2A"
            border.color: root.currentPosition === 4 ? "#6BB6FF" : "#555555"
            border.width: 1
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: centerPos.top
            anchors.bottomMargin: 10

            Text {
                anchors.centerIn: parent
                text: root.positions[4] !== undefined ? root.positions[4].toString() : "48"
                font.pixelSize: 10
                font.bold: true
                color: root.currentPosition === 4 ? "#FFFFFF" : "#CCCCCC"
            }
        }
    }
}
