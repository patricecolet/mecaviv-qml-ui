import QtQuick
import QtQuick3D

Node {
    id: root
    
    property string clefType: "treble" // "treble" ou "bass"
    property real clefScale: 80.0  // Échelle à 80% de la taille initiale
    property color clefColor: Qt.rgba(0.7, 0.7, 0.7, 1)
    property real staffWidth: 600
    property real lineSpacing: 20
    
    // Offsets optionnels pour ajustements fins
    property real clefOffsetX: 0
    property real clefOffsetY: 0
    
    // Position X : marge depuis le bord gauche de la portée
    x: -staffWidth/2 + 50 + clefOffsetX
    
    // Position Y : directement sur la ligne de référence !
    // Les modèles 3D ont leur origine (0,0,0) placée sur la ligne de référence
    y: {
        if (clefType === "treble") {
            // Sol4 est sur la 2ème ligne (Y = -1 * lineSpacing)
            return -lineSpacing + clefOffsetY
        } else {  // bass
            // Fa3 est sur la 4ème ligne (Y = +1 * lineSpacing)
            return lineSpacing + clefOffsetY
        }
    }
    
    z: 0.1  // Légèrement devant les lignes de la portée
    
    Component.onCompleted: {
        console.log("🎼 Clef3D - Type:", clefType, "- Position:", x, y, z, "- Scale:", clefScale)
    }
    
    // Modèle 3D avec origine (0,0) sur la ligne de référence
    Model {
        id: clefModel
        source: clefType === "treble" 
            ? "qrc:/QML/utils/meshes/TrebleKey.mesh"  // Clé de Sol (origine sur Sol4)
            : "qrc:/QML/utils/meshes/BassKey.mesh"    // Clé de Fa (origine sur Fa3)
        
        scale: Qt.vector3d(clefScale, clefScale, clefScale)
        position: Qt.vector3d(0, 0, 0)
        
        materials: PrincipledMaterial {
            baseColor: root.clefColor
            metalness: 0.0
            roughness: 0.8
        }
        
        Component.onCompleted: {
            console.log("🎨 Clef model loaded:", clefType, "from", source)
        }
    }
}