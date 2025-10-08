import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    width: 200
    height: 60
    radius: 8
    
    property real temperature: 0
    property bool alertMode: temperature > 70
    
    color: {
        if (temperature < 60) return "#2d5a27"      // Vert
        else if (temperature < 70) return "#8b6914" // Orange
        else return "#8b1538"                       // Rouge
    }
    
    border.color: alertMode ? "#ff4444" : "#555"
    border.width: alertMode ? 2 : 1
    
    Column {
        anchors.centerIn: parent
        spacing: 4
        
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "🌡️ CPU"
            color: "white"
            font.pixelSize: 12
            font.bold: true
        }
        
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: temperature.toFixed(1) + "°C"
            color: "white"
            font.pixelSize: 16
            font.bold: true
        }
        
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                if (temperature < 60) return "OK"
                else if (temperature < 70) return "ATTENTION"
                else return "CRITIQUE"
            }
            color: alertMode ? "#ffdddd" : "#ddffdd"
            font.pixelSize: 10
        }
    }
    
    // Animation d'alerte si température critique
    SequentialAnimation {
        running: alertMode
        loops: Animation.Infinite
        
        PropertyAnimation {
            target: root
            property: "opacity"
            to: 0.3
            duration: 500
        }
        
        PropertyAnimation {
            target: root
            property: "opacity"
            to: 1.0
            duration: 500
        }
    }
} 