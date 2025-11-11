import QtQuick
import QtQuick3D
import GameGeometry 1.0

// Test ultra-simple avec un triangle
Model {
    id: testModel
    
    // Propriétés requises par MelodicLine3D (on les ignore)
    property real targetY: 0
    property real targetX: 0
    property real spawnHeight: 500
    property real fallSpeed: 150
    property color cubeColor: "#00CED1"
    property real velocity: 127
    property real duration: 1000
    
    geometry: SimpleTestGeometry {}
    
    position: Qt.vector3d(targetX, spawnHeight, -50)
    scale: Qt.vector3d(50, 50, 50)
    
    materials: [
        PrincipledMaterial {
            baseColor: cubeColor
            lighting: PrincipledMaterial.NoLighting  // Pas d'éclairage pour debug
        }
    ]
}

