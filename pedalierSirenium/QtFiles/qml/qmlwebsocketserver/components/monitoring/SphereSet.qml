import QtQuick
import QtQuick3D

Node {
    id: root
    
    // Sphère visible SEULEMENT quand sélectionnée
    visible: root.isCurrent
    
    property bool isActive: false
    property bool isCurrent: false
    property bool pedalActive: false
    property color inactiveColor
    
    property real bottomDefaultScale: 0.7
    property real bottomSelectedScale: 0.9
    property real bottomUnselectedScale: 0.5
    
    property bool pulseInProgress: false

    // Supprimer le topSphereModel et ne garder que la sphère du bas
    
    Model {
        id: bottomSphereModel
        scale: Qt.vector3d(
            root.isActive ? (root.isCurrent ? root.bottomSelectedScale : root.bottomUnselectedScale) : root.bottomDefaultScale,
            root.isActive ? (root.isCurrent ? root.bottomSelectedScale : root.bottomUnselectedScale) : root.bottomDefaultScale,
            root.isActive ? (root.isCurrent ? root.bottomSelectedScale : root.bottomUnselectedScale) : root.bottomDefaultScale
        )
        position: Qt.vector3d(0, -100, 0)
        source: "#Sphere"
        materials: [ DefaultMaterial {
            id: bottomSphereMaterial
            diffuseColor: root.inactiveColor
        }]
    }

    function pulseSphere(isFirstBeat, beatDuration) {
        if (root.isCurrent) {
            // Arrêter le timer précédent s'il est en cours
            if (pulseTimer.running) {
                pulseTimer.stop();
            }
            
            // Définir la couleur active
            bottomSphereMaterial.diffuseColor = isFirstBeat ? "red" : "lime";
            
            // Utiliser beatDuration directement car c'est déjà la moitié du temps
            pulseTimer.interval = beatDuration;
            pulseTimer.restart();
        }
    }

    Timer {
        id: pulseTimer
        repeat: false
        onTriggered: {
            // Revenir à la couleur inactive après exactement la moitié d'un temps
            bottomSphereMaterial.diffuseColor = root.inactiveColor;
        }
    }

    PropertyAnimation {
        id: pulseAnimation
        target: bottomSphereMaterial
        property: "diffuseColor"
        to: root.inactiveColor
        duration: 200
        
        onFinished: {
            if (bottomSphereMaterial.diffuseColor !== root.inactiveColor) {
                bottomSphereMaterial.diffuseColor = root.inactiveColor;
            }
        }
    }
}