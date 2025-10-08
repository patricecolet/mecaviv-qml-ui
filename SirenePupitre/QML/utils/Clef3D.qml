import QtQuick
import QtQuick3D

Node {
    id: root
    
    property string clefType: "treble" // "treble" ou "bass"
    property real clefScale: 2.0  // Augmenté pour être plus visible
    property color clefColor: Qt.rgba(0.7, 0.7, 0.7, 1)
    property real staffWidth: 600
    property real lineSpacing: 20
    
    // Nouvelles propriétés pour un contrôle précis de la position
    property real clefOffsetX: 0  // Centré
    property real clefOffsetY: 0   // Centré
    
    // Position calculée
    x: -staffWidth/2 + clefOffsetX
    y: (clefType === "treble" ? -lineSpacing : lineSpacing) + clefOffsetY
    z: 0.1  // Légèrement devant les lignes
    
    Component.onCompleted: {
        console.log("🎼 Clef3D - Component loaded")
        console.log("🎼 Clef3D - Position:", x, y, z)
        console.log("🎼 Clef3D - Scale:", clefScale)
        console.log("🎼 Clef3D - Type:", clefType)
    }
    
    // Modèle 3D de clé de sol - Utilisation directe du fichier .mesh
    Model {
        id: clefModel
        source: "qrc:/QML/utils/meshes/Clef3D.mesh"
        scale: Qt.vector3d(clefScale, clefScale, clefScale)
        
        materials: PrincipledMaterial {
            baseColor: root.clefColor
            metalness: 0.0
            roughness: 0.8
        }
    }
}