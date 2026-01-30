import QtQuick
import QtQuick.Controls
import "../components"
import "../components/ambitus"
import "../utils"
import "../admin"

Page {
    id: root
    title: "Test Composants 2D"

    property color accentColor: '#d1ab00'
    property color backgroundColor: "#1a1a1a"
    property bool uiControlsEnabled: true
    property bool isGamePlaying: false
    property bool gameMode: false
    property bool adminPanelVisible: false
    property var webSocketController: null

    readonly property var _defaultSirenInfo: ({
        name: "S1",
        ambitus: { min: 48, max: 84 },
        clef: "treble",
        mode: "restricted",
        restrictedMax: 72,
        displayOctaveOffset: 0
    })
    property var sirenController: null
    property var sirenInfo: (configController && configController.currentSirenInfo) ? configController.currentSirenInfo : _defaultSirenInfo
    property var configController: null
    property real midiNote: sirenController ? sirenController.midiNote : 69.0
    property real clampedNote: sirenController ? sirenController.clampedNote : 69.0
    property string noteName: sirenController ? sirenController.trueNoteName : "La4"
    property real rpm: sirenController ? sirenController.trueRpm : 1200
    property int frequency: sirenController ? sirenController.trueFrequency : 440
    property int velocity: 100
    property real bend: 0.0

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor

        TopDisplays2D {
            id: topDisplays
            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            accentColor: root.accentColor
            rpm: root.rpm
            frequency: root.frequency
            noteName: root.noteName
            midiNote: root.midiNote
            velocity: root.velocity
            bend: root.bend
        }

        Item {
            id: infoContainer
            anchors.fill: parent
            anchors.topMargin: 20
            anchors.bottomMargin: 20

            SirenSelector {
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.top: parent.top
                anchors.topMargin: 80
                configController: root.configController
                accentColor: root.accentColor
                sirenInfo: root.sirenInfo
            }

            ScrollView {
                anchors.top: parent.top
                anchors.topMargin: 130
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 20
                contentWidth: contentWrapper.width
                contentHeight: contentWrapper.height
                z: 0

                Item {
                    id: contentWrapper
                    width: scrollViewContent.width
                    height: scrollViewContent.height

                    Column {
                        id: scrollViewContent
                        width: 400
                        spacing: 20
                        padding: 12
                    }
                }
            }

            StaffZone2D {
                id: staffZone
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                z: 1
                accentColor: root.accentColor
                currentNoteMidi: root.clampedNote
                sirenInfo: root.sirenInfo
            }

            GearShiftPositionIndicator {
                anchors.fill: parent
                visible: true
                currentPosition: configController ? (configController.gearShiftPosition || 0) : 0
                configController: root.configController
            }

            ControllersPanel {
                id: controllersPanel
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * 0.35
                configController: root.configController
                webSocketController: null
                visible: configController ? configController.getValueAtPath(["controllersPanel", "visible"], false) : false
            }

            Test2DButtons {
                controllersPanelVisible: controllersPanel.visible
                configController: root.configController
                uiControlsEnabled: root.uiControlsEnabled
                gameMode: root.gameMode
                isGamePlaying: root.isGamePlaying
                consoleConnected: configController ? configController.consoleConnected : false

                onToggleControllers: {
                    if (configController) {
                        var v = configController.getValueAtPath(["controllersPanel", "visible"], false)
                        configController.setValueAtPath(["controllersPanel", "visible"], !v)
                    } else {
                        controllersPanel.visible = !controllersPanel.visible
                    }
                }
                onToggleGameMode: root.gameMode = !root.gameMode
                onTogglePlayStop: root.isGamePlaying = !root.isGamePlaying
                onAdminClicked: root.adminPanelVisible = true
            }
        }
    }

    AdminPanel {
        anchors.fill: parent
        visible: root.adminPanelVisible
        enabled: root.adminPanelVisible
        z: 10000
        configController: root.configController
        webSocketController: root.webSocketController
        onClose: root.adminPanelVisible = false
    }
}
