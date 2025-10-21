import QtQuick
import QtQuick3D
import "../../../shared/qml/common"

Node {
    id: root
    
    property int value: 0
    property color digitColor: "#00CED1"
    property color inactiveColor: "#003333"
    property color frameColor: "#00CED1"
    property string label: "" // "RPM" ou "Hz"
    property real digitSpacing: 45
    property real scaleX: 2.5
    property real scaleY: 1
    
    // Boîte principale (arrière) - proportions 3:1
    Model {
        position: Qt.vector3d(0, 0, -30)
        source: "#Cube"
        scale: Qt.vector3d(scaleX * 1.2, scaleY * 1.2, 0.6)  // ← Utilise scaleX/Y
        materials: [
            PrincipledMaterial {
                baseColor: "#2a2a2a"
                metalness: 0.4
                roughness: 0.6
            }
        ]
    }
    
    // Cadre intermédiaire
    Model {
        position: Qt.vector3d(0, 0, -15)
        source: "#Cube"
        scale: Qt.vector3d(scaleX * 1.24, scaleY * 1.1, 0.3)  // ← Adapté aux proportions
        materials: [
            PrincipledMaterial {
                baseColor: "#3a3a3a"
                metalness: 0.5
                roughness: 0.5
            }
        ]
    }
    
    // Écran noir (zone d'affichage)
    Model {
        position: Qt.vector3d(0, 0, -8)
        source: "#Rectangle"
        scale: Qt.vector3d(scaleX * 1.2, scaleY, 1)  // ← Utilise scaleX/Y
        materials: [
            PrincipledMaterial {
                baseColor: "#0a0a0a"
                metalness: 0.0
                roughness: 1.0
            }
        ]
    }
    
    // Cadre décoratif autour de l'écran
    // Bord haut
    Model {
        position: Qt.vector3d(0, scaleY * 0.52, -6)  // ← Position adaptée
        source: "#Cube"
        scale: Qt.vector3d(scaleX * 1.22, 0.04, 0.1)  // ← Largeur adaptée
        materials: [
            PrincipledMaterial {
                baseColor: frameColor
                metalness: 0.9
                roughness: 0.2
            }
        ]
    }
    
    // Bord bas
    Model {
        position: Qt.vector3d(0, -scaleY * 0.52, -6)  // ← Position adaptée
        source: "#Cube"
        scale: Qt.vector3d(scaleX * 1.22, 0.04, 0.1)  // ← Largeur adaptée
        materials: [
            PrincipledMaterial {
                baseColor: frameColor
                metalness: 0.9
                roughness: 0.2
            }
        ]
    }
    
    // Bord gauche
    Model {
        position: Qt.vector3d(-scaleX * 0.61, 0, -6)  // ← Position adaptée
        source: "#Cube"
        scale: Qt.vector3d(0.04, scaleY * 1.08, 0.1)  // ← Hauteur adaptée
        materials: [
            PrincipledMaterial {
                baseColor: frameColor
                metalness: 0.9
                roughness: 0.2
            }
        ]
    }
    
    // Bord droit
    Model {
        position: Qt.vector3d(scaleX * 0.61, 0, -6)  // ← Position adaptée
        source: "#Cube"
        scale: Qt.vector3d(0.04, scaleY * 1.08, 0.1)  // ← Hauteur adaptée
        materials: [
            PrincipledMaterial {
                baseColor: frameColor
                metalness: 0.9
                roughness: 0.2
            }
        ]
    }
    
    // Effet de vitre/reflet
    Model {
        position: Qt.vector3d(0, 0, -5)
        source: "#Rectangle"
        scale: Qt.vector3d(scaleX * 1.2, scaleY, 1)  // ← Adapté
        opacity: 0.05
        materials: [
            DefaultMaterial {
                diffuseColor: "#FFFFFF"
                opacity: 0.05
            }
        ]
    }
    
// Conteneur pour les chiffres
Node {
    x: -scaleX * 48  // Position adaptée au scaleX
    z: 5
    
    // Chiffre des milliers
    DigitLED3D {
        x: 0
        value: Math.floor(root.value / 1000) % 10
        activeColor: root.digitColor
        inactiveColor: root.inactiveColor
        scale: Qt.vector3d(scaleX * 0.48, scaleY * 1.2, 1.2)  // ← Scale adapté
    }
    
    // Chiffre des centaines
    DigitLED3D {
        x: root.digitSpacing * scaleX * 0.4  // ← Espacement adapté
        value: Math.floor(root.value / 100) % 10
        activeColor: root.digitColor
        inactiveColor: root.inactiveColor
        scale: Qt.vector3d(scaleX * 0.48, scaleY * 1.2, 1.2)  // ← Scale adapté
    }
    
    // Chiffre des dizaines
    DigitLED3D {
        x: root.digitSpacing * 2 * scaleX * 0.4  // ← Espacement adapté
        value: Math.floor(root.value / 10) % 10
        activeColor: root.digitColor
        inactiveColor: root.inactiveColor
        scale: Qt.vector3d(scaleX * 0.48, scaleY * 1.2, 1.2)  // ← Scale adapté
    }
    
    // Chiffre des unités
    DigitLED3D {
        x: root.digitSpacing * 3 * scaleX * 0.4  // ← Espacement adapté
        value: root.value % 10
        activeColor: root.digitColor
        inactiveColor: root.inactiveColor
        scale: Qt.vector3d(scaleX * 0.48, scaleY * 1.2, 1.2)  // ← Scale adapté
    }
}

// Label à droite sur la boîte
LEDText3D {
    position: Qt.vector3d(scaleX * 40, -15, 5)
    text: root.label
    textColor: "#f8f546"
    scale: Qt.vector3d(scaleX * 0.32, scaleY * 0.8, 0.8)  // ← Scale adapté
    visible: root.label !== ""
}

}
