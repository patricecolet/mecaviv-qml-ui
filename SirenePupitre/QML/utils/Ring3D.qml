import QtQuick
import QtQuick3D

Node {
    id: root
    
    property real radius: 50
    property real thickness: 10
    property int segments: 32
    property color ringColor: Qt.rgba(0.5, 0.5, 0.5, 1)
    property real metalness: 0.1
    property real roughness: 0.1
    
    Repeater3D {
        model: root.segments
        
        Model {
            source: "#Cylinder"
            
            property real angle: (index * 360 / root.segments) * Math.PI / 180
            property real nextAngle: ((index + 1) * 360 / root.segments) * Math.PI / 180
            property real midAngle: angle + (nextAngle - angle) / 2
            property real segmentLength: 2 * root.radius * Math.sin(Math.PI / root.segments)
            property real overlapFactor: 1.05  // 2% de chevauchement
            // Position au centre du segment
            position: Qt.vector3d(
                Math.cos(midAngle) * root.radius,
                Math.sin(midAngle) * root.radius,
                0
            )
            
            // Pour que les cylindres soient bout à bout :
            // Le cylindre doit être perpendiculaire au rayon (tangent au cercle)
            eulerRotation: Qt.vector3d(
                0,
                0,
                midAngle * 180 / Math.PI
            )
            
            // Le cylindre s'étend le long de son axe Y
            // Donc hauteur = longueur du segment
            scale: Qt.vector3d(
                root.thickness / 100,  // Diamètre X
                (segmentLength * overlapFactor) / 100,   // Hauteur Y (divisé par 200 car c'est un rayon)
                root.thickness / 100   // Diamètre Z
            )
            
            materials: PrincipledMaterial {
                baseColor: root.ringColor
                metalness: root.metalness
                roughness: root.roughness
            }
        }
    }
}
