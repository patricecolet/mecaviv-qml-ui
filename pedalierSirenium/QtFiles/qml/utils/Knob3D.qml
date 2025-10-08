import QtQuick
import QtQuick3D

Node {
    id: knob3D
    
    property real value: 0  // -127 à 127
    property real angle: 0  // angle en degrés
    property color knobColor: "#606060"
    property color indicatorColor: "#00ff00"
    property real knobRadius: 20
    property real knobHeight: 15
    
    // Convertir la valeur en angle
    function valueToAngle(val) {
        return (val / 127) * 150;  // -127 à 127 -> -150° à 150°
    }
    
    // Convertir l'angle en valeur
    function angleToValue(ang) {
        return (ang / 150) * 127;
    }
    
    onValueChanged: {
        angle = valueToAngle(value);
    }
    
    // Corps du knob
    Model {
        id: knobBody
        source: "#Cylinder"
        scale: Qt.vector3d(knobRadius/50, knobHeight/100, knobRadius/50)
        
        materials: [
            PrincipledMaterial {
                baseColor: knob3D.knobColor
                metalness: 0.7
                roughness: 0.3
            }
        ]
        
        // Indicateur de position
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, knobHeight/2, knobRadius * 0.8)
            scale: Qt.vector3d(0.1, 0.1, 0.3)
            eulerRotation.y: knob3D.angle
            
            materials: [
                PrincipledMaterial {
                    baseColor: knob3D.indicatorColor
                    metalness: 0.5
                    roughness: 0.2
                }
            ]
        }
    }
    
    // Zone de détection pour la souris (invisible)
    Model {
        id: pickArea
        source: "#Cylinder"
        scale: Qt.vector3d((knobRadius*1.2)/50, (knobHeight*1.5)/100, (knobRadius*1.2)/50)
        opacity: 0
        pickable: true
        
        property real startY: 0
        property real startValue: 0
        property bool isDragging: false
    }
}
