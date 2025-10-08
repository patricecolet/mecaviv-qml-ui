import QtQuick
import QtQuick.Controls

Rectangle {
    id: sceneInfo
    width: parent.width
    height: 80
    color: "#333"
    radius: 8
    border.color: currentScene > 0 ? "lime" : "#555"
    
    property int currentScene: -1
    
    function getSceneName(sceneId) {
        // Cette fonction sera fournie par le parent
        return "Scène " + sceneId
    }
    
    Column {
        anchors.centerIn: parent
        spacing: 4
        
        Row {
            spacing: 4
            anchors.horizontalCenter: parent.horizontalCenter
            
            Image {
                source: currentScene > 0 ? "qrc:/qml/icons/music.png" : "qrc:/qml/icons/circle.png"
                width: 14
                height: 14
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
            }
            
            Text {
                text: currentScene > 0 ? "Scène active" : "Aucune scène sélectionnée"
                color: currentScene > 0 ? "lime" : "#888"
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        
        Text {
            text: currentScene > 0 ? getSceneName(currentScene) + " (ID: " + currentScene + ")" : ""
            color: "white"
            font.pixelSize: 16
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
            visible: currentScene > 0
        }
    }
} 