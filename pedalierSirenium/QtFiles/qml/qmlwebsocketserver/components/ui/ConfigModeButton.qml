import QtQuick

Rectangle {
    id: root
    required property var sirenView
    
    property int selectedPedal: 1
    
    color: mouseArea.pressed ? "#505050" : "#404040"
    border.color: "#606060"
    radius: 5
    width: sirenView.configMode ? 50 : 180
    height: 40
    border.width: 2
    
    Text {
        anchors.centerIn: parent
        text: sirenView.configMode ? "↩" : "Config pédales "
        color: "white"
        font.pixelSize: sirenView.configMode ? 20 :20
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        
        onClicked: {
            sirenView.toggleConfigMode(root.selectedPedal);
        }
        
        onWheel: {
            if (!sirenView.configMode) {
                if (wheel.angleDelta.y > 0) {
                    root.selectedPedal = Math.max(1, root.selectedPedal - 1);
                } else {
                    root.selectedPedal = Math.min(8, root.selectedPedal + 1);
                }
            }
        }
    }
}