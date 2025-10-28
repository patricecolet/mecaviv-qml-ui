import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: overviewPage
    
    color: "#1a1a1a"
    
    property var consoleController: parent ? parent.consoleController : null
    
    Component.onCompleted: {
       // Page initialisée
    }
    
    // Timer pour forcer la mise à jour des pupitres
    Timer {
        id: refreshTimer
        interval: 2000 // Rafraîchir toutes les 2 secondes (backup)
        running: true
        repeat: true
        onTriggered: {
            // Forcer la mise à jour en rechargeant les composants
            if (consoleController && consoleController.webSocketManager) {
                consoleController.webSocketManager.checkPupitresStatus()
            }
        }
    }
    
    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: parent.width - 40
        contentHeight: childrenRect.height
        
        Column {
            width: parent.width
            spacing: 8
            
            // Rangées des pupitres
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property string pupitreId: "P1"
                property string pupitreStatus: overviewPage.consoleController.pupitre1Status
                property string pupitreName: "Pupitre 1"
                property string pupitreHost: "192.168.1.41"
                property real currentNote: overviewPage.consoleController.volantNoteFloat
                property real currentHz: overviewPage.consoleController.volantFrequency
                property real currentRpm: overviewPage.consoleController.volantRpm
                // Ambitus réel depuis config.json
                property int ambitusMin: overviewPage.consoleController.p1AmbitusMin
                property int ambitusMax: overviewPage.consoleController.p1AmbitusMax
                
                width: parent.width
            }
            
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property string pupitreId: "P2"
                property string pupitreStatus: overviewPage.consoleController.pupitre2Status
                property string pupitreName: "Pupitre 2"
                property string pupitreHost: "192.168.1.42"
                width: parent.width
            }
            
            Loader {
    source: "../components/overview/OverviewRow.qml"
    property string pupitreId: "P3"
    property string pupitreStatus: overviewPage.consoleController.pupitre3Status
    property string pupitreName: "Pupitre 3"
    property string pupitreHost: "192.168.1.43"
    width: parent.width
}
            
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property string pupitreId: "P4"
                property string pupitreStatus: overviewPage.consoleController.pupitre4Status
                property string pupitreName: "Pupitre 4"
                property string pupitreHost: "192.168.1.44"
                width: parent.width
            }
            
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property string pupitreId: "P5"
                property string pupitreStatus: overviewPage.consoleController.pupitre5Status
                property string pupitreName: "Pupitre 5"
                property string pupitreHost: "192.168.1.45"
                width: parent.width
            }
            
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property string pupitreId: "P6"
                property string pupitreStatus: overviewPage.consoleController.pupitre6Status
                property string pupitreName: "Pupitre 6"
                property string pupitreHost: "192.168.1.46"
                width: parent.width
            }
            
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property string pupitreId: "P7"
                property string pupitreStatus: overviewPage.consoleController.pupitre7Status
                property string pupitreName: "Pupitre 7"
                property string pupitreHost: "192.168.1.47"
                width: parent.width
            }
        }
    }
}
