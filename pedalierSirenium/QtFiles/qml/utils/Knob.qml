import QtQuick
import QtQuick.Controls

/**
 * Knob.qml - Composant de bouton rotatif personnalisable
 * 
 * Un bouton rotatif interactif avec affichage de valeur configurable.
 * La valeur peut être modifiée par glissement vertical/horizontal, molette ou double-clic.
 * 
 * Détection automatique int/float :
 * Le composant détecte automatiquement s'il doit utiliser des entiers ou des
 * flottants selon les valeurs min/max définies. Si minValue ET maxValue sont
 * des entiers, toutes les valeurs seront arrondies automatiquement.
 * 
 * Propriétés principales:
 * - value: La valeur actuelle (-127 à 127 par défaut)
 * - minValue/maxValue: Plage de valeurs
 * - sensitivity: Sensibilité du mouvement de la souris
 * - dragOrientation: Direction du glissement ("vertical" ou "horizontal")
 * - isInteger: Détection automatique du mode entier (lecture seule)
 * 
 * Propriétés visuelles:
 * - knobColor: Couleur du bouton
 * - indicatorColor: Couleur de l'indicateur de position
 * 
 * Propriétés du texte de valeur:
 * - showValue: Afficher ou non la valeur
 * - valuePosition: Position du texte ("center", "left", "right", "top", "bottom", 
 *                  "topLeft", "topRight", "bottomLeft", "bottomRight", "none")
 * - valueFontSize: Taille de la police
 * - valueColor: Couleur du texte
 * - valueOffset: Distance entre le texte et le bouton
 * - valueRotation: Rotation du texte en degrés
 * - valueFormat: Format d'affichage ("%1" par défaut, ex: "%1°", "%1%")
 * 
 * Interactions:
 * - Glisser verticalement/horizontalement: Modifier la valeur
 * - Double-clic: Réinitialiser à 0
 * - Molette: Incrémenter/décrémenter par pas de 5 (entiers) ou 0.1 (flottants)
 */
Item {
    id: knob
    width: 40
    height: 40
    
    // Propriétés de valeur
    property real value: 0
    property real minValue: -127
    property real maxValue: 127
    property real angle: 0
    property real sensitivity: 1.0
    property string dragOrientation: "vertical"  // "vertical" ou "horizontal"
    
    // Détection automatique : true si minValue ET maxValue sont des entiers
    readonly property bool isInteger: (minValue % 1 === 0) && (maxValue % 1 === 0)
    
    // Propriétés visuelles du knob
    property color knobColor: "#606060"
    property color indicatorColor: "#00ff00"
    
    // Propriétés du texte de valeur
    property bool showValue: true
    property string valuePosition: "center"
    property int valueFontSize: 10
    property color valueColor: "white"
    property int valueOffset: 5
    property real valueRotation: 0
    property string valueFormat: "%1"
    
    // Fonction helper pour formater la valeur selon le mode int/float
    function formatValue(val) {
        let clamped = Math.max(minValue, Math.min(maxValue, val));
        return isInteger ? Math.round(clamped) : clamped;
    }
    
    // Convertir la valeur en angle (12H = 0°, 5H = 150°, 7H = -150°)
    function valueToAngle(val) {
        var normalizedValue = (val - minValue) / (maxValue - minValue);
        return (normalizedValue - 0.5) * 300; // -150° à 150°
    }
    
    // Convertir l'angle en valeur
    function angleToValue(ang) {
        var normalizedAngle = (ang / 300) + 0.5;
        return normalizedAngle * (maxValue - minValue) + minValue;
    }
    
    onValueChanged: {
        angle = valueToAngle(value);
    }
    
    // Méthode explicite pour définir la valeur (évite les problèmes de binding)
    function setValue(newValue) {
        value = formatValue(newValue);
    }
    
    Rectangle {
        id: knobBackground
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        radius: width / 2
        color: knob.knobColor
        border.color: "#303030"
        border.width: 2
        
        // Indicateur de position
        Rectangle {
            id: indicator
            width: 4
            height: parent.height / 2 - 4
            color: knob.indicatorColor
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 4
            transformOrigin: Item.Bottom
            rotation: knob.angle
        }
    }
    
    // Texte de valeur positionnable
    Text {
        id: valueText
        visible: knob.showValue && knob.valuePosition !== "none"
        // Affichage adaptatif selon le mode int/float
        text: knob.valueFormat.arg(knob.isInteger ? Math.round(knob.value) : knob.value.toFixed(2))
        color: knob.valueColor
        font.pixelSize: knob.valueFontSize
        rotation: knob.valueRotation
        
        // Positionnement dynamique
        states: [
            State {
                when: knob.valuePosition === "center"
                AnchorChanges {
                    target: valueText
                    anchors.horizontalCenter: knobBackground.horizontalCenter
                    anchors.verticalCenter: knobBackground.verticalCenter
                }
            },
            State {
                when: knob.valuePosition === "left"
                AnchorChanges {
                    target: valueText
                    anchors.right: knobBackground.left
                    anchors.verticalCenter: knobBackground.verticalCenter
                }
                PropertyChanges {
                    target: valueText
                    anchors.rightMargin: knob.valueOffset
                }
            },
            State {
                when: knob.valuePosition === "right"
                AnchorChanges {
                    target: valueText
                    anchors.left: knobBackground.right
                    anchors.verticalCenter: knobBackground.verticalCenter
                }
                PropertyChanges {
                    target: valueText
                    anchors.leftMargin: knob.valueOffset
                }
            },
            State {
                when: knob.valuePosition === "top"
                AnchorChanges {
                    target: valueText
                    anchors.bottom: knobBackground.top
                    anchors.horizontalCenter: knobBackground.horizontalCenter
                }
                PropertyChanges {
                    target: valueText
                    anchors.bottomMargin: knob.valueOffset
                }
            },
            State {
                when: knob.valuePosition === "bottom"
                AnchorChanges {
                    target: valueText
                    anchors.top: knobBackground.bottom
                    anchors.horizontalCenter: knobBackground.horizontalCenter
                }
                PropertyChanges {
                    target: valueText
                    anchors.topMargin: knob.valueOffset
                }
            },
            State {
                when: knob.valuePosition === "topLeft"
                AnchorChanges {
                    target: valueText
                    anchors.right: knobBackground.left
                    anchors.bottom: knobBackground.top
                }
                PropertyChanges {
                    target: valueText
                    anchors.rightMargin: knob.valueOffset
                    anchors.bottomMargin: knob.valueOffset
                }
            },
            State {
                when: knob.valuePosition === "topRight"
                AnchorChanges {
                    target: valueText
                    anchors.left: knobBackground.right
                    anchors.bottom: knobBackground.top
                }
                PropertyChanges {
                    target: valueText
                    anchors.leftMargin: knob.valueOffset
                    anchors.bottomMargin: knob.valueOffset
                }
            },
            State {
                when: knob.valuePosition === "bottomLeft"
                AnchorChanges {
                    target: valueText
                    anchors.right: knobBackground.left
                    anchors.top: knobBackground.bottom
                }
                PropertyChanges {
                    target: valueText
                    anchors.rightMargin: knob.valueOffset
                    anchors.topMargin: knob.valueOffset
                }
            },
            State {
                when: knob.valuePosition === "bottomRight"
                AnchorChanges {
                    target: valueText
                    anchors.left: knobBackground.right
                    anchors.top: knobBackground.bottom
                }
                PropertyChanges {
                    target: valueText
                    anchors.leftMargin: knob.valueOffset
                    anchors.topMargin: knob.valueOffset
                }
            }
        ]
    }
    
    MouseArea {
        anchors.fill: parent
        property real startX: 0
        property real startY: 0
        property real startValue: 0
        
        onPressed: {
            startX = mouseX
            startY = mouseY
            startValue = knob.value
        }
        
        onPositionChanged: {
            if (pressed) {
                var deltaValue = 0
                
                if (knob.dragOrientation === "vertical") {
                    // Mouvement vertical : vers le haut = augmentation, vers le bas = diminution
                    var deltaY = startY - mouseY  // Inversé pour que haut = positif
                    deltaValue = deltaY * sensitivity
                } else if (knob.dragOrientation === "horizontal") {
                    // Mouvement horizontal : vers la droite = augmentation, vers la gauche = diminution
                    var deltaX = mouseX - startX
                    deltaValue = deltaX * sensitivity
                }
                
                var newValue = startValue + deltaValue
                
                // Utiliser formatValue pour gérer int/float automatiquement
                knob.value = formatValue(newValue)
            }
        }
        
        onDoubleClicked: {
            // Double-clic pour réinitialiser à 0
            knob.value = formatValue(0)
        }
        
        onWheel: {
            // Support de la molette de souris
            var delta = wheel.angleDelta.y / 120  // Normaliser à ±1
            // Incrément adaptatif selon le mode int/float
            var increment = knob.isInteger ? 5 : 0.1
            var newValue = knob.value + delta * increment
            knob.value = formatValue(newValue)
        }
    }
}
