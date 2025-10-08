import QtQuick
import QtQuick3D
import "../../utils"

Node {
    id: root
    
    // Propriétés publiques
    property real value: 0 // Valeur du fader (0-127)
    property real normalizedValue: value / 127
    
    // Propriétés visuelles
    property real railLength: 80
    property real railWidth: 15
    property real cursorWidth: 25
    property real cursorHeight: 15
    property color railColor: Qt.rgba(0.2, 0.2, 0.2, 1)
    property color cursorColor: Qt.rgba(0.1, 0.7, 0.9, 1)
    
    // Propriétés d'éclairage
    property bool lightEnabled: true
    property real lightBrightness: 20
    property bool showValues: true
    
    // Lumière qui suit le curseur
    PointLight {
        visible: root.lightEnabled
        position: Qt.vector3d(
            0,
            50,
            -root.railLength/2 + root.normalizedValue * root.railLength
        )
        brightness: root.lightBrightness + root.normalizedValue * 30
        color: Qt.rgba(0.8, 0.9, 1, 1)
    }
    
    // Rail du fader
    Model {
        source: "#Cube"
        scale: Qt.vector3d(
            root.railWidth / 100,
            root.railLength / 100,
            0.05
        )
        materials: PrincipledMaterial {
            baseColor: root.railColor
            metalness: 0.3
            roughness: 0.7
        }
    }
    
    // Rainure centrale
    Model {
        source: "#Cube"
        scale: Qt.vector3d(
            root.railWidth * 0.3 / 100,
            root.railLength * 0.95 / 100,
            0.03
        )
        position: Qt.vector3d(0, 0, 2)
        materials: PrincipledMaterial {
            baseColor: Qt.rgba(0.1, 0.1, 0.1, 1)
            metalness: 0.1
            roughness: 0.9
        }
    }
    
    // Curseur
    Model {
        source: "#Cube"
        scale: Qt.vector3d(
            root.cursorWidth / 100,
            root.cursorHeight / 100,
            0.1
        )
        position: Qt.vector3d(
            0,
            -root.railLength/2 + root.normalizedValue * root.railLength,
            5
        )
        materials: PrincipledMaterial {
            baseColor: root.cursorColor
            metalness: 0.5
            roughness: 0.2
            emissiveFactor: Qt.vector3d(0, 0.1 * root.normalizedValue, 0.2 * root.normalizedValue)
        }
    }
    
    // Indicateur lumineux sur le curseur
    Model {
        source: "#Cylinder"
        scale: Qt.vector3d(0.05, 0.02, 0.05)
        position: Qt.vector3d(
            0,
            -root.railLength/2 + root.normalizedValue * root.railLength,
            8
        )
        eulerRotation: Qt.vector3d(90, 0, 0)
        materials: PrincipledMaterial {
            baseColor: Qt.rgba(1, 1, 1, 1)
            metalness: 0.0
            roughness: 0.1
            emissiveFactor: Qt.vector3d(root.normalizedValue, root.normalizedValue, root.normalizedValue)
        }
    }
    
    // Affichage LED fixe en dessous du fader
    Node {
        position: Qt.vector3d(-5, -root.railLength/2 - 30, 0) // Fixe en bas du fader
        visible: showValues
        
        // Centaines
        DigitLED3D {
            value: Math.floor(root.value / 100)
            position: Qt.vector3d(-15, 0, 0)
            active: root.value >= 100
            activeColor: "#00CED1"  // Turquoise
            inactiveColor: "#003333" // Turquoise foncé
            grayActive: "#404040"    // Gris actif
            grayInactive: "#1a1a1a"  // Gris inactif
            segmentWidth: 2
            horizontalLength: 8
            verticalLength: 8
        }
        
        // Dizaines
        DigitLED3D {
            value: Math.floor((root.value % 100) / 10)
            position: Qt.vector3d(0, 0, 0)
            active: root.value >= 10
            activeColor: "#00CED1"  // Turquoise
            inactiveColor: "#003333" // Turquoise foncé
            grayActive: "#404040"    // Gris actif
            grayInactive: "#1a1a1a"  // Gris inactif
            segmentWidth: 2
            horizontalLength: 8
            verticalLength: 8
        }
        
        // Unités
        DigitLED3D {
            value: root.value % 10
            position: Qt.vector3d(15, 0, 0)
            active: root.value > 0
            activeColor: "#00CED1"  // Turquoise
            inactiveColor: "#003333" // Turquoise foncé
            grayActive: "#404040"    // Gris actif
            grayInactive: "#1a1a1a"  // Gris inactif
            segmentWidth: 2
            horizontalLength: 8
            verticalLength: 8
        }
    }
}
