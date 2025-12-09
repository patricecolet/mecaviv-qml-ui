import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    
    property string format: "hh:mm:ss"
    property color textColor: "#FFFFFF"
    property int fontSize: 20
    
    color: "transparent"
    
    Text {
        id: clockText
        anchors.centerIn: parent
        color: root.textColor
        font.pixelSize: root.fontSize
        font.bold: true
        
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                var date = new Date()
                clockText.text = Qt.formatDateTime(date, root.format)
            }
        }
        
        Component.onCompleted: {
            var date = new Date()
            clockText.text = Qt.formatDateTime(date, root.format)
        }
    }
}
