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
    
    // Timer de refresh désactivé (polling manuel via WebSocketManager si besoin)
    Timer {
        id: refreshTimer
        interval: 2000
        running: false
        repeat: false
        onTriggered: {}
    }
    
    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: parent.width - 40
        contentHeight: childrenRect.height
        
        Column {
            width: parent.width
            spacing: 8
            
            // Rangées des pupitres - P1
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property string pupitreId: "P1"
                property string pupitreStatus: overviewPage.consoleController.pupitre1Status
                property string pupitreName: "Pupitre 1"
                property string pupitreHost: "192.168.1.41"
                property real currentNote: overviewPage.consoleController.pupitre1CurrentNote
                property real currentHz: overviewPage.consoleController.pupitre1CurrentHz
                property real currentRpm: overviewPage.consoleController.pupitre1CurrentRpm
                property int ambitusMin: overviewPage.consoleController.pupitre1AmbitusMin
                property int ambitusMax: overviewPage.consoleController.pupitre1AmbitusMax
                
                width: parent.width
            }
            
            // P2
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property string pupitreId: "P2"
                property string pupitreStatus: overviewPage.consoleController.pupitre2Status
                property string pupitreName: "Pupitre 2"
                property string pupitreHost: "192.168.1.42"
                property real currentNote: overviewPage.consoleController.pupitre2CurrentNote
                property real currentHz: overviewPage.consoleController.pupitre2CurrentHz
                property real currentRpm: overviewPage.consoleController.pupitre2CurrentRpm
                property int ambitusMin: overviewPage.consoleController.pupitre2AmbitusMin
                property int ambitusMax: overviewPage.consoleController.pupitre2AmbitusMax
                width: parent.width
            }
            
            // P3
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property string pupitreId: "P3"
                property string pupitreStatus: overviewPage.consoleController.pupitre3Status
                property string pupitreName: "Pupitre 3"
                property string pupitreHost: "192.168.1.43"
                property real currentNote: overviewPage.consoleController.pupitre3CurrentNote
                property real currentHz: overviewPage.consoleController.pupitre3CurrentHz
                property real currentRpm: overviewPage.consoleController.pupitre3CurrentRpm
                property int ambitusMin: overviewPage.consoleController.pupitre3AmbitusMin
                property int ambitusMax: overviewPage.consoleController.pupitre3AmbitusMax
                width: parent.width
            }
            
            // P4
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property string pupitreId: "P4"
                property string pupitreStatus: overviewPage.consoleController.pupitre4Status
                property string pupitreName: "Pupitre 4"
                property string pupitreHost: "192.168.1.44"
                property real currentNote: overviewPage.consoleController.pupitre4CurrentNote
                property real currentHz: overviewPage.consoleController.pupitre4CurrentHz
                property real currentRpm: overviewPage.consoleController.pupitre4CurrentRpm
                property int ambitusMin: overviewPage.consoleController.pupitre4AmbitusMin
                property int ambitusMax: overviewPage.consoleController.pupitre4AmbitusMax
                width: parent.width
            }
            
            // P5
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property string pupitreId: "P5"
                property string pupitreStatus: overviewPage.consoleController.pupitre5Status
                property string pupitreName: "Pupitre 5"
                property string pupitreHost: "192.168.1.45"
                property real currentNote: overviewPage.consoleController.pupitre5CurrentNote
                property real currentHz: overviewPage.consoleController.pupitre5CurrentHz
                property real currentRpm: overviewPage.consoleController.pupitre5CurrentRpm
                property int ambitusMin: overviewPage.consoleController.pupitre5AmbitusMin
                property int ambitusMax: overviewPage.consoleController.pupitre5AmbitusMax
                width: parent.width
            }
            
            // P6
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property string pupitreId: "P6"
                property string pupitreStatus: overviewPage.consoleController.pupitre6Status
                property string pupitreName: "Pupitre 6"
                property string pupitreHost: "192.168.1.46"
                property real currentNote: overviewPage.consoleController.pupitre6CurrentNote
                property real currentHz: overviewPage.consoleController.pupitre6CurrentHz
                property real currentRpm: overviewPage.consoleController.pupitre6CurrentRpm
                property int ambitusMin: overviewPage.consoleController.pupitre6AmbitusMin
                property int ambitusMax: overviewPage.consoleController.pupitre6AmbitusMax
                width: parent.width
            }
            
            // P7
            Loader {
                source: "../components/overview/OverviewRow.qml"
                property string pupitreId: "P7"
                property string pupitreStatus: overviewPage.consoleController.pupitre7Status
                property string pupitreName: "Pupitre 7"
                property string pupitreHost: "192.168.1.47"
                property real currentNote: overviewPage.consoleController.pupitre7CurrentNote
                property real currentHz: overviewPage.consoleController.pupitre7CurrentHz
                property real currentRpm: overviewPage.consoleController.pupitre7CurrentRpm
                property int ambitusMin: overviewPage.consoleController.pupitre7AmbitusMin
                property int ambitusMax: overviewPage.consoleController.pupitre7AmbitusMax
                width: parent.width
            }
        }
    }
}
