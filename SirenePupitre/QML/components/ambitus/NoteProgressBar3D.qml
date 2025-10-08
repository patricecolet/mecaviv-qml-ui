import QtQuick
import QtQuick3D
import "../../utils"

Node {
    id: root
    
    // Propriétés requises
    required property real currentNoteMidi
    required property real ambitusMin
    required property real ambitusMax
    required property real staffWidth
    required property real staffPosX
    
    // Nouvelles propriétés pour le positionnement
    property real lineSpacing: 20
    property string clef: "treble"
    property int octaveOffset: 0
    
    // Propriétés optionnelles
    property real barHeight: 5
    property real barOffsetY: 30  // Distance sous la première note
    property color backgroundColor: Qt.rgba(0.2, 0.2, 0.2, 0.5)
    property color progressColor: Qt.rgba(0.2, 0.8, 0.2, 0.8)
    property color cursorColor: Qt.rgba(1, 1, 1, 0.9)
    property real cursorSize: 10  // Taille du curseur sur la barre
    property bool showPercentage: true
    
    // Instances
    NotePositionCalculator {
        id: noteCalc
    }
    
    // Calcul de la position Y de la barre (sous la première note)
    property real firstNoteY: noteCalc.calculateNoteYPosition(ambitusMin + (octaveOffset * 12), lineSpacing, clef)
    property real barY: firstNoteY - barOffsetY
    
    // Position X en fonction de la note actuelle
    property real normalizedProgress: Math.max(0, Math.min(1, (currentNoteMidi - ambitusMin) / (ambitusMax - ambitusMin)))
    property real progressX: -staffWidth/2 + (normalizedProgress * staffWidth)
    
    // Positionner le node à la hauteur de la barre
    y: barY
    
    // Barre de fond (toute la largeur)
    Model {
        source: "#Cube"
        scale: Qt.vector3d(root.staffWidth / 100, root.barHeight / 100, 0.01)
        position: Qt.vector3d(root.staffPosX, 0, 0.2)
        
        materials: PrincipledMaterial {
            baseColor: root.backgroundColor
            metalness: 0.0
            roughness: 0.9
            opacity: root.backgroundColor.a
        }
    }
    
    // Barre de progression (jusqu'à la position actuelle)
    Model {
        visible: normalizedProgress > 0
        source: "#Cube"
        scale: Qt.vector3d((root.normalizedProgress * root.staffWidth) / 100, root.barHeight / 100, 0.01)
        position: Qt.vector3d(root.staffPosX - root.staffWidth/2 + (root.normalizedProgress * root.staffWidth)/2, 0, 0.3)
        
        materials: PrincipledMaterial {
            baseColor: root.progressColor
            metalness: 0.0
            roughness: 0.7
            opacity: root.progressColor.a
        }
    }
    
    // Curseur sur la barre (simple indicateur)
    Model {
        source: "#Sphere"
        scale: Qt.vector3d(root.cursorSize / 100, root.cursorSize / 100, root.cursorSize / 100)
        position: Qt.vector3d(root.progressX + root.staffPosX, 0, 0.4)
        
        materials: PrincipledMaterial {
            baseColor: root.cursorColor
            metalness: 0.2
            roughness: 0.3
            opacity: root.cursorColor.a
        }
    }
}
