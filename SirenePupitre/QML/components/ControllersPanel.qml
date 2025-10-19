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
    
    // Propriétés visuelles
    property color backgroundColor: "#0a0a0a"
    property color borderColor: "#2a2a2a"
    property int headerHeight: 5
    property var configController: null
    
    function showControllerValues() {
        return configController ? configController.isComponentVisible("controllerValues") : true
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
                Math.min(1.5, controllerView3D.width / 900) * configScale,
                Math.min(1.5, controllerView3D.width / 900) * configScale,
                Math.min(1.5, controllerView3D.width / 900) * configScale
            )
            
            // Position 1/6 - Wheel
            Node {
                x: -parent.itemSpacing * 2.5
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
                x: -parent.itemSpacing * 1.5 - 50
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
                x: -parent.itemSpacing * 0.5
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
                x: parent.itemSpacing * 0.5
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
    
    // Labels pour les pads
    Row {
        visible: showControllerValues() && configController && configController.isSubComponentVisible("controllers", "pad")
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: parent.width * 0.36
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        spacing: 50
        
        Text {
            text: "PAD 1"
            font.pixelSize: 12
            font.bold: root.pad1Active
            color: root.pad1Active ? "#00ff00" : "#666666"
        }
        
        Text {
            text: "PAD 2"
            font.pixelSize: 12
            font.bold: root.pad2Active
            color: root.pad2Active ? "#00ff00" : "#666666"
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
        }
        
        // Pad 2
        if (controllersData.pad2) {
            pad2Velocity = controllersData.pad2.velocity || 0
            pad2Aftertouch = controllersData.pad2.aftertouch || 0
            pad2Active = controllersData.pad2.active || false
        }
        
        // Rétrocompatibilité : ancien format "pad" unique -> pad1
        if (controllersData.pad && !controllersData.pad1) {
            pad1Velocity = controllersData.pad.velocity || 0
            pad1Aftertouch = controllersData.pad.aftertouch || 0
            pad1Active = controllersData.pad.active || false
        }
        
        // Boutons supplémentaires
        if (controllersData.buttons) {
            button1 = controllersData.buttons.button1 || false
            button2 = controllersData.buttons.button2 || false
        }
        
    }
}
