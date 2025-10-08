import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    width: 300
    height: 120
    radius: 8
    color: "#1a1a1a"
    border.color: "#333"
    border.width: 1
    
    property real fps: 60
    property real cpuUsage: 0
    property real memoryUsage: 0
    property int wsMessages: 0
    
    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8
        
        Text {
            text: "📊 Performances Système"
            color: "#00aaff"
            font.pixelSize: 12
            font.bold: true
        }
        
        Row {
            spacing: 20
            width: parent.width
            
            // FPS
            Column {
                Text {
                    text: "FPS"
                    color: "#888"
                    font.pixelSize: 10
                }
                Text {
                    text: fps.toFixed(1)
                    color: fps > 30 ? "#4CAF50" : "#FF5722"
                    font.pixelSize: 14
                    font.bold: true
                }
            }
            
            // CPU
            Column {
                Text {
                    text: "CPU %"
                    color: "#888"
                    font.pixelSize: 10
                }
                Text {
                    text: cpuUsage.toFixed(1)
                    color: cpuUsage < 80 ? "#4CAF50" : "#FF5722"
                    font.pixelSize: 14
                    font.bold: true
                }
            }
            
            // Mémoire
            Column {
                Text {
                    text: "RAM %"
                    color: "#888"
                    font.pixelSize: 10
                }
                Text {
                    text: memoryUsage.toFixed(1)
                    color: memoryUsage < 85 ? "#4CAF50" : "#FF5722"
                    font.pixelSize: 14
                    font.bold: true
                }
            }
            
            // WebSocket
            Column {
                Text {
                    text: "WS Msg/s"
                    color: "#888"
                    font.pixelSize: 10
                }
                Text {
                    text: wsMessages.toString()
                    color: "#00aaff"
                    font.pixelSize: 14
                    font.bold: true
                }
            }
        }
        
        // Barres de progression
        Row {
            spacing: 10
            width: parent.width - 20
            
            Rectangle {
                width: 60
                height: 4
                radius: 2
                color: "#333"
                Rectangle {
                    width: parent.width * (cpuUsage / 100)
                    height: parent.height
                    radius: parent.radius
                    color: cpuUsage < 80 ? "#4CAF50" : "#FF5722"
                }
            }
            
            Rectangle {
                width: 60
                height: 4
                radius: 2
                color: "#333"
                Rectangle {
                    width: parent.width * (memoryUsage / 100)
                    height: parent.height
                    radius: parent.radius
                    color: memoryUsage < 85 ? "#4CAF50" : "#FF5722"
                }
            }
        }
    }
    
    // Retirer le Timer de simulation  
    /*
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.fps = 55 + Math.random() * 10
            root.cpuUsage = 20 + Math.random() * 60
            root.memoryUsage = 30 + Math.random() * 50
            root.wsMessages = Math.floor(Math.random() * 20)
        }
    }
    */
} 