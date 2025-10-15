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
    property real duration: 1000  // Durée en ms
    
    // Position
    property real currentY: spawnHeight + cubeHeight
    property real currentX: targetX
    property real cubeZ: -50
    property real cubeSize: 0.4  // Taille proportionnelle à la vélocité
    
    // Calculer la hauteur du cube basée sur la durée
    property real cubeHeight: Math.max(0.1, (duration / 1000.0) * fallSpeed / 2.0)
    
    // Position du cube - currentY représente la position du CENTRE du cube
    position: Qt.vector3d(currentX, currentY, cubeZ)
    scale: Qt.vector3d(
        (velocity / 127.0 * 0.8 + 0.2) * cubeSize,  // Largeur selon vélocité
        cubeHeight*cubeSize/20,  // Hauteur selon durée
        cubeSize     // Profondeur fixe
    )
    
    source: "#Cube"
    
    materials: [
        CustomMaterial {
            id: cubeMaterial
            
            // ===== CHOIX DU SHADER =====
            // Décommente celui que tu veux tester :
            
            // EFFETS MUSICAUX (recommandés)
            // ---------------------------
            // Tremolo seul (pulsation de largeur)
            //vertexShader: "shaders/tremolo.vert"
            
            // Vibrato seul (ondulation latérale)
            //vertexShader: "shaders/vibrato.vert"
            
            // Tremolo + Vibrato combinés (contrôle séparé)
            vertexShader: "shaders/tremolo_vibrato.vert"
            
            // AUTRES EFFETS
            // -------------
            // Squash & Stretch (élastique cartoon)
            //vertexShader: "shaders/squash.vert"
            
            // Bend uniforme (courbure douce)
            //vertexShader: "shaders/bend_uniform.vert"
            
            // Balancement simple (oscillation globale)
            //vertexShader: "shaders/bend.vert"
            
            fragmentShader: "shaders/bend.frag"
            
            property color baseColor: cubeColor
            property real metalness: 0.7
            property real roughness: 0.2
            property real time: 0  // Temps pour l'animation (en ms)
            
            // Intensités des effets musicaux (0.0 = désactivé, 0.15 = standard, 0.3 = fort)
            property real tremoloIntensity: 0.15  // Variation de largeur
            property real vibratoIntensity: 1.12  // Ondulation latérale
            
            // Fréquences (vitesse) des effets musicaux (Hz)
            property real tremoloSpeed: 4.0  // 4 Hz = 4 oscillations/seconde (standard)
            property real vibratoSpeed: 5.0  // 5 Hz = 5 oscillations/seconde (standard)
            
            shadingMode: CustomMaterial.Shaded
            
            // Animation continue du temps pour les oscillations
            NumberAnimation on time {
                from: 0
                to: 100000  // Grande valeur pour que ça continue longtemps
                duration: 100000
                running: true
                loops: Animation.Infinite
            }
        }
    ]
    
    // Animation de chute
    // Le cube tombe jusqu'à ce que le haut du cube atteigne targetY (noteOff)
    // currentY est la position du CENTRE du cube
    // Le bas du cube est à currentY - cubeHeight / 2
    // Le haut du cube est à currentY + cubeHeight / 2
    // On veut que le haut atteigne targetY, donc currentY + cubeHeight / 2 doit atteindre targetY
    // Donc currentY doit atteindre targetY - cubeHeight / 2
    NumberAnimation on currentY {
        id: fallAnimation
        from: currentY  // Le centre du cube est à spawnHeight au début
        to: targetY - cubeHeight // Le haut du cube est à targetY à la fin
        duration: Math.max(100, (spawnHeight - (targetY - cubeHeight*2)) / fallSpeed * 1000)
        running: false  // Ne pas démarrer automatiquement
        
        onFinished: {
            cubeModel.destroy()
        }
    }
    
    Component.onCompleted: {
        fallAnimation.start()
    }
}
