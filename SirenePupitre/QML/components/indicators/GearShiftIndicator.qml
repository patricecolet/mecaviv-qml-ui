import QtQuick
import QtQuick3D
import "../../../../shared/qml/common"

Node {
    id: root
    
    // Propriétés publiques
    property int position: 0 // Position du levier (0-3)
    property string mode: "SEMITONE" // Mode actuel
    
    onModeChanged: {
    }
    
    onPositionChanged: {
    }
    
    // Propriétés visuelles
    property real baseSize: 70          // Plus large
    property real gateLength: 40        // Plus long
    property real gateWidth: 10         // Plus épais
    property real leverHeight: 40
    property real knobRadius: 12
    property color baseColor: Qt.rgba(0.2, 0.2, 0.2, 1)
    property color gateColor: Qt.rgba(0.4, 0.4, 0.4, 1)
    property color leverColor: Qt.rgba(0.8, 0.8, 0.8, 1)
    property color knobColor: Qt.rgba(0.9, 0.4, 0.1, 1)
    property bool showValues:true
    // Nouvelle rotation pour vue de face
    eulerRotation: Qt.vector3d(90, 10, 0)
    
    // Base
    Model {
        source: "#Cylinder"
        scale: Qt.vector3d(baseSize/50, 0.05, baseSize/50)
        position: Qt.vector3d(0, 0, 0)
        materials: PrincipledMaterial {
            baseColor: root.baseColor
            metalness: 0.7
            roughness: 0.3
        }
    }
    
    // Grille en croix (gate)
    Node {
        // Barre horizontale
        Model {
            source: "#Cube"
            scale: Qt.vector3d(gateLength*2/100, 0.02, gateWidth/100)
            position: Qt.vector3d(0, 1, 0)
            materials: PrincipledMaterial {
                baseColor: root.gateColor
                metalness: 0.5
                roughness: 0.4
            }
        }
        
        // Barre verticale
        Model {
            source: "#Cube"
            scale: Qt.vector3d(gateWidth/100, 0.02, gateLength*2/100)
            position: Qt.vector3d(0, 1, 0)
            materials: PrincipledMaterial {
                baseColor: root.gateColor
                metalness: 0.5
                roughness: 0.4
            }
        }
    }
    
    // Positions définitives:
    // 0: Centre (neutre)
    // 1: Gauche
    // 2: Bas  
    // 3: Droite
    // 4: Haut
    
    // Levier animé qui pivote depuis la base
    Node {
        id: leverNode
        
        // Angles d'inclinaison (en degrés)
        property real tiltAngle: 25
        
        property real targetRotationX: {
            switch(root.position) {
                case 0: return 0            // Centre - neutre
                case 2: return tiltAngle    // Bas - penche vers l'arrière
                case 4: return -tiltAngle   // Haut - penche vers l'avant
                default: return 0
            }
        }
        
        property real targetRotationZ: {
            switch(root.position) {
                case 0: return 0            // Centre - neutre
                case 1: return tiltAngle    // Gauche - penche à gauche
                case 3: return -tiltAngle   // Droite - penche à droite
                default: return 0
            }
        }
        
        // Position fixe au centre
        position: Qt.vector3d(0, 0, 0)
        
        // Pivot depuis la base
        eulerRotation: Qt.vector3d(rotX, 0, rotZ)
        
        property real rotX: targetRotationX
        property real rotZ: targetRotationZ
        
        // Animations fluides
        Behavior on rotX {
            NumberAnimation {
                duration: 300
                easing.type: Easing.InOutQuad
            }
        }
        
        Behavior on rotZ {
            NumberAnimation {
                duration: 300
                easing.type: Easing.InOutQuad
            }
        }
        
        // Tige du levier
        Model {
            source: "#Cylinder"
            scale: Qt.vector3d(0.06, leverHeight/100, 0.06)
            position: Qt.vector3d(0, leverHeight/2, 0)
            materials: PrincipledMaterial {
                baseColor: root.leverColor
                metalness: 0.9
                roughness: 0.1
            }
        }
        
        // Pommeau
        Model {
            source: "#Sphere"
            scale: Qt.vector3d(knobRadius/50, knobRadius/50, knobRadius/50)
            position: Qt.vector3d(0, leverHeight, 0)
            materials: PrincipledMaterial {
                baseColor: root.knobColor
                metalness: 0.3
                roughness: 0.2
                emissiveFactor: Qt.vector3d(0.2, 0.08, 0)
            }
        }
    }
    
    // Indicateurs de position (sans labels hardcodés)
    Repeater3D {
        model: 5  // Maintenant 5 positions (0-4)
        Node {
            property real posX: {
                switch(index) {
                    case 0: return 0            // Centre
                    case 1: return -gateLength  // Gauche
                    case 3: return gateLength   // Droite
                    default: return 0
                }
            }
            property real posZ: {
                switch(index) {
                    case 0: return 0            // Centre
                    case 2: return gateLength   // Bas
                    case 4: return -gateLength  // Haut
                    default: return 0
                }
            }
            
            x: posX
            y: 2
            z: posZ
            
            // Indicateur de position (petit point lumineux)
            Model {
                source: "#Sphere"
                scale: Qt.vector3d(0.02, 0.02, 0.02)
                position: Qt.vector3d(0, 0, 0)
                materials: PrincipledMaterial {
                    baseColor: root.position === index ?
                        Qt.rgba(0, 1, 0, 1) :
                        Qt.rgba(0.3, 0.3, 0.3, 1)
                    emissiveFactor: root.position === index ?
                        Qt.vector3d(0, 0.5, 0) :
                        Qt.vector3d(0, 0, 0)
                }
            }
        }
    }
    
    // Mode affiché via overlay 2D dans ControllersPanel
}
