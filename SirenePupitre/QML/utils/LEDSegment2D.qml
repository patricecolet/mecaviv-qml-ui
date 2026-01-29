import QtQuick

Rectangle {
    id: root
    
    property real segmentWidth: 5
    property real segmentLength: 30
    property color segmentColor: "#ff0000"
    property bool segmentActive: true
    property real rotationAngle: 0  // Angle de rotation en degrés
    
    width: segmentLength
    height: segmentWidth
    color: segmentActive ? segmentColor : "transparent"
    visible: segmentActive
    
    // Rotation autour du centre
    transform: Rotation {
        origin.x: root.width / 2
        origin.y: root.height / 2
        angle: root.rotationAngle
    }
}
