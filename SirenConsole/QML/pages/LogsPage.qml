import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: logsPage
    
    color: "#1a1a1a"
    
    property var consoleController: null
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        
        // Titre
        Text {
            text: "Logs du Système"
            color: "#ffffff"
            font.pixelSize: 20
            font.bold: true
            Layout.fillWidth: true
        }
        
        // LogViewer
        Loader {
            source: "../components/logs/LogViewer.qml"
            Layout.fillWidth: true
            Layout.fillHeight: true
            property var consoleController: logsPage.consoleController
        }
    }
}