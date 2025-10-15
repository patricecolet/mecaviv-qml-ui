import QtQuick
import QtQuick3D
import GameGeometry 1.0

// FallingNote avec géométrie C++ custom (TaperedBoxGeometry)
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
    property real releaseTime: 1000  // Durée du release en ms
    
    // Propriétés calculées
    property real cubeZ: -50
    property real cubeSize: 0.4
    property real sustainHeight: Math.max(0.1, (duration / 1000.0) * fallSpeed / 2.0)
    property real releaseHeight: Math.max(0.05, (releaseTime / 1000.0) * fallSpeed)
    property real totalHeight: sustainHeight + releaseHeight
    property real baseWidth: (velocity / 127.0 * 0.8 + 0.2) * cubeSize
    
    // Position
    property real currentY: spawnHeight + totalHeight
    property real currentX: targetX
    
    // Géométrie custom C++ avec sustainHeight dynamique
    geometry: TaperedBoxGeometry {
        sustainHeight: noteModel.sustainHeight
        releaseHeight: noteModel.releaseHeight  // Utilisé pour le calcul futur
        width: 100.0
        depth: 100.0
    }
    
    position: Qt.vector3d(currentX, currentY, cubeZ)
    
    // Scale calculé selon la durée (comme FallingCube)
    scale: Qt.vector3d(
        baseWidth,
        sustainHeight * cubeSize / 20,
        cubeSize
    )
    
    materials: [
        CustomMaterial {
            id: noteMaterial
            
            // Tremolo + Vibrato combinés
            vertexShader: "shaders/tremolo_vibrato.vert"
            fragmentShader: "shaders/bend.frag"
            
            property color baseColor: cubeColor
            property real metalness: 0.7
            property real roughness: 0.2
            property real time: 0  // Temps pour l'animation (en ms)
            
            // Intensités des effets musicaux
            property real tremoloIntensity: 0.15  // Variation de largeur
            property real vibratoIntensity: 1.12  // Ondulation latérale
            
            // Fréquences (vitesse) des effets musicaux (Hz)
            property real tremoloSpeed: 4.0  // 4 Hz
            property real vibratoSpeed: 5.0  // 5 Hz
            
            shadingMode: CustomMaterial.Shaded
            
            // Animation continue du temps pour les oscillations
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
        console.log("FallingNoteCustomGeo created - sustainHeight:", sustainHeight, 
                   "releaseHeight:", releaseHeight, "geometry:", geometry,
                   "position:", position, "scale:", scale, "visible:", visible)
        fallAnimation.start()
    }
}

