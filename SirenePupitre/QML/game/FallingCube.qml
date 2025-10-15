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
    property real currentY: spawnHeight + cubeHeight * 50.0
    property real currentX: targetX
    property real cubeZ: -50
    property real cubeSize: 0.4  // Taille proportionnelle à la vélocité
    
    // Calculer la hauteur du cube basée sur la durée
    property real cubeHeight: Math.max(0.1, (duration / 1000.0) * fallSpeed / 100.0)
    
    // Position du cube - currentY représente la position du CENTRE du cube
    position: Qt.vector3d(currentX, currentY, cubeZ)
    scale: Qt.vector3d(
        (velocity / 127.0 * 0.8 + 0.2) * cubeSize,  // Largeur selon vélocité
        cubeHeight,  // Hauteur selon durée
        cubeSize     // Profondeur fixe
    )
    
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
    // Le cube tombe jusqu'à ce que le haut du cube atteigne targetY (noteOff)
    // currentY est la position du CENTRE du cube
    // Le bas du cube est à currentY - cubeHeight / 2
    // Le haut du cube est à currentY + cubeHeight / 2
    // On veut que le haut atteigne targetY, donc currentY + cubeHeight / 2 doit atteindre targetY
    // Donc currentY doit atteindre targetY - cubeHeight / 2
    NumberAnimation on currentY {
        id: fallAnimation
        from: currentY  // Le centre du cube est à spawnHeight au début
        to: targetY - cubeHeight * 50.0  // Le haut du cube est à targetY à la fin
        duration: Math.max(200, (spawnHeight - (targetY - cubeHeight / 2)) / fallSpeed * 1000)
        running: false  // Ne pas démarrer automatiquement
        
        onFinished: {
            cubeModel.destroy()
        }
    }
    
    Component.onCompleted: {
        fallAnimation.start()
    }
}
