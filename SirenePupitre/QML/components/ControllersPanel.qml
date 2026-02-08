import QtQuick
import QtQuick3D
import "./indicators"

Rectangle {
    id: root
    
    // Propriétés pour les données des contrôleurs
    property real wheelPosition: 0
    property real wheelSpeed: 0
    property real joystickX: 0
    property real joystickY: 0
    property real joystickZ: 0
    property bool joystickButton: false
    property int gearShiftPosition: 0
    property string gearShiftMode: "RONDE"
    property int faderValue: 0
    property int modPedalValue: 0
    property real modPedalPercent: 0
    // Pad 1
    property int pad1Velocity: 0
    property int pad1Aftertouch: 0
    property bool pad1Active: false
    // Pad 2
    property int pad2Velocity: 0
    property int pad2Aftertouch: 0
    property bool pad2Active: false
    // Boutons supplémentaires
    property bool button1: false
    property bool button2: false
    // Encodeur
    property int encoderValue: 0
    property bool encoderPressed: false
    
    // Propriétés visuelles
    property color backgroundColor: "#0a0a0a"
    property color borderColor: "#2a2a2a"
    property int headerHeight: 5
    property var configController: null
    property var webSocketController: null
    property bool faderTestActive: false  // État du toggle de test
    // Calibrage pads
    property string padCalibrationMode: "min"  // "min" | "max"
    property bool pad1CalibrationActive: false
    property bool pad2CalibrationActive: false
    property int pad1CalibMinV: 0
    property int pad1CalibMaxV: 127
    property int pad1CalibMinA: 0
    property int pad1CalibMaxA: 127
    property int pad2CalibMinV: 0
    property int pad2CalibMaxV: 127
    property int pad2CalibMinA: 0
    property int pad2CalibMaxA: 127
    /** Valeur int16 affichée sous chaque bouton de calibration (reçue par WebSocket). */
    property int pad1CalibDisplayValue: 0
    property int pad2CalibDisplayValue: 0

    function setPadCalibrationValue(pad, value) {
        if (pad === 0) root.pad1CalibDisplayValue = value
        else if (pad === 1) root.pad2CalibDisplayValue = value
    }

    function showControllerValues() {
        return configController ? configController.isComponentVisible("controllerValues") : true
    }
    
    // Fonction pour envoyer un message de test du fader (1 ou 0)
    function testFader(active) {
        if (!webSocketController || !webSocketController.connected) {
            console.log("❌ WebSocket non connecté, impossible d'envoyer le test du fader")
            return
        }
        
        // Envoyer un message JSON simple pour tester le fader (1 = activé, 0 = désactivé)
        var message = {
            type: "FADER_TEST",
            value: active ? 1 : 0
        }
        
        // Envoyer via sendBinaryMessage (qui convertit JSON en binaire)
        webSocketController.sendBinaryMessage(message)
        console.log("✅ Message de test fader envoyé:", JSON.stringify(message))
    }

    property bool leftSpeakerTestOn: false
    property bool rightSpeakerTestOn: false

    function testSpeaker(channel, active) {
        if (!webSocketController || !webSocketController.connected) {
            console.log("❌ WebSocket non connecté, impossible d'envoyer le test HP")
            return
        }
        webSocketController.sendBinaryMessage({ type: "SPEAKER_TEST", channel: channel, active: active })
        console.log("✅ Message SPEAKER_TEST envoyé:", channel, active)
    }

    /** Envoie un message PAD_CALIBRATION à chaque clic : pad (0 ou 1), mode (min ou max), active (true/false). */
    function sendPadCalibration(pad, active) {
        if (!webSocketController || !webSocketController.connected) return
        webSocketController.sendBinaryMessage({
            type: "PAD_CALIBRATION",
            pad: pad,
            mode: root.padCalibrationMode,
            active: active
        })
    }

    color: backgroundColor
    border.color: borderColor
    border.width: 1
    radius: 5
    
    // Indicateur de connexion (en haut à droite)
    Rectangle {
        width: 10
        height: 10
        radius: 5
        color: root.wheelSpeed !== 0 || root.faderValue !== 0 || root.pad1Active || root.pad2Active ? "#00ff00" : "#ff0000"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 15
        
        SequentialAnimation on opacity {
            running: root.wheelSpeed !== 0 || root.faderValue !== 0 || root.pad1Active || root.pad2Active
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 1000 }
            NumberAnimation { to: 1.0; duration: 1000 }
        }
    }
    
    // Vue 3D pour les contrôleurs
    View3D {
        id: controllerView3D
        anchors.fill: parent
        anchors.topMargin: headerHeight
        anchors.margins: 10
        
        environment: SceneEnvironment {
            clearColor: "#1a1a40"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.NoAA
            probeExposure: 1.2
        }
        
        PerspectiveCamera {
            id: camera
            position: Qt.vector3d(0, 0, 800)
            fieldOfView: 23
            clipFar: 1000
            clipNear: 1
        }
        
        // Éclairage général
        DirectionalLight {
            eulerRotation.x: -45
            eulerRotation.y: -45
            brightness: 1.0
            color: Qt.rgba(1, 1, 1, 1)
        }
        
        DirectionalLight {
            eulerRotation.x: -20
            eulerRotation.y: 45
            brightness: 0.9
            color: Qt.rgba(0.8, 0.8, 1, 1)
        }
        
        // Organisation des contrôleurs
        Node {
            id: controllersContainer
            property real totalWidth: 800
            property real itemSpacing: totalWidth / 4

            // 🔧 Échelle globale depuis la configuration
            property real configScale: {
                if (configController && configController.updateCounter >= 0) {
                    return configController.getValueAtPath(["displayConfig", "components", "controllers", "scale"]) || 0.8
                }
                return 0.8
            }
            
            scale: Qt.vector3d(
                Math.min(1.5, Math.min(controllerView3D.width / 900, controllerView3D.height / 320)) * configScale,
                Math.min(1.5, Math.min(controllerView3D.width / 900, controllerView3D.height / 320)) * configScale,
                Math.min(1.5, Math.min(controllerView3D.width / 900, controllerView3D.height / 320)) * configScale
            )
            
            // Position 1/6 - Wheel
            Node {
                x: -parent.itemSpacing * 3
                y: 0
                z: 0
                visible: {
                    if (!configController) return true
                    configController.updateCounter
                    return configController.isSubComponentVisible("controllers", "wheel")
                }
                
                WheelIndicator {
                    position: root.wheelPosition
                    speed: root.wheelSpeed
                    scale: Qt.vector3d(1.2, 1.2, 1.2)
                    showValues: showControllerValues()
                }
            }
            
            // Position 3/6 - GearShift
            Node {
                x: -parent.itemSpacing * 2.2
                y: 0
                z: -150
                visible: {
                    if (!configController) return true
                    configController.updateCounter
                    return configController.isSubComponentVisible("controllers", "gearShift")
                }
                
                GearShiftIndicator {
                    position: root.gearShiftPosition
                    mode: root.gearShiftMode
                    scale: Qt.vector3d(1.5, 1.5, 1.5)
                    showValues: showControllerValues()
                }
            }
            
            // Position 2/6 - Joystick
            Node {
                x: -parent.itemSpacing * 0.8
                y: 0
                z: 0
                visible: {
                    if (!configController) return true
                    configController.updateCounter
                    return configController.isSubComponentVisible("controllers", "joystick")
                }
                
                JoystickIndicator {
                    xValue: root.joystickX
                    yValue: root.joystickY
                    zValue: root.joystickZ
                    button: root.joystickButton
                    scale: Qt.vector3d(1.5, 1.5, 1.5)
                    showValues: showControllerValues()
                }
            }
            
            // Position 4/6 - Fader
            Node {
                x: parent.itemSpacing * 0.0
                y: 0
                z: 0
                visible: {
                    if (!configController) return true
                    configController.updateCounter
                    return configController.isSubComponentVisible("controllers", "fader")
                }
                
                FaderIndicator {
                    value: root.faderValue
                    scale: Qt.vector3d(1.5, 1.5, 1.5)
                    showValues: showControllerValues()
                }
            }
            
            // Position 4.5/6 - Encoder
            Node {
                x: parent.itemSpacing * 0.6
                y: 0
                z: 0
                visible: {
                    if (!configController) return true
                    configController.updateCounter
                    return configController.isSubComponentVisible("controllers", "encoder")
                }
                
                EncoderIndicator {
                    value: root.encoderValue
                    pressed: root.encoderPressed
                    scale: Qt.vector3d(1.5, 1.5, 1.5)
                    showValues: showControllerValues()
                }
            }
            
            // Position 5/6 - Pedal
            Node {
                x: parent.itemSpacing * 1.5
                y: 10
                z: 0
                visible: {
                    if (!configController) return true
                    configController.updateCounter
                    return configController.isSubComponentVisible("controllers", "modPedal")
                }
                
                PedalIndicator {
                    value: root.modPedalValue
                    percent: root.modPedalPercent
                    scale: Qt.vector3d(1.5, 1.5, 1.5)
                    orientation: Qt.vector3d(20, 60, 10)
                    showValues: showControllerValues()
                }
            }
            
            // Position 6a/6 - Pad 1
            Node {
                x: parent.itemSpacing * 2.3
                y: 0
                z: 0
                visible: {
                    if (!configController) return true
                    configController.updateCounter
                    return configController.isSubComponentVisible("controllers", "pad")
                }
                
                PadIndicator {
                    aftertouch: root.pad1Aftertouch
                    velocity: root.pad1Velocity
                    scale: Qt.vector3d(1.3, 1.3, 1.3)
                    orientation: Qt.vector3d(-90, 90, 90)
                    showValues: showControllerValues()
                }
            }
            
            // Position 6b/6 - Pad 2
            Node {
                x: parent.itemSpacing * 2.7
                y: 0
                z: 0
                visible: {
                    if (!configController) return true
                    configController.updateCounter
                    return configController.isSubComponentVisible("controllers", "pad")
                }
                
                PadIndicator {
                    aftertouch: root.pad2Aftertouch
                    velocity: root.pad2Velocity
                    scale: Qt.vector3d(1.3, 1.3, 1.3)
                    orientation: Qt.vector3d(-90, 90, 90)
                    showValues: showControllerValues()
                }
            }
        }
    }
    
    // Overlay 2D pour le mode GearShift
    Text {
        visible: showControllerValues() && configController && configController.isSubComponentVisible("controllers", "gearShift")
        text: root.gearShiftMode
        font.pixelSize: 14
        font.bold: true
        color: "#CCCCCC"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -parent.width * 0.19  // Position centrée au-dessus du GearShift
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
    }
    
    // Labels pour les pads (+ plage calibrage en mode calibrage)
    Row {
        visible: showControllerValues() && configController && configController.isSubComponentVisible("controllers", "pad")
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: parent.width * 0.33
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        spacing: 50
        
        Column {
            spacing: 2
            Text {
                text: "PAD 1"
                font.pixelSize: 12
                font.bold: root.pad1Active
                color: root.pad1Active ? "#00ff00" : "#666666"
            }
        }
        
        Column {
            spacing: 2
            Text {
                text: "PAD 2"
                font.pixelSize: 12
                font.bold: root.pad2Active
                color: root.pad2Active ? "#00ff00" : "#666666"
            }
        }
    }
    
    // Boutons test haut-parleurs (tout à gauche)
    Row {
        id: speakerTestBar
        visible: showControllerValues()
        anchors.top: parent.top
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.leftMargin: 12
        spacing: 8
        z: 1000

        // HP G (switch on/off)
        Rectangle {
            width: 56
            height: 28
            radius: 4
            color: root.leftSpeakerTestOn ? "#00aa00" : (maHPG.containsMouse ? "#3a3a3a" : "#2a2a2a")
            border.color: "#00ff00"
            border.width: root.leftSpeakerTestOn ? 2 : 1
            MouseArea {
                id: maHPG
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.leftSpeakerTestOn = !root.leftSpeakerTestOn
                    root.testSpeaker("left", root.leftSpeakerTestOn)
                }
            }
            Text {
                anchors.centerIn: parent
                text: root.leftSpeakerTestOn ? "HP G ON" : "HP G"
                color: root.leftSpeakerTestOn ? "#000000" : "#00ff00"
                font.pixelSize: 10
                font.bold: root.leftSpeakerTestOn
            }
        }

        // HP D (switch on/off)
        Rectangle {
            width: 56
            height: 28
            radius: 4
            color: root.rightSpeakerTestOn ? "#00aa00" : (maHPD.containsMouse ? "#3a3a3a" : "#2a2a2a")
            border.color: "#00ff00"
            border.width: root.rightSpeakerTestOn ? 2 : 1
            MouseArea {
                id: maHPD
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.rightSpeakerTestOn = !root.rightSpeakerTestOn
                    root.testSpeaker("right", root.rightSpeakerTestOn)
                }
            }
            Text {
                anchors.centerIn: parent
                text: root.rightSpeakerTestOn ? "HP D ON" : "HP D"
                color: root.rightSpeakerTestOn ? "#000000" : "#00ff00"
                font.pixelSize: 10
                font.bold: root.rightSpeakerTestOn
            }
        }
    }

    // Boutons calibration pads (tout à droite)
    Row {
        id: padCalibBar
        visible: showControllerValues() && configController && configController.isSubComponentVisible("controllers", "pad")
        anchors.top: parent.top
        anchors.topMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 12
        spacing: 8
        z: 1000

        // Sélecteur Min / Max
        Row {
            spacing: 4
            Rectangle {
                width: 44
                height: 28
                radius: 4
                color: root.padCalibrationMode === "min" ? "#00aa00" : (maMin.containsMouse ? "#3a3a3a" : "#2a2a2a")
                border.color: "#00ff00"
                border.width: root.padCalibrationMode === "min" ? 2 : 1
                MouseArea {
                    id: maMin
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.padCalibrationMode = "min"
                }
                Text {
                    anchors.centerIn: parent
                    text: "Min"
                    color: root.padCalibrationMode === "min" ? "#000000" : "#00ff00"
                    font.pixelSize: 10
                    font.bold: root.padCalibrationMode === "min"
                }
            }
            Rectangle {
                width: 44
                height: 28
                radius: 4
                color: root.padCalibrationMode === "max" ? "#00aa00" : (maMax.containsMouse ? "#3a3a3a" : "#2a2a2a")
                border.color: "#00ff00"
                border.width: root.padCalibrationMode === "max" ? 2 : 1
                MouseArea {
                    id: maMax
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.padCalibrationMode = "max"
                }
                Text {
                    anchors.centerIn: parent
                    text: "Max"
                    color: root.padCalibrationMode === "max" ? "#000000" : "#00ff00"
                    font.pixelSize: 10
                    font.bold: root.padCalibrationMode === "max"
                }
            }
        }

        // Calibrer PAD 1 + valeur int16 en dessous
        Column {
            spacing: 4
            Rectangle {
                width: 110
                height: 28
                radius: 4
                color: root.pad1CalibrationActive ? "#00aa00" : (ma1.containsMouse ? "#3a3a3a" : "#2a2a2a")
                border.color: "#00ff00"
                border.width: root.pad1CalibrationActive ? 3 : 1
                MouseArea {
                    id: ma1
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.pad1CalibrationActive = !root.pad1CalibrationActive
                        root.sendPadCalibration(0, root.pad1CalibrationActive)
                        if (!root.pad1CalibrationActive) {
                            root.pad1CalibMinV = 0
                            root.pad1CalibMaxV = 127
                            root.pad1CalibMinA = 0
                            root.pad1CalibMaxA = 127
                        } else {
                            if (root.padCalibrationMode === "min") {
                                root.pad1CalibMinV = 127
                                root.pad1CalibMinA = 127
                            } else {
                                root.pad1CalibMaxV = 0
                                root.pad1CalibMaxA = 0
                            }
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: root.pad1CalibrationActive ? "CAL. PAD 1 ON" : "Calibrer PAD 1"
                    color: root.pad1CalibrationActive ? "#000000" : "#00ff00"
                    font.pixelSize: 10
                    font.bold: root.pad1CalibrationActive
                }
            }
            Text {
                width: 110
                horizontalAlignment: Text.AlignHCenter
                text: root.pad1CalibDisplayValue
                font.pixelSize: 11
                color: "#00ff00"
            }
        }

        // Calibrer PAD 2 + valeur int16 en dessous
        Column {
            spacing: 4
            Rectangle {
                width: 110
                height: 28
                radius: 4
                color: root.pad2CalibrationActive ? "#00aa00" : (ma2.containsMouse ? "#3a3a3a" : "#2a2a2a")
                border.color: "#00ff00"
                border.width: root.pad2CalibrationActive ? 3 : 1
                MouseArea {
                    id: ma2
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.pad2CalibrationActive = !root.pad2CalibrationActive
                        root.sendPadCalibration(1, root.pad2CalibrationActive)
                        if (!root.pad2CalibrationActive) {
                            root.pad2CalibMinV = 0
                            root.pad2CalibMaxV = 127
                            root.pad2CalibMinA = 0
                            root.pad2CalibMaxA = 127
                        } else {
                            if (root.padCalibrationMode === "min") {
                                root.pad2CalibMinV = 127
                                root.pad2CalibMinA = 127
                            } else {
                                root.pad2CalibMaxV = 0
                                root.pad2CalibMaxA = 0
                            }
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: root.pad2CalibrationActive ? "CAL. PAD 2 ON" : "Calibrer PAD 2"
                    color: root.pad2CalibrationActive ? "#000000" : "#00ff00"
                    font.pixelSize: 10
                    font.bold: root.pad2CalibrationActive
                }
            }
            Text {
                width: 110
                horizontalAlignment: Text.AlignHCenter
                text: root.pad2CalibDisplayValue
                font.pixelSize: 11
                color: "#00ff00"
            }
        }
    }

    // Barre "Tests et calibrage" (2D, centrée) — TEST FADER uniquement
    Row {
        id: testsCalibBar
        visible: showControllerValues()
        anchors.top: parent.top
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12
        z: 1000

        // TEST FADER
        Rectangle {
            width: 80
            height: 28
            radius: 4
            visible: configController && configController.isSubComponentVisible("controllers", "fader")
            color: root.faderTestActive ? "#00aa00" : (maFader.containsMouse ? "#3a3a3a" : "#2a2a2a")
            border.color: "#00ff00"
            border.width: root.faderTestActive ? 3 : 1
            MouseArea {
                id: maFader
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.faderTestActive = !root.faderTestActive
                    root.testFader(root.faderTestActive)
                }
            }
            Text {
                anchors.centerIn: parent
                text: root.faderTestActive ? "TEST ON" : "TEST FADER"
                color: root.faderTestActive ? "#000000" : "#00ff00"
                font.pixelSize: 10
                font.bold: true
            }
        }
    }

    // Boutons supplémentaires en overlay 2D (en bas)
    Row {
        visible: showControllerValues()
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 5
        spacing: 15
        
        // Bouton 1
        Rectangle {
            width: 50
            height: 30
            radius: 4
            color: root.button1 ? "#00ff00" : "#2a2a2a"
            border.color: root.button1 ? "#00aa00" : "#444444"
            border.width: 2
            
            Text {
                text: "BTN 1"
                anchors.centerIn: parent
                color: root.button1 ? "#000000" : "#666666"
                font.pixelSize: 10
                font.bold: root.button1
            }
        }
        
        // Bouton 2
        Rectangle {
            width: 50
            height: 30
            radius: 4
            color: root.button2 ? "#00ff00" : "#2a2a2a"
            border.color: root.button2 ? "#00aa00" : "#444444"
            border.width: 2
            
            Text {
                text: "BTN 2"
                anchors.centerIn: parent
                color: root.button2 ? "#000000" : "#666666"
                font.pixelSize: 10
                font.bold: root.button2
            }
        }
    }
    
    // Fonction pour mettre à jour toutes les données
    function updateControllers(controllersData) {
        
        if (controllersData.wheel) {
            wheelPosition = controllersData.wheel.position || 0
            wheelSpeed = controllersData.wheel.velocity || 0
        }
        
        if (controllersData.joystick) {
            joystickX = (controllersData.joystick.x || 0) / 127.0
            joystickY = (controllersData.joystick.y || 0) / 127.0
            joystickZ = (controllersData.joystick.z || 0) / 127.0
            joystickButton = controllersData.joystick.button || false
        }
        
        if (controllersData.gearShift) {
            gearShiftPosition = controllersData.gearShift.position || 0
            gearShiftMode = controllersData.gearShift.mode || "SEMITONE"
        }
        
        if (controllersData.fader) {
            faderValue = controllersData.fader.value || 0
        }
        
        if (controllersData.modPedal) {
            modPedalValue = controllersData.modPedal.value || 0
            modPedalPercent = controllersData.modPedal.percent || 0
        }
        
        // Pad 1
        if (controllersData.pad1) {
            pad1Velocity = controllersData.pad1.velocity || 0
            pad1Aftertouch = controllersData.pad1.aftertouch || 0
            pad1Active = controllersData.pad1.active || false
            if (root.pad1CalibrationActive) {
                if (root.padCalibrationMode === "min") {
                    root.pad1CalibMinV = Math.min(root.pad1CalibMinV, pad1Velocity)
                    root.pad1CalibMinA = Math.min(root.pad1CalibMinA, pad1Aftertouch)
                } else {
                    root.pad1CalibMaxV = Math.max(root.pad1CalibMaxV, pad1Velocity)
                    root.pad1CalibMaxA = Math.max(root.pad1CalibMaxA, pad1Aftertouch)
                }
            }
        }
        
        // Pad 2
        if (controllersData.pad2) {
            pad2Velocity = controllersData.pad2.velocity || 0
            pad2Aftertouch = controllersData.pad2.aftertouch || 0
            pad2Active = controllersData.pad2.active || false
            if (root.pad2CalibrationActive) {
                if (root.padCalibrationMode === "min") {
                    root.pad2CalibMinV = Math.min(root.pad2CalibMinV, pad2Velocity)
                    root.pad2CalibMinA = Math.min(root.pad2CalibMinA, pad2Aftertouch)
                } else {
                    root.pad2CalibMaxV = Math.max(root.pad2CalibMaxV, pad2Velocity)
                    root.pad2CalibMaxA = Math.max(root.pad2CalibMaxA, pad2Aftertouch)
                }
            }
        }
        
        // Rétrocompatibilité : ancien format "pad" unique -> pad1
        if (controllersData.pad && !controllersData.pad1) {
            pad1Velocity = controllersData.pad.velocity || 0
            pad1Aftertouch = controllersData.pad.aftertouch || 0
            pad1Active = controllersData.pad.active || false
            if (root.pad1CalibrationActive) {
                if (root.padCalibrationMode === "min") {
                    root.pad1CalibMinV = Math.min(root.pad1CalibMinV, pad1Velocity)
                    root.pad1CalibMinA = Math.min(root.pad1CalibMinA, pad1Aftertouch)
                } else {
                    root.pad1CalibMaxV = Math.max(root.pad1CalibMaxV, pad1Velocity)
                    root.pad1CalibMaxA = Math.max(root.pad1CalibMaxA, pad1Aftertouch)
                }
            }
        }
        
        // Boutons supplémentaires
        if (controllersData.buttons) {
            button1 = controllersData.buttons.button1 || false
            button2 = controllersData.buttons.button2 || false
        }
        
        // Encodeur
        if (controllersData.encoder) {
            encoderValue = controllersData.encoder.value || 0
            encoderPressed = controllersData.encoder.pressed || false
        }
        
    }
}
