import QtQuick
import QtQuick.Controls

Rectangle {
    id: sceneNavigation
    width: parent.width
    height: 60
    color: "#333"
    radius: 8
    border.color: "#555"
    
    property var logger
    property int currentPage: 1
    property int totalPages: 8
    
    signal pageChanged(int newPage)
    
    Row {
        anchors.centerIn: parent
        spacing: 20
        
        Button {
            text: "◄ Prev"
            width: 80
            height: 40
            enabled: sceneNavigation.currentPage > 1
            
            background: Rectangle {
                color: parent.enabled ? (parent.pressed ? "#444" : "#555") : "#333"
                radius: 6
                border.color: parent.enabled ? "#777" : "#444"
            }
            
            contentItem: Text {
                text: parent.text
                color: parent.enabled ? "white" : "#666"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                sceneNavigation.pageChanged(sceneNavigation.currentPage - 1)
            }
        }
        
        Row {
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter
            
            Image {
                source: "qrc:/qml/icons/theater.png"
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
            }
            
            Text {
                text: "Page " + sceneNavigation.currentPage + "/" + sceneNavigation.totalPages
                color: "white"
                font.pixelSize: 18
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        
        Button {
            text: "Next ►"
            width: 80
            height: 40
            enabled: sceneNavigation.currentPage < sceneNavigation.totalPages
            
            background: Rectangle {
                color: parent.enabled ? (parent.pressed ? "#444" : "#555") : "#333"
                radius: 6
                border.color: parent.enabled ? "#777" : "#444"
            }
            
            contentItem: Text {
                text: parent.text
                color: parent.enabled ? "white" : "#666"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                sceneNavigation.pageChanged(sceneNavigation.currentPage + 1)
            }
        }
    }
} 