import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: overviewPage
    
    color: "#1a1a1a"
    
    property var consoleController: null
    
    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: parent.width - 40
        contentHeight: childrenRect.height
        
        Column {
            width: parent.width
            spacing: 8
            
            // Titre
            Text {
                text: "Vue d'ensemble des Pupitres"
                color: "#ffffff"
                font.pixelSize: 24
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            // Rangées des pupitres
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property var pupitre: consoleController && consoleController.pupitre1 ? consoleController.pupitre1 : null
                width: parent.width
            }
            
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property var pupitre: consoleController && consoleController.pupitre2 ? consoleController.pupitre2 : null
                width: parent.width
            }
            
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property var pupitre: consoleController && consoleController.pupitre3 ? consoleController.pupitre3 : null
                width: parent.width
            }
            
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property var pupitre: consoleController && consoleController.pupitre4 ? consoleController.pupitre4 : null
                width: parent.width
            }
            
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property var pupitre: consoleController && consoleController.pupitre5 ? consoleController.pupitre5 : null
                width: parent.width
            }
            
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property var pupitre: consoleController && consoleController.pupitre6 ? consoleController.pupitre6 : null
                width: parent.width
            }
            
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property var pupitre: consoleController && consoleController.pupitre7 ? consoleController.pupitre7 : null
                width: parent.width
            }
        }
    }
}
