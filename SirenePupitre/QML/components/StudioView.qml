import QtQuick
import QtQuick3D
import QtQuick.Controls
import "../utils"  // Pour Ring3D
import "./indicators"
Rectangle {
    id: root
    
    // L'objet à afficher
    property var currentObject: null
    property string objectName: "Object"
    
    // Contrôles de la vue
    property real cameraDistance: 200
    property real rotationSpeed: 0.5
    property bool autoRotate: false
    property color backgroundColor: "#1a1a1a"
    
    // Vue actuelle
    property int currentView: 0
    property var viewNames: ["Face", "Côté", "Dessus", "3/4", "Libre"]
    
    color: backgroundColor
    
    // Liste des contrôleurs disponibles
    property var controllers: [
        { name: "Wheel Controller", file: "./indicators/WheelIndicator.qml", props: { position: 45, speed: 5 } },
        { name: "Ring3D Test", file: "../utils/Ring3D.qml", props: { radius: 90, thickness: 12, ringColor: "#FF0000" } },
        { name: "Joystick", file: "./indicators/JoystickIndicator.qml", props: { xValue: 0.3, yValue: -0.5, zValue: 0.7, button: true } },
        { name: "Gear Shift", file: "./indicators/GearShiftIndicator.qml", props: { position: 2, mode: "SEMITONE" } },
        { name: "Fader", file: "./indicators/FaderIndicator.qml", props: { value: 0.7 } },
        { name: "Mod Pedal", file: "./indicators/PedalIndicator.qml", props: { value: 65, percent: 50 } },
        { name: "Pad", file: "./indicators/PadIndicator.qml", props: { velocity: 100, aftertouch: 30, active: true } }
    ]
    
    // Variable pour éviter le double chargement
    property bool isInitializing: true
    
    // Gradient de fond
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#2a2a2a" }
            GradientStop { position: 0.5; color: "#1a1a1a" }
            GradientStop { position: 1.0; color: "#0a0a0a" }
        }
    }
    
    // Vue 3D Studio
    View3D {
        id: studioView
        anchors.fill: parent
        anchors.margins: 20
        
        // Environnement avec lumière ambiante
        environment: SceneEnvironment {
        clearColor: "transparent"
        backgroundMode: SceneEnvironment.Transparent
        antialiasingMode: SceneEnvironment.MSAA
        antialiasingQuality: SceneEnvironment.High
    }
        
        // Caméra tournante
        Node {
            id: cameraRotator
            
            PerspectiveCamera {
                id: camera
                position: getCameraPosition()
                lookAtNode: currentView !== 4 ? objectContainer : null
                fieldOfView: 45
                clipFar: 1000
                clipNear: 0.1
            }
            
            NumberAnimation on eulerRotation.y {
                running: root.autoRotate && currentView === 4
                from: 0
                to: 360
                duration: 20000
                loops: Animation.Infinite
            }
        }
        
        // Même éclairage que ControllersPanel
        DirectionalLight {
            eulerRotation: Qt.vector3d(-30, -30, 0)
            brightness: 1.0
            color: "#ffffff"
            castsShadow: true
        }
        
        DirectionalLight {
            eulerRotation: Qt.vector3d(30, 60, 0)
            brightness: 0.5
            color: "#ffffff"
        }
        
        PointLight {
            position: Qt.vector3d(0, 200, 0)
            brightness: 0.3
            color: "#ffffff"
        }
        
        // Conteneur pour l'objet
        Node {
            id: objectContainer
            scale: Qt.vector3d(2, 2, 2)
        }
        
        // MouseArea pour la vue 3D uniquement
        MouseArea {
            anchors.fill: parent
            property real lastX: 0
            property real lastY: 0
            enabled: currentView === 4 // Seulement en vue libre
            
            onPressed: {
                lastX = mouse.x
                lastY = mouse.y
                root.autoRotate = false
            }
            
            onPositionChanged: {
                if (pressed) {
                    var deltaX = mouse.x - lastX
                    var deltaY = mouse.y - lastY
                    
                    cameraRotator.eulerRotation.y += deltaX * root.rotationSpeed
                    cameraRotator.eulerRotation.x = Math.max(-80, Math.min(80, 
                        cameraRotator.eulerRotation.x + deltaY * root.rotationSpeed))
                    
                    lastX = mouse.x
                    lastY = mouse.y
                }
            }
            
            onWheel: {
                root.cameraDistance = Math.max(50, Math.min(500, 
                    root.cameraDistance - wheel.angleDelta.y * 0.2))
            }
        }
    }
    
    // Panneau de contrôle
    Column {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 10
        
        // Sélecteur d'objet
        Rectangle {
            width: 250
            height: 50
            color: "#2a2a2a"
            radius: 5
            
            ComboBox {
                id: controllerSelector
                anchors.fill: parent
                anchors.margins: 5
                model: controllers.map(c => c.name)
                
                onCurrentIndexChanged: {
                    if (!isInitializing && currentIndex >= 0) {
                        loadController(currentIndex)
                    }
                }
            }
        }
        
        // Sélecteur de vue
        Rectangle {
            width: 250
            height: 50
            color: "#2a2a2a"
            radius: 5
            border.color: "#00CED1"
            border.width: 2
            
            Row {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 10
                
                Text {
                    text: "Vue:"
                    color: "#ffffff"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Button {
                    text: viewNames[currentView]
                    width: 80
                    height: parent.height
                    onClicked: {
                        currentView = (currentView + 1) % viewNames.length
                        if (currentView !== 4) {
                            autoRotate = false
                            cameraRotator.eulerRotation = Qt.vector3d(0, 0, 0)
                        }
                    }
                }
                
                Button {
                    text: "Reset"
                    width: 60
                    height: parent.height
                    onClicked: {
                        cameraDistance = 200
                        cameraRotator.eulerRotation = Qt.vector3d(0, 0, 0)
                    }
                }
            }
        }
        
        // Nom de l'objet
        Rectangle {
            width: 250
            height: 40
            color: "#2a2a2a"
            radius: 5
            
            Text {
                text: root.objectName
                color: "#ffffff"
                font.pixelSize: 16
                font.bold: true
                anchors.centerIn: parent
            }
        }
        
        // Rotation auto
        Rectangle {
            width: 250
            height: 35
            color: "#2a2a2a"
            radius: 5
            visible: currentView === 4 // Seulement en vue libre
            
            Row {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    text: "Auto-rotation"
                    color: "#ffffff"
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Switch {
                    checked: root.autoRotate
                    onCheckedChanged: root.autoRotate = checked
                    scale: 0.8
                }
            }
        }
        
        // Zoom
        Rectangle {
            width: 250
            height: 60
            color: "#2a2a2a"
            radius: 5
            
            Column {
                anchors.fill: parent
                anchors.margins: 10
                
                Text {
                    text: "Zoom: " + Math.round(objectContainer.scale.x * 100) + "%"
                    color: "#ffffff"
                    font.pixelSize: 12
                }
                
                Slider {
                    width: parent.width
                    from: 0.5
                    to: 5
                    value: objectContainer.scale.x
                    onValueChanged: {
                        objectContainer.scale = Qt.vector3d(value, value, value)
                    }
                }
            }
        }
        
        // Distance caméra
        Rectangle {
            width: 250
            height: 60
            color: "#2a2a2a"
            radius: 5
            
            Column {
                anchors.fill: parent
                anchors.margins: 10
                
                Text {
                    text: "Distance: " + Math.round(root.cameraDistance)
                    color: "#ffffff"
                    font.pixelSize: 12
                }
                
                Slider {
                    width: parent.width
                    from: 100
                    to: 500
                    value: root.cameraDistance
                    onValueChanged: root.cameraDistance = value
                }
            }
        }
    }
    
    // Fonctions pour les positions de caméra
    function getCameraPosition() {
        switch(currentView) {
            case 0: // Face
                return Qt.vector3d(0, 0, root.cameraDistance)
            case 1: // Côté
                return Qt.vector3d(root.cameraDistance, 0, 0)
            case 2: // Dessus
                return Qt.vector3d(0, root.cameraDistance, 0)
            case 3: // 3/4
                return Qt.vector3d(root.cameraDistance * 0.7, root.cameraDistance * 0.5, root.cameraDistance * 0.7)
            case 4: // Libre
                return Qt.vector3d(0, 50, root.cameraDistance)
        }
    }
    
    function getCameraRotation() {
        switch(currentView) {
            case 0: // Face
                return Qt.vector3d(0, 0, 0)
            case 1: // Côté
                return Qt.vector3d(0, -90, 0)
            case 2: // Dessus
                return Qt.vector3d(-90, 0, 0)
            case 3: // 3/4
                return Qt.vector3d(-20, -45, 0)
            case 4: // Libre
                return Qt.vector3d(-10, 0, 0)
        }
    }
    
    // Fonction pour charger un contrôleur
    function loadController(index) {
        if (index < 0 || index >= controllers.length) return
        
        var controller = controllers[index]
        
        // Supprimer l'ancien objet
        if (currentObject) {
            currentObject.destroy()
        }
        
        // Créer le composant
        var component = Qt.createComponent(controller.file)
        
        if (component.status === Component.Ready) {
            currentObject = component.createObject(objectContainer, controller.props)
            objectName = controller.name
            
            if (currentObject) {
                // Position correcte selon le type d'objet
                if (currentObject.hasOwnProperty('x')) {
                    currentObject.x = 0
                    currentObject.y = 0
                    currentObject.z = 0
                }
                
                // Debug
                
                // Debug spécifique pour WheelIndicator
                if (controller.name === "Wheel Controller") {
                    
                    // Parcourir les enfants
                    for (var i = 0; i < currentObject.children.length; i++) {
                        var child = currentObject.children[i]
                    }
                    
                    // Debug détaillé du premier enfant (Node rotatif)
                    if (currentObject.children.length > 0) {
                        var rotatingNode = currentObject.children[0]
                        
                        // Parcourir les enfants du node rotatif
                        for (var j = 0; j < rotatingNode.children.length; j++) {
                            var subChild = rotatingNode.children[j]
                            
                            // Vérifier les propriétés si possible
                            if (subChild.hasOwnProperty('radius')) {
                            }
                            if (subChild.hasOwnProperty('thickness')) {
                            }
                            if (subChild.hasOwnProperty('source')) {
                            }
                        }
                    }
                }
            }
        } else {
        }
    }
    
    // Charger le premier contrôleur au démarrage
    Component.onCompleted: {
        isInitializing = false
        loadController(0)
    }
}
