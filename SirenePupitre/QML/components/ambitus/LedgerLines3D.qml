import QtQuick 2.15
import QtQuick3D

Node {
    id: root
    
    required property real noteY
    required property real noteX
    required property real lineSpacing
    required property real lineThickness
    
    property real lineLength: 40
    property color lineColor: Qt.rgba(0.8, 0.8, 0.8, 1)
    
    Repeater3D {
        model: {
            // Pas de lignes si la note est dans la portée
            if (noteY >= -2 * lineSpacing && noteY <= 2 * lineSpacing) return 0
            
            // Calculer le nombre de positions de lignes entre la portée et la note
            if (noteY < -2 * lineSpacing) {
                // Au-dessus de la portée
                // On compte combien de positions de lignes il y a entre -2*lineSpacing et noteY
                var firstLedgerLine = -3 * lineSpacing  // Première ligne supplémentaire
                if (noteY > firstLedgerLine) return 0  // La note n'atteint pas la première ligne supplémentaire
                return Math.floor((firstLedgerLine - noteY) / lineSpacing) + 1
            } else {
                // En-dessous de la portée
                var firstLedgerLine = 3 * lineSpacing  // Première ligne supplémentaire
                if (noteY < firstLedgerLine) return 0  // La note n'atteint pas la première ligne supplémentaire
                return Math.floor((noteY - firstLedgerLine) / lineSpacing) + 1
            }
        }
        
        Model {
            source: "#Cube"
            scale: Qt.vector3d(root.lineLength / 100, root.lineThickness / 100, 0.01)
            
            position: {
                var y
                if (root.noteY < -2 * root.lineSpacing) {
                    // Lignes au-dessus de la portée
                    y = -3 * root.lineSpacing - index * root.lineSpacing
                } else {
                    // Lignes en-dessous de la portée
                    y = 3 * root.lineSpacing + index * root.lineSpacing
                }
                return Qt.vector3d(root.noteX, y, 0)
            }
            
            materials: PrincipledMaterial {
                baseColor: root.lineColor
                metalness: 0.0
                roughness: 0.9
            }
        }
    }
}
