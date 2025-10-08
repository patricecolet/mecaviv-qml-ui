import QtQuick
import "../../../utils" as Utils
import "../../config.js" as Config

pragma ComponentBehavior: Bound

Item {
    id: root
    
    property string label: ""
    property color labelColor: "white"
    property color knobColor: "#404040"
    property color indicatorColor: "white"
    property int knobCount: 2
    property var values: []
    property int startIndex: 0
    property var knobLabels: []
    property bool showKnobLabels: false
    
    signal valueChanged(int index, real value)
    
    width: 180
    height: knobCount * 56 + (knobCount - 1) * 12
    
    // Méthode pour mettre à jour tous les knobs de cette section
    function setValues(sectionValues) {
        for (let i = 0; i < knobCount && i < sectionValues.length; i++) {
            let rowItem = knobRepeater.itemAt(i);
            if (rowItem && rowItem.children) {
                // Parcourir les enfants du Row pour trouver le Knob
                for (let j = 0; j < rowItem.children.length; j++) {
                    let child = rowItem.children[j];
                    if (child && typeof child.setValue === "function") {
                        child.setValue(sectionValues[i]);
                        break; // Knob trouvé, passer au suivant
                    }
                }
            }
        }
    }

    Row {
        spacing: 10
        anchors.fill: parent

        // Label de section
        Text {
            visible: root.label !== ""
            text: root.label
            color: root.labelColor
            font.pixelSize: 14
            font.bold: true
            font.family: "Arial"
            width: 70
            horizontalAlignment: Text.AlignRight
            renderType: Text.NativeRendering
        }

        // Knobs avec métadonnées
        Column {
            spacing: 12

            Repeater {
                id: knobRepeater
                model: root.knobCount

                Row {
                    required property int index
                    spacing: 5
                    // Label du knob
                    Text {
                        visible: root.showKnobLabels
                        text: visible && root.knobLabels.length > index
                            ? Config.controllers.definitions[root.knobLabels[index]].label
                            : ""
                        color: "#fff700"
                        font.pixelSize: 12
                        font.family: "Arial"
                        width: visible ? 40 : 0
                        horizontalAlignment: Text.AlignRight
                        renderType: Text.NativeRendering
                    }

                    // Le knob
                    Utils.Knob {
                        id: knobItem
                        objectName: "knob_" + index
                        property string controllerName: root.knobLabels.length > index ? root.knobLabels[index] : ""
                        property var pedalRange: controllerName && Config.controllers.definitions[controllerName]
                            ? { "min": Config.controllers.definitions[controllerName].min, "max": Config.controllers.definitions[controllerName].max }
                            : { "min": -100, "max": 100 }

                        width: 48
                        height: 48
                        minValue: pedalRange.min
                        maxValue: pedalRange.max
                        value: 0  // Sera mis à jour via setValue()
                        knobColor: root.knobColor
                        indicatorColor: root.indicatorColor

                        // Sensibilité depuis la config
                        sensitivity: {
                            let range = pedalRange.max - pedalRange.min;
                            if (range <= 24) return Config.ui.knobSensitivity.small;
                            else if (range <= 100) return Config.ui.knobSensitivity.medium;
                            else return Config.ui.knobSensitivity.large;
                        }

                        // Configuration affichage valeur
                        showValue: true
                        valuePosition: "right"
                        valueColor: "#ffd500"
                        valueFontSize: 14
                        valueOffset: 8

                        onValueChanged: {
                            root.valueChanged(root.startIndex + index, value)
                        }
                    }
                }
            }
        }
    }
}
