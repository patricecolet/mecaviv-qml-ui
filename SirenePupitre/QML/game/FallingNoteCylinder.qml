import QtQuick
import QtQuick3D

// FallingNote basé sur Cylinder avec shader pour transformation cube + queue
Model {
    id: noteModel
    
    // Propriétés publiques (compatibles avec FallingCube)
    property real targetY: 0
    property real targetX: 0
    property real spawnHeight: 500
    property real fallSpeed: 150
    property color cubeColor: "#00CED1"
    property real velocity: 127  // Vélocité de la note (0-127)
    property real duration: 1000  // Durée en ms
    property real releaseTime: 500  // Durée du release en ms
    
    // Propriétés calculées
    property real cubeZ: -50
    property real cubeSize: 0.4
    property real sustainHeight: Math.max(0.1, (duration / 1000.0) * fallSpeed / 2.0)
    property real releaseHeight: Math.max(0.05, (releaseTime / 1000.0) * fallSpeed / 2.0)
    property real totalHeight: sustainHeight + releaseHeight
    property real releaseRatio: releaseHeight / totalHeight
    property real baseWidth: (velocity / 127.0 * 0.8 + 0.2) * cubeSize
    
    // Position
    property real currentY: spawnHeight + totalHeight
    property real currentX: targetX
    
    // Geometry
    source: "#Cylinder"
    position: Qt.vector3d(currentX, currentY, cubeZ)
    
    // Scale : hauteur totale (sustain + release)
    scale: Qt.vector3d(
        baseWidth,
        totalHeight * cubeSize / 20,
        cubeSize
    )
    
    materials: [
        CustomMaterial {
            vertexShader: "shaders/cylinder_to_cube_tapered.vert"
            fragmentShader: "shaders/release_gradient.frag"
            
            property color baseColor: cubeColor
            property real metalness: 0.7
            property real roughness: 0.2
            property real time: 0
            
            // Paramètres de release
            property real releaseRatio: noteModel.releaseRatio
            
            // Effets musicaux
            property real tremoloIntensity: 0.15
            property real vibratoIntensity: 1.12
            property real tremoloSpeed: 4.0
            property real vibratoSpeed: 5.0
            
            shadingMode: CustomMaterial.Shaded
            
            // Animation temps
            NumberAnimation on time {
                from: 0
                to: 100000
                duration: 100000
                running: true
                loops: Animation.Infinite
            }
        }
    ]
    
    // Animation de chute
    NumberAnimation on currentY {
        id: fallAnimation
        from: currentY
        to: targetY - totalHeight
        duration: Math.max(100, (spawnHeight - (targetY - totalHeight * 2)) / fallSpeed * 1000)
        running: false
        
        onFinished: {
            noteModel.destroy()
        }
    }
    
    Component.onCompleted: {
        fallAnimation.start()
    }
}

