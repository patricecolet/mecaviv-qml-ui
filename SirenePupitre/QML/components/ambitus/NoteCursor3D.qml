import QtQuick
import QtQuick3D
import "../../../../shared/qml/common"

Node {
    id: root
    
    // Propriétés requises
    required property real currentNoteMidi
    required property real staffWidth
    required property real staffPosX
    required property real lineSpacing
    required property real lineThickness
    required property string clef
    required property real ambitusMin
    required property real ambitusMax
    
    // Propriétés optionnelles
    property color cursorColor: Qt.rgba(1, 0.2, 0.2, 0.8)
    property real cursorWidth: 3
    property real cursorOffsetY: 30  // Distance sous la première note
    property bool showNoteHighlight: true
    property int octaveOffset: 0  // Par défaut pas de décalage
    
    // AJOUTER ces nouvelles propriétés pour le highlight
    property color highlightColor: Qt.rgba(1, 1, 0, 0.6)
    property real highlightSize: 0.25
    
    // AJOUTER pour déboguer et forcer la mise à jour
    onCursorWidthChanged: {
        // Forcer la mise à jour du scale
        if (cursorModel) {
            cursorModel.scale = Qt.vector3d(cursorWidth / 100, Math.abs(cursorHeight) / 100, 0.02);
        }
    }
    
    onCursorColorChanged: {
        if (cursorModel && cursorModel.materials[0]) {
            cursorModel.materials[0].baseColor = cursorColor;
            cursorModel.materials[0].opacity = cursorColor.a;
        }
    }
    
    onHighlightColorChanged: {
        if (highlightModel && highlightModel.materials && highlightModel.materials.length > 0) {
            highlightModel.materials[0].baseColor = highlightColor;
        }
    }
    
    onHighlightSizeChanged: {
        if (highlightModel) {
            highlightModel.scale = Qt.vector3d(highlightSize, highlightSize * 0.8, highlightSize);
        }
    }
        
    // Instances
    NotePositionCalculator {
        id: noteCalc
    }
    
    // Calculs de position
    property real firstNoteY: noteCalc.calculateNoteYPosition(ambitusMin + (octaveOffset * 12), lineSpacing, clef)
    property real bottomY: firstNoteY - cursorOffsetY  // Position du bas du curseur
    property real currentNoteY: noteCalc.calculateNoteYPosition(currentNoteMidi + (octaveOffset * 12), lineSpacing, clef)  // Position de la note actuelle
    property real cursorHeight: currentNoteY - bottomY  // Hauteur jusqu'à la note actuelle
    property real cursorCenterY: bottomY + cursorHeight/2  // Centre du curseur
    
    // Position directe du curseur
    x: noteCalc.calculateNoteXPosition(currentNoteMidi, ambitusMin, ambitusMax, staffPosX, staffWidth)
    y: 0
    
    // Ligne verticale du curseur (du bas jusqu'à la note actuelle)
    Model {
        id: cursorModel  // AJOUTER cet id
        source: "#Cube"
        scale: Qt.vector3d(root.cursorWidth / 100, Math.abs(root.cursorHeight) / 100, 0.02)
        position: Qt.vector3d(0, root.cursorCenterY, 0.5)
        
        materials: PrincipledMaterial {
            baseColor: root.cursorColor
            metalness: 0.0
            roughness: 0.8
            opacity: root.cursorColor.a
        }
    }
    
    // Et définir le material séparément :
    PrincipledMaterial {
        id: highlightMaterial
        baseColor: root.highlightColor
        metalness: 0.0
        roughness: 0.2
    }
    
    // Highlight de la note actuelle (sphère jaune)
    Model {
        id: highlightModel
        visible: root.showNoteHighlight
        source: "#Sphere"
        scale: Qt.vector3d(root.highlightSize, root.highlightSize * 0.8, root.highlightSize)
        position: Qt.vector3d(0, root.currentNoteY, 0.3)
        materials: [highlightMaterial]  // Utiliser le material défini séparément
    }
}
