import QtQuick

Rectangle {
    id: root
    required property var wsController
    
    width: statusText.width + 20
    height: 40
    radius: 20
    color: "#333333"
    border.color: wsController.statusColor
    border.width: 2
    
    Text {
        id: statusText
        anchors.centerIn: parent
        text: wsController.connectionStatus
        color: wsController.statusColor
        font.pixelSize: 12
    }
    
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (!wsController.isConnected) {
                wsController.reconnect();
            }
        }
    }
}