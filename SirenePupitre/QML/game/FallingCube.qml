import QtQuick
import QtQuick3D

Model {
    id: cubeModel
    
    // Propriétés
    property real targetY: 0
    property real targetX: 0
    property real spawnHeight: 500
    property real fallSpeed: 150
    property color cubeColor: "#00CED1"
    property real velocity: 127  // Vélocité de la note (0-127)
    
    // Position
    property real currentY: spawnHeight
    property real currentX: targetX
    property real cubeZ: -50
    
    position: Qt.vector3d(currentX, currentY, cubeZ)
    scale: Qt.vector3d(velocity / 127.0 * 0.8 + 0.2, 1, 1)  // 20% à 100% uniquement sur X
    
    source: "#Cube"
    
    materials: [
        PrincipledMaterial {
            baseColor: cubeColor
            metalness: 0.7
            roughness: 0.2
            emissiveFactor: 0.5
        }
    ]
    
    // Animation de chute
    NumberAnimation on currentY {
        id: fallAnimation
        from: spawnHeight
        to: targetY
        duration: Math.max(100, (spawnHeight - targetY) / fallSpeed * 1000)
        running: true
        
        onFinished: {
            cubeModel.destroy()
        }
    }
}

