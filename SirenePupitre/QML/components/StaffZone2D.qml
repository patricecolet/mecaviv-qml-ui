import QtQuick
import "./ambitus"

Item {
    id: root

    property color accentColor: '#d1ab00'
    property real currentNoteMidi: 0
    property var sirenInfo: null
    property real lineSpacing: 20
    property real lineThickness: 2
    height: 120

    MusicalStaff2D {
        width: root.width
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        staffWidth: root.width
        lineSpacing: root.lineSpacing
        lineThickness: root.lineThickness
        lineColor: root.accentColor
        currentNoteMidi: root.currentNoteMidi
        sirenInfo: root.sirenInfo
    }
}
