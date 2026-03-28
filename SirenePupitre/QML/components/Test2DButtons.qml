import QtQuick
import QtQuick.Controls

Item {
    id: root
    anchors.fill: parent

    property var configController: null
    property bool controllersPanelVisible: false
    property bool uiControlsEnabled: true
    property bool gameMode: false
    /** Vue microtonale active (mode normal : libellé au-dessus d’Options) */
    property bool useMicrotonalDisplay: false
    property bool isGamePlaying: false
    property bool consoleConnected: false
    property var gameOptionsDialog: null
    // Focus UI pour l’encodeur : 0 = ADMIN, 1 = CONTRÔLEURS (top right)
    property int encoderFocusIndex: -1

    signal toggleControllers()
    signal toggleGameMode()
    signal togglePlayStop()
    signal adminClicked()

    function getPrimarySirenIndex() {
        if (!configController || !configController.primarySiren) return -1
        var sirens = configController.config && configController.config.sirenConfig ? (configController.config.sirenConfig.sirens || []) : []
        for (var i = 0; i < sirens.length; i++)
            if (Number(sirens[i].id) === Number(configController.primarySiren.id)) return i
        return -1
    }

    property bool frettedEnabled: {
        if (!configController) return false
        var _ = configController.updateCounter
        var idx = getPrimarySirenIndex()
        if (idx < 0) return false
        var sirens = configController.config.sirenConfig.sirens || []
        var s = sirens[idx]
        return !!(s && s.frettedMode && s.frettedMode.enabled)
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 20
        anchors.rightMargin: 20
        width: 100
        height: 35
        color: root.encoderFocusIndex === 1 ? "#3a3a3a" : "#2a2a2a"
        border.color: root.controllersPanelVisible
                     ? "#00ff00"
                     : (root.encoderFocusIndex === 1 ? "#FFD700" : "#555")
        border.width: root.encoderFocusIndex === 1 ? 2 : 1
        radius: 5
        visible: root.uiControlsEnabled && (root.configController ? root.configController.isComponentVisible("controllers") : true)

        MouseArea {
            anchors.fill: parent
            onClicked: root.toggleControllers()
        }

        Text {
            text: root.controllersPanelVisible ? "Masquer" : "Contrôleurs"
            color: root.encoderFocusIndex === 1 ? "#FFD700" : "white"
            font.pixelSize: 12
            font.bold: root.encoderFocusIndex === 1
            anchors.centerIn: parent
        }
    }

    Rectangle {
        id: frettedButton
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        x: parent.width * 0.25 - width / 2
        width: 140
        height: 60
        color: root.frettedEnabled ? "#1a4a2a" : "#2a2a2a"
        border.color: root.frettedEnabled ? "#4ade80" : "#FFD700"
        border.width: 2
        radius: 5
        visible: root.uiControlsEnabled && !root.gameMode && !root.controllersPanelVisible

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!root.configController) return
                var idx = root.getPrimarySirenIndex()
                if (idx < 0) return
                var path = ["sirenConfig", "sirens", idx, "frettedMode", "enabled"]
                root.configController.setValueAtPath(path, !root.frettedEnabled)
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 5
            Text {
                text: root.frettedEnabled ? "Fretté ON" : "Fretté OFF"
                color: root.frettedEnabled ? "#4ade80" : "#FFD700"
                font.pixelSize: 14
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "↓ Bouton physique"
                color: "#888"
                font.pixelSize: 10
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        x: parent.width * 0.25 - width / 2
        width: 140
        height: 60
        color: root.isGamePlaying ? "#1a5a3a" : "#2a2a2a"
        border.color: root.isGamePlaying ? "#4ade80" : "#6bb6ff"
        border.width: 2
        radius: 5
        visible: root.gameMode && root.uiControlsEnabled

        SequentialAnimation on opacity {
            running: root.isGamePlaying && root.gameMode
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.7; duration: 800 }
            NumberAnimation { from: 0.7; to: 1.0; duration: 800 }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.togglePlayStop()
        }

        Column {
            anchors.centerIn: parent
            spacing: 5
            Text {
                text: root.isGamePlaying ? "⏹ Stop" : "▶︎ Play"
                color: root.isGamePlaying ? "#4ade80" : "#fff"
                font.pixelSize: 14
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "↓ Bouton physique"
                color: root.isGamePlaying ? "#4ade80" : "#888"
                font.pixelSize: 10
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    Column {
        id: optionsNormalModeBlock
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        visible: root.uiControlsEnabled && !root.controllersPanelVisible && !root.gameMode

        Text {
            visible: root.useMicrotonalDisplay
            text: "Mode Microtonal"
            color: "#6bb6ff"
            font.pixelSize: 13
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
            id: optionsNormalModeBtn
            width: 120
            height: 44
            color: "#2a2a2a"
            border.color: "#6bb6ff"
            border.width: 2
            radius: 5

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.gameOptionsDialog)
                        root.gameOptionsDialog.open()
                }
            }
            Text {
                anchors.centerIn: parent
                text: "Options"
                color: "#6bb6ff"
                font.pixelSize: 13
                font.bold: true
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        x: parent.width * 0.75 - width / 2
        width: 140
        height: 60
        color: root.gameMode ? "#00CED1" : "#2a2a2a"
        border.color: "#00CED1"
        border.width: 2
        radius: 5
        visible: root.uiControlsEnabled && !root.controllersPanelVisible

        MouseArea {
            anchors.fill: parent
            onClicked: root.toggleGameMode()
        }

        Column {
            anchors.centerIn: parent
            spacing: 5
            Text {
                text: root.gameMode ? "Mode Normal" : "Mode Jeu"
                color: root.gameMode ? "#000" : "#00CED1"
                font.pixelSize: 14
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "↓ Bouton physique"
                color: root.gameMode ? "#000" : "#888"
                font.pixelSize: 10
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 20
        width: 80
        height: 40
        color: root.encoderFocusIndex === 0 ? "#3a3a3a" : "#2a2a2a"
        border.color: root.encoderFocusIndex === 0 ? "#FFD700" : "#555"
        border.width: root.encoderFocusIndex === 0 ? 2 : 1
        radius: 5
        visible: root.uiControlsEnabled

        MouseArea {
            id: mouseAreaAdmin
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.adminClicked()
        }

        Text {
            text: "ADMIN"
            color: root.encoderFocusIndex === 0 ? "#FFD700" : "#888"
            font.pixelSize: 14
            font.bold: root.encoderFocusIndex === 0
            anchors.centerIn: parent
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 20
        anchors.rightMargin: 20
        width: 180
        height: 35
        color: "#FFD700"
        border.color: "#FFA500"
        border.width: 2
        radius: 8
        visible: root.consoleConnected

        Text {
            text: "🎛️ CONSOLE CONNECTÉE"
            color: "#000"
            font.pixelSize: 14
            font.bold: true
            anchors.centerIn: parent
        }
    }
}
