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
    property real attackTime: 0  // Durée de l'attaque en ms (contrôlée par CC73)
    property real releaseTime: 0  // Durée du release en ms (contrôlée par CC72)
    
    // Paramètres de modulation (contrôlés par MIDI CC) - Désactivés par défaut
    property real vibratoAmount: 0.0  // CC1
    property real vibratoRate: 5.0    // CC9
    property real tremoloAmount: 0.0  // CC92
    property real tremoloRate: 4.0    // CC15
    
    // Propriétés calculées
    property real cubeZ: -50
    property real cubeSize: 1.0
    property real totalDurationHeight: Math.max(0.1, (duration / 1000.0) * fallSpeed )
    property real releaseHeight: Math.max(0.05, (releaseTime / 1000.0) * fallSpeed)
    property real totalHeight: totalDurationHeight + releaseHeight  // Release additif
    
    // Position simplifiée - Le centre de l'objet C++ est au point NOTE ON (fin attack/début sustain)
    property real currentY: spawnHeight  + totalHeight
    property real currentX: targetX
    
    // Calcul du sustain pour le shader (modulation proportionnelle)
    property real attackRatio: attackTime > 0 ? Math.min(1.0, attackTime / duration) : 0.0
    property real sustainHeight: totalDurationHeight * (1.0 - attackRatio)
    
    // Géométrie custom C++ - Le C++ calcule TOUT (ADSR, effectiveVelocity, proportions)
    // Passe les données musicales brutes, le C++ s'occupe du reste
    geometry: TaperedBoxGeometry {
        attackTime: noteModel.attackTime            // Temps d'attack en ms
        duration: noteModel.duration                // Durée de la note en ms
        totalHeight: noteModel.totalDurationHeight  // Hauteur visuelle pour la note
        releaseHeight: noteModel.releaseHeight      // Hauteur visuelle pour le release
        velocity: noteModel.velocity                // Vélocité MIDI (0-127)
        baseSize: 20.0                              // Taille de référence en unités visuelles
    }
    
    // Position - Le centre C++ (Y=0) correspond au point NOTE ON
    position: Qt.vector3d(currentX, currentY, cubeZ)
    
    // Scale simple et uniforme (à ajuster manuellement pour correspondre au timing)
    scale: Qt.vector3d(cubeSize*2, cubeSize, cubeSize)
    
    materials: [
        CustomMaterial {
            id: noteMaterial
            
            // Tremolo + Vibrato combinés
            vertexShader: "shaders/tremolo_vibrato.vert"
            fragmentShader: "shaders/bend.frag"
            
            property color baseColor: cubeColor
            property real metalness: 1.0
            property real roughness: 0.5
            property real time: 0  // Temps pour l'animation (en ms)
            
            // Intensités des effets musicaux (contrôlées par MIDI CC)
            property real tremoloIntensity: noteModel.tremoloAmount  // CC92
            property real vibratoIntensity: noteModel.vibratoAmount  // CC1
            
            // Fréquences (vitesse) des effets musicaux (contrôlées par MIDI CC)
            property real tremoloSpeed: noteModel.tremoloRate  // CC15
            property real vibratoSpeed: noteModel.vibratoRate  // CC9
            
            // Hauteur du sustain pour modulation proportionnelle
            property real sustainHeightNormalized: noteModel.sustainHeight
            
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
    
    // Animation de chute - Le centre de l'objet atteint targetY
    NumberAnimation on currentY {
        id: fallAnimation
        from: spawnHeight + (totalDurationHeight / 2.0) * cubeSize
        to: targetY + (totalDurationHeight / 2.0) * cubeSize
        duration: Math.max(100, (spawnHeight - targetY)/ fallSpeed * 1000)
        running: false
        
        onFinished: {
            noteModel.destroy()
        }
    }
    
    Component.onCompleted: {
        console.log("FallingNoteCustomGeo created - attackTime:", attackTime,
                   "duration:", duration, "totalDurationHeight:", totalDurationHeight,
                   "releaseHeight:", releaseHeight, "velocity:", velocity,
                   "position:", position, "scale:", scale, "visible:", visible)
        fallAnimation.start()
    }
}

