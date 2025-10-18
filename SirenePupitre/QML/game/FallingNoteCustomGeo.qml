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
    property real cubeSize: 1.0
    property real totalDurationHeight: Math.max(0.1, (duration / 1000.0) * fallSpeed )
    property real releaseHeight: Math.max(0.05, (releaseTime / 1000.0) * fallSpeed)
    property real totalHeight: totalDurationHeight + releaseHeight  // Release additif
    
    // Position et profondeur
    property real currentY: spawnHeight
    property real currentX: targetX
    property real currentZ: -500  // Départ du fond de la scène
    property real targetZ: -5  // Z de la portée (arrivée)
    
    // Calcul du sustain pour le shader (modulation proportionnelle)
    property real attackRatio: attackTime > 0 ? Math.min(1.0, attackTime / duration) : 0.0
    property real sustainHeight: totalDurationHeight * (1.0 - attackRatio)
    
    // Offset de clipping - constant maintenant que Z=0 (même plan que la portée)
    property real clipOffset: 0  // Devrait être constant pour toutes les notes!
    
    // Clipping supérieur relatif (suit la note automatiquement)
    property real clipYTopLocal: totalHeight * 1.0  // Position locale de troncature (1.0 = sommet, désactivé par défaut)
    
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
    position: Qt.vector3d(currentX, currentY, currentZ)
    
    // Scale simple et uniforme (à ajuster manuellement pour correspondre au timing)
    scale: Qt.vector3d(cubeSize*4, cubeSize, cubeSize)
    
    // Fonction de troncature pour mode monophonique
    // Définit la position locale où tronquer (0 = bas de la note, totalHeight = sommet)
    function truncateNote(atLocalY) {
        clipYTopLocal = atLocalY
    }
    
    materials: [
        CustomMaterial {
            id: noteMaterial
            
            // Tremolo + Vibrato combinés
            vertexShader: "shaders/tremolo_vibrato.vert"
            fragmentShader: "shaders/bend.frag"
            
            property color baseColor: cubeColor
            property real metalness: 0.0
            property real roughness: 0.0
            property real time: 0  // Temps pour l'animation (en ms)
            property real clipY: noteModel.targetY + noteModel.clipOffset  // Ligne de clipping bas (espace monde)
            property real clipYTopLocal: noteModel.clipYTopLocal  // Ligne de clipping haut (espace local, suit la note)
            
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
    
    // Animation de chute - Passe à travers targetY, le shader clippe
    NumberAnimation on currentY {
        id: fallAnimation
        from: spawnHeight
        to: targetY - totalHeight * cubeSize  // Continue sous targetY pour clipping progressif
        duration: Math.max(100, (spawnHeight - (targetY - totalHeight * cubeSize)) / fallSpeed * 1000)
        running: false
        
        onFinished: {
            noteModel.destroy()
        }
    }
    
/*     // Animation de profondeur - Se rapproche plus vite pour arriver au bon Z avant la note
    NumberAnimation on currentZ {
        id: depthAnimation
        from: -500  // Fond de la scène
        to: targetZ  // Position de la portée
        duration: Math.max(100, fallAnimation.duration - (totalHeight*2 * cubeSize / fallSpeed * 1000))  // Arrive au bon Z avant la note
        running: false
    } */
    
    Component.onCompleted: {
        fallAnimation.start()
    }
}

