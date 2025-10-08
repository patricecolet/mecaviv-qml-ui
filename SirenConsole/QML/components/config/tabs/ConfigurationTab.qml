import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: configurationTab
    
    property var pupitre: null
    
    ColumnLayout {
        anchors.margins: 10
        anchors.fill: parent
        spacing: 15
        
        // Sirène active
        RowLayout {
            Text {
                text: "Sirène active:"
                color: "#cccccc"
                Layout.preferredWidth: 100
            }
            ComboBox {
                model: ["Sirene 1", "Sirene 2", "Sirene 3", "Sirene 4", "Sirene 5", "Sirene 6", "Sirene 7"]
                currentIndex: (pupitre && pupitre.currentSiren !== undefined) ? pupitre.currentSiren - 1 : 0
                Layout.fillWidth: true
                onCurrentIndexChanged: {
                    if (pupitre) {
                        pupitre.currentSiren = currentIndex + 1
                    }
                }
            }
        }
        
        // Mode fretté
        RowLayout {
            Text {
                text: "Mode fretté:"
                color: "#cccccc"
                Layout.preferredWidth: 100
            }
            Switch {
                checked: (pupitre && pupitre.frettedMode !== undefined) ? pupitre.frettedMode : false
                onCheckedChanged: {
                    if (pupitre) {
                        pupitre.frettedMode = checked
                    }
                }
            }
        }
        
        // Configuration Ambitus
        GroupBox {
            title: "Ambitus"
            Layout.fillWidth: true
            
            GridLayout {
                columns: 4
                columnSpacing: 10
                rowSpacing: 8
                
                Text { text: "Note Min:"; color: "#cccccc" }
                SpinBox {
                    from: 0; to: 127
                    value: (pupitre && pupitre.ambitus) ? pupitre.ambitus.min : 48
                    onValueChanged: {
                        if (pupitre && pupitre.ambitus) {
                            pupitre.ambitus = { min: value, max: pupitre.ambitus.max }
                        }
                    }
                }
                Text { text: "Note Max:"; color: "#cccccc" }
                SpinBox {
                    from: 0; to: 127
                    value: (pupitre && pupitre.ambitus) ? pupitre.ambitus.max : 72
                    onValueChanged: {
                        if (pupitre && pupitre.ambitus) {
                            pupitre.ambitus = { min: pupitre.ambitus.min, max: value }
                        }
                    }
                }
                
                Text { text: "Max Restreint:"; color: "#cccccc" }
                SpinBox {
                    from: 0; to: 127
                    value: (pupitre && pupitre.restrictedMax !== undefined) ? pupitre.restrictedMax : 72
                    onValueChanged: {
                        if (pupitre) {
                            pupitre.restrictedMax = value
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                Item { Layout.fillWidth: true }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}
