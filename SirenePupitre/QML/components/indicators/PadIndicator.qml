import QtQuick
import QtQuick3D
import "../../utils"

Node {
    id: root
    
    // Propriétés publiques
    property int aftertouch: 0  // 0-127
    property int velocity: 0    // 0-127 (frappe)
    
    // Propriété d'orientation configurable
    property vector3d orientation: Qt.vector3d(0, 0, 0)
    
    // Propriétés visuelles
    property real padSize: 60
    property real padHeight: 10
    
    // Nouvelle propriété
    property bool showValues: true
    
    // Node principal avec orientation
    Node {
        eulerRotation: root.orientation
        
        // Base du pad (support noir)
        Model {

            visible: true
            source: "#Cube"
            scale: Qt.vector3d(
                root.padSize / 100,
                root.padHeight / 100,
                root.padSize / 100
            )
            materials: PrincipledMaterial {
                baseColor: "#252525"
                metalness: 0.2
                roughness: 0.8
            }
        }
        
        // Surface sensible 
        Model {
            visible: true
            source: "#Cube"
            scale: Qt.vector3d(
                root.padSize * 0.9 / 100,
                0.2,
                root.padSize * 0.9 / 100
            )
            position: Qt.vector3d(0, 6, 0)
            
            materials: PrincipledMaterial {
                baseColor: {
                    if (root.aftertouch === 0) {
                        return Qt.rgba(0.3, 0.3, 0.3, 1.0)
                    }
                    var normalized = root.aftertouch / 127.0
                    var redValue = 0.15 + (normalized * 0.85)
                    var greenValue = Math.pow(normalized, 4)
                    return Qt.rgba(redValue, greenValue, 0.0, 1.0)
                }
                metalness: 0.0
                roughness: 0.6
                emissiveFactor: root.aftertouch > 0 ? 
                    Qt.vector3d(
                        Math.pow(root.aftertouch / 127, 1.5) * 0.6,
                        Math.pow(root.aftertouch / 127, 4) * 0.6,
                        0
                    ) : 
                    Qt.vector3d(0, 0, 0)
            }
        }
        
        // Affichage des chiffres - Ligne 1: Velocity (en haut)
        Node {
            visible: root.showValues
            position: Qt.vector3d(0, 0, -70)  // Position Z de base
            eulerRotation: Qt.vector3d(-90, 0, 180)
            scale: Qt.vector3d(0.35, 0.35, 0.35)
            
            // Label "V:" pour Velocity
            LEDText3D {
                position: Qt.vector3d(-50, 400, 0)  // X positif pour apparaître en haut
                text: "V:"
                textColor: "#FF6B35"  // Orange/rouge pour différencier
                letterHeight: 12
                letterSpacing: 8
                segmentWidth: 2
                segmentDepth: 0.5
            }
            
            // Centaines
            DigitLED3D {
                position: Qt.vector3d(-30, 400, 0)  // X négatif, espacement augmenté
                value: Math.floor(root.velocity / 100)
                // Actif seulement si velocity >= 100 (pas un zéro de tête)
                active: root.velocity >= 100
                activeColor: "#FF6B35"    // Orange/rouge
                inactiveColor: "#331100"  // Orange foncé
            }
            
            // Dizaines
            DigitLED3D {
                position: Qt.vector3d(0, 400, 0)  // Centre
                value: Math.floor((root.velocity % 100) / 10)
                // Actif seulement si velocity >= 10 (pas un zéro de tête)
                active: root.velocity >= 10
                activeColor: "#FF6B35"    // Orange/rouge
                inactiveColor: "#331100"  // Orange foncé
            }
            
            // Unités
            DigitLED3D {
                position: Qt.vector3d(30, 400, 0)  // X positif, espacement augmenté
                value: root.velocity % 10
                // Actif seulement si velocity > 0
                active: root.velocity > 0
                activeColor: "#FF6B35"    // Orange/rouge
                inactiveColor: "#331100"  // Orange foncé
            }
        }
        
        // Affichage des chiffres - Ligne 2: Aftertouch (en bas)
        Node {
            visible: root.showValues
            position: Qt.vector3d(0, 0, -70)  // Position Z de base
            eulerRotation: Qt.vector3d(-90, 0, 180)
            scale: Qt.vector3d(0.35, 0.35, 0.35)
            
            // Label "A:" pour Aftertouch
            LEDText3D {
                position: Qt.vector3d(-50, 30, 0)  // Y remis à la valeur d'origine
                text: "A:"
                textColor: "#00CED1"
                letterHeight: 12
                letterSpacing: 8
                segmentWidth: 2
                segmentDepth: 0.5
            }
            
            // Centaines
            DigitLED3D {
                position: Qt.vector3d(-30, 30, 0)  // Y remis à la valeur d'origine
                value: Math.floor(root.aftertouch / 100)
                // Actif seulement si aftertouch >= 100 (pas un zéro de tête)
                active: root.aftertouch >= 100
                activeColor: "#00CED1"    // Turquoise
                inactiveColor: "#003333"  // Turquoise foncé
            }
            
            // Dizaines
            DigitLED3D {
                position: Qt.vector3d(0, 30, 0)  // Y remis à la valeur d'origine
                value: Math.floor((root.aftertouch % 100) / 10)
                // Actif seulement si aftertouch >= 10 (pas un zéro de tête)
                active: root.aftertouch >= 10
                activeColor: "#00CED1"    // Turquoise
                inactiveColor: "#003333"  // Turquoise foncé
            }
            
            // Unités
            DigitLED3D {
                position: Qt.vector3d(30, 30, 0)  // Y remis à la valeur d'origine
                value: root.aftertouch % 10
                // Actif seulement si aftertouch > 0
                active: root.aftertouch > 0
                activeColor: "#00CED1"    // Turquoise
                inactiveColor: "#003333"  // Turquoise foncé
            }
        }
    }
}
