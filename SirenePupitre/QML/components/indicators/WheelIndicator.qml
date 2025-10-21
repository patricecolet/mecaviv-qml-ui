import QtQuick
import QtQuick3D
import "../../../../shared/qml/common"

Node {
    id: root
    
    // Propriétés publiques
    property real position: 0 // Position du volant en degrés (0-360)
    property real speed: 0 // Vitesse de rotation en deg/s
    property bool showSpeed: true // Afficher la vitesse
    
    // Propriétés visuelles
    property real wheelRadius: 60
    property real wheelThickness: 12
    property color wheelColor: Qt.rgba(1, 1, 1, 1)
    property color indicatorColor: Qt.rgba(1, 0.3, 0.3, 1)
    property color spokeColor: Qt.rgba(0.7, 0.7, 0.7, 1)
    property color centerColor: Qt.rgba(0.15, 0.15, 0.15, 1)
    property color logoColor: Qt.rgba(0.8, 0.1, 0.1, 1)
    property real indicatorScale: 0.2
    
    // Propriétés de matériaux
    property real wheelMetalness: 0.8
    property real wheelRoughness: 0.2
    property real spokeMetalness: 0.7
    property real spokeRoughness: 0.3
    
    property bool showValues: true
    
    // Angle normalisé entre 0 et 360
    property real normalizedAngle: {
        var angle = root.position % 360
        return angle < 0 ? angle + 360 : angle
    }
    
    // Groupe rotatif pour tout le volant
    Node {
        eulerRotation: Qt.vector3d(0, 10, -root.position)
        
        // Anneau principal du volant
        Ring3D {
            radius: root.wheelRadius
            thickness: root.wheelThickness
            segments: 48 // Plus de segments pour un cercle lisse
            ringColor: root.wheelColor
            metalness: root.wheelMetalness
            roughness: root.wheelRoughness
        }
        
        // Rayons du volant
        Repeater3D {
            model: 3 // 3 rayons à 120 degrés
            Node {
                eulerRotation: Qt.vector3d(0, 0, index * 120 - 90)
                
                // Rayon principal
                Model {
                    source: "#Cube"
                    scale: Qt.vector3d(
                        (root.wheelRadius - root.wheelThickness) / 100,
                        root.wheelThickness * 0.6 / 100,
                        root.wheelThickness * 0.4 / 100
                    )
                    position: Qt.vector3d((root.wheelRadius - root.wheelThickness) / 2, 0, 0)
                    materials: PrincipledMaterial {
                        baseColor: root.spokeColor
                        metalness: root.spokeMetalness
                        roughness: root.spokeRoughness
                    }
                }
                
                // Renfort au niveau de l'anneau
                Model {
                    source: "#Cylinder"
                    scale: Qt.vector3d(0.15, 0.1, 0.15)
                    position: Qt.vector3d(root.wheelRadius - root.wheelThickness/2, 0, 0)
                    eulerRotation: Qt.vector3d(90, 0, 0)
                    materials: PrincipledMaterial {
                        baseColor: root.spokeColor
                        metalness: root.spokeMetalness + 0.1
                        roughness: root.spokeRoughness - 0.1
                    }
                }
            }
        }
        
        // Centre du volant (tourne avec le volant)
        Model {
            source: "#Cylinder"
            scale: Qt.vector3d(0.25, 0.05, 0.25)
            eulerRotation: Qt.vector3d(90, 0, 0)
            materials: PrincipledMaterial {
                baseColor: root.centerColor
                metalness: 0.9
                roughness: 0.1
            }
        }
        
        // Indicateur de position (fixe, ne tourne pas)
        Model {
            id: positionIndicator
            source: "#Sphere"
            position: Qt.vector3d(0, root.wheelRadius, 2)
            scale: Qt.vector3d(indicatorScale, indicatorScale, indicatorScale)
            materials: PrincipledMaterial {
                baseColor: root.indicatorColor
                metalness: 0.0
                roughness: 0.2
                emissiveFactor: Qt.vector3d(0.8, 0.1, 0.1)
            }
        }
    }
    
    // Centre du volant (fixe, ne tourne pas)
    Model {
        source: "#Cylinder"
        scale: Qt.vector3d(0.3, 0.12, 0.3)
        eulerRotation: Qt.vector3d(90, 0, 0)
        materials: PrincipledMaterial {
            baseColor: root.centerColor
            metalness: 0.9
            roughness: 0.1
        }
    }
    
    // Logo/décoration centrale
    Model {
        source: "#Cylinder"
        scale: Qt.vector3d(0.2, 0.02, 0.2)
        position: Qt.vector3d(0, 0, 6)
        eulerRotation: Qt.vector3d(90, 0, 0)
        materials: PrincipledMaterial {
            baseColor: root.logoColor
            metalness: 0.5
            roughness: 0.3
        }
    }
    
    // Affichage de l'angle
    Node {
        position: Qt.vector3d(0, -root.wheelRadius - 30, 0)
        visible: root.showValues
        
        // Centaines
        DigitLED3D {
            value: Math.floor(root.normalizedAngle / 100)
            position: Qt.vector3d(-20, 0, 0)
            active: root.normalizedAngle >= 100
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
            value: Math.floor((root.normalizedAngle % 100) / 10)
            position: Qt.vector3d(-5, 0, 0)
            active: root.normalizedAngle >= 10
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
            value: Math.floor(root.normalizedAngle % 10)
            position: Qt.vector3d(10, 0, 0)
            active: true  // Toujours actif car on affiche au minimum 0°
            activeColor: "#00CED1"
            inactiveColor: "#003333"
            grayActive: "#404040"
            grayInactive: "#1a1a1a"
            segmentWidth: 2
            horizontalLength: 8
            verticalLength: 8
        }
        
        // // Symbole °
        // LEDText3D {
        //     position: Qt.vector3d(25, 0, 0)
        //     text: "°"
        //     textColor: "#00CED1"
        //     offColor: "#003333"
        //     letterHeight: 16
        //     segmentWidth: 2
        //     letterSpacing: 0
        //     scale: Qt.vector3d(0.8, 0.8, 0.8)
        // }
    }
}
