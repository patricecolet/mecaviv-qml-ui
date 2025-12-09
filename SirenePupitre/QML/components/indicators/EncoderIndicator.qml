import QtQuick
import QtQuick3D
import "../../utils"

Node {
    id: root
    
    // Propriétés publiques
    property real value: 0  // Valeur de rotation (0-127)
    property bool pressed: false  // État du poussoir
    property real normalizedValue: value / 127  // Valeur normalisée 0-1
    
    // Propriétés visuelles
    property real encoderRadius: 25  // Rayon de l'encodeur
    property real encoderHeight: 15  // Hauteur de l'encodeur
    property color encoderIdleColor: Qt.rgba(0.3, 0.3, 0.3, 1)  // Gris quand non pressé
    property color encoderPressedColor: "#00ff00"  // Vert quand pressé
    
    property bool showValues: true
    
    // Cylindre principal qui change de couleur selon l'état pressé
    Model {
        source: "#Cylinder"
        scale: Qt.vector3d(encoderRadius / 50, encoderHeight / 100, encoderRadius / 50)
        position: Qt.vector3d(0, 0, 0)
        eulerRotation: Qt.vector3d(90, 0, 0)
        materials: PrincipledMaterial {
            baseColor: pressed ? root.encoderPressedColor : root.encoderIdleColor
            metalness: 0.6
            roughness: 0.3
            emissiveFactor: pressed ? Qt.vector3d(0.3, 0.8, 0.3) : Qt.vector3d(0, 0, 0)
        }
    }
    
    // Affichage LED de la valeur
    Node {
        position: Qt.vector3d(0, -encoderHeight / 2 - 50, 0)
        visible: showValues
        
        // Centaines
        DigitLED3D {
            value: Math.floor(root.value / 100)
            position: Qt.vector3d(-15, 0, 0)
            active: root.value >= 100
            activeColor: "#00CED1"
            inactiveColor: "#003333"
            grayActive: "#404040"
            grayInactive: "#1a1a1a"
            segmentWidth: 2
            horizontalLength: 8
            verticalLength: 8
        }
        
        // Dizaines
        DigitLED3D {
            value: Math.floor((root.value % 100) / 10)
            position: Qt.vector3d(0, 0, 0)
            active: root.value >= 10
            activeColor: "#00CED1"
            inactiveColor: "#003333"
            grayActive: "#404040"
            grayInactive: "#1a1a1a"
            segmentWidth: 2
            horizontalLength: 8
            verticalLength: 8
        }
        
        // Unités
        DigitLED3D {
            value: root.value % 10
            position: Qt.vector3d(15, 0, 0)
            active: root.value > 0
            activeColor: "#00CED1"
            inactiveColor: "#003333"
            grayActive: "#404040"
            grayInactive: "#1a1a1a"
            segmentWidth: 2
            horizontalLength: 8
            verticalLength: 8
        }
    }
}
