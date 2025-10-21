import QtQuick
import QtQuick3D
import "../../../../shared/qml/common"

Node {
    id: root
    
    // Propriétés publiques
    property real value: 0 // Valeur actuelle
    property real minValue: 0 // Valeur minimale (par défaut 0)
    property real maxValue: 127 // Valeur maximale (par défaut 127)
    property real percent: {
        var range = maxValue - minValue
        if (range <= 0) return 0
        return ((value - minValue) / range) * 100
    }
    property bool showPercent: true
    
    // Propriété d'orientation configurable (pédale seulement)
    property vector3d orientation: Qt.vector3d(30, 60, 0)
    
    // Propriétés visuelles
    property color baseColor: Qt.rgba(0.3, 0.3, 0.3, 1)
    property color activeColor: "#00CED1" // Turquoise au lieu d'orange
    
    // Propriétés d'éclairage
    property bool lightEnabled: true
    property real lightBrightness: 20
    
    // Valeur normalisée pour les animations (0 à 1)
    property real normalizedValue: {
        var range = maxValue - minValue
        if (range <= 0) return 0
        return (value - minValue) / range
    }
    
    property bool showValues: true
    
    // Node pour la pédale avec orientation
    Node {
        id: pedalNode
        eulerRotation: root.orientation
        
        // Lumière pulsante basée sur la valeur
        PointLight {
            visible: root.lightEnabled
            position: Qt.vector3d(0, 60, 0)
            brightness: root.lightBrightness + root.percent * 0.3
            color: Qt.rgba(
                0.5 + root.percent * 0.005,
                0.5,
                1 - root.percent * 0.005,
                1
            )
            
            // Animation pulsante quand > 50%
            SequentialAnimation on brightness {
                running: root.percent > 50
                loops: Animation.Infinite
                NumberAnimation {
                    to: root.lightBrightness + 50
                    duration: 500
                }
                NumberAnimation {
                    to: root.lightBrightness + root.percent * 0.3
                    duration: 500
                }
            }
        }
        
        // Base de la pédale
        Model {
            id: pedalBase
            source: "#Cube"
            scale: Qt.vector3d(0.6, 0.15, 0.8)
            position: Qt.vector3d(0, -20, 0)
            materials: PrincipledMaterial {
                baseColor: root.baseColor
                metalness: 0.6
                roughness: 0.3
            }
        }
        
        // Axe de rotation (cylindre horizontal) plus vers l'intérieur
        Model {
            source: "#Cylinder"
            scale: Qt.vector3d(0.05, 0.65, 0.05)
            position: Qt.vector3d(0, -12, 20) // Reculé de 30 à 20
            eulerRotation: Qt.vector3d(0, 0, 90)
            materials: PrincipledMaterial {
                baseColor: Qt.rgba(0.6, 0.6, 0.6, 1)
                metalness: 0.9
                roughness: 0.2
            }
        }
        
        // Node pour la rotation de la pédale autour de l'axe bas
        Node {
            position: Qt.vector3d(0, -12, 20) // Point de pivot sur l'axe
            eulerRotation.x: 30 * (1 - root.normalizedValue) // 30° à value=0, 0° à value=127
            
            // Pédale principale
            Model {
                source: "#Cube"
                scale: Qt.vector3d(0.6, 0.08, 0.8)
                position: Qt.vector3d(0, 0, -25) // Ajusté pour le nouvel axe
                materials: PrincipledMaterial {
                    baseColor: Qt.rgba(0.5, 0.5, 0.5, 1)
                    metalness: 0.8
                    roughness: 0.2
                    emissiveFactor: Qt.vector3d(0, 0, 0.1 * root.normalizedValue)
                }
            }
            
            // Surface antidérapante
            Model {
                source: "#Cube"
                scale: Qt.vector3d(0.5, 0.02, 0.65)
                position: Qt.vector3d(0, 4, -25)
                materials: PrincipledMaterial {
                    baseColor: Qt.rgba(0.1, 0.1, 0.1, 1)
                    metalness: 0.0
                    roughness: 0.95
                }
            }
            
            // Bandes antidérapantes
            Repeater3D {
                model: 5
                Model {
                    source: "#Cube"
                    scale: Qt.vector3d(0.45, 0.01, 0.02)
                    position: Qt.vector3d(0, 5, -45 + index * 10)
                    materials: PrincipledMaterial {
                        baseColor: Qt.rgba(0.05, 0.05, 0.05, 1)
                        metalness: 0.0
                        roughness: 1.0
                    }
                }
            }
        }
    }
    
    // Affichage de la valeur/pourcentage - toujours face caméra
    Node {
        position: Qt.vector3d(0, -70, 30)
        
        // Affichage du pourcentage si showPercent est true
        Node {
            visible: showValues && root.showPercent
            
            // Centaines
            DigitLED3D {
                value: Math.floor(root.percent / 100)
                position: Qt.vector3d(-20, 0, 0)
                active: root.percent >= 100
                activeColor: "#00CED1"  // Turquoise
                inactiveColor: "#003333" // Turquoise foncé
                segmentWidth: 2
                horizontalLength: 7
                verticalLength: 7
            }
            
            // Dizaines
            DigitLED3D {
                value: Math.floor((root.percent % 100) / 10)
                position: Qt.vector3d(-8, 0, 0)
                active: root.percent >= 10
                activeColor: "#00CED1"  // Turquoise
                inactiveColor: "#003333" // Turquoise foncé
                segmentWidth: 2
                horizontalLength: 7
                verticalLength: 7
            }
            
            // Unités
            DigitLED3D {
                value: Math.floor(root.percent % 10)
                position: Qt.vector3d(4, 0, 0)
                active: root.percent > 0
                activeColor: "#00CED1"  // Turquoise
                inactiveColor: "#003333" // Turquoise foncé
                segmentWidth: 2
                horizontalLength: 7
                verticalLength: 7
            }
        }
// Dans le Node d'affichage du pourcentage, après les 3 DigitLED3D, ajoutez :

// Affichage du pourcentage si showPercent est true
Node {
    visible: showValues && root.showPercent
    
    // Centaines
    DigitLED3D {
        value: Math.floor(root.percent / 100)
        position: Qt.vector3d(-20, 0, 0)
        active: root.percent >= 100
        activeColor: "#00CED1"
        inactiveColor: "#003333"
        grayActive: "#404040"
        grayInactive: "#1a1a1a"
        segmentWidth: 2
        horizontalLength: 7
        verticalLength: 7
    }
    
    // Dizaines
    DigitLED3D {
        value: Math.floor((root.percent % 100) / 10)
        position: Qt.vector3d(-8, 0, 0)
        active: root.percent >= 10
        activeColor: "#00CED1"
        inactiveColor: "#003333"
        grayActive: "#404040"
        grayInactive: "#1a1a1a"
        segmentWidth: 2
        horizontalLength: 7
        verticalLength: 7
    }
    
    // Unités
    DigitLED3D {
        value: Math.floor(root.percent % 10)
        position: Qt.vector3d(4, 0, 0)
        active: root.percent > 0
        activeColor: "#00CED1"
        inactiveColor: "#003333"
        grayActive: "#404040"
        grayInactive: "#1a1a1a"
        segmentWidth: 2
        horizontalLength: 7
        verticalLength: 7
    }
    
//     // Symbole %
//     LEDText3D {
//         position: Qt.vector3d(18, 0, 0)  // À droite des chiffres
//         text: "%"
//         textColor: root.value > 0 ? "#00CED1" : "#404040"  // Turquoise si actif, gris sinon
//         offColor: root.value > 0 ? "#003333" : "#1a1a1a"   // Turquoise foncé si actif, gris foncé sinon
//         letterHeight: 14  // Proportionnel aux chiffres (7*2)
//         segmentWidth: 2
//         letterSpacing: 0  // Pas d'espacement car un seul caractère
//         scale: Qt.vector3d(0.8, 0.8, 0.8)  // Un peu plus petit que les chiffres
//     }
     }

    }
}
