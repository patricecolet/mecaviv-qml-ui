import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property bool midiEnabled: false
    property string midiSource: ""
    property bool midiLearn: false
    
    signal midiEnabledChanged(bool enabled)
    signal midiSourceChanged(string source)
    signal midiLearnToggled(bool enabled)
    
    color: "#2a2a2a"
    border.color: "#666666"
    border.width: 1
    radius: 5
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        Text {
            Layout.fillWidth: true
            text: "Contrôleur MIDI"
            color: "#FFFFFF"
            font.pixelSize: 14
            font.bold: true
        }
        
        CheckBox {
            text: "Activer MIDI"
            checked: root.midiEnabled
            onCheckedChanged: {
                root.midiEnabled = checked
                root.midiEnabledChanged(checked)
            }
        }
        
        ComboBox {
            Layout.fillWidth: true
            enabled: root.midiEnabled
            model: ["Aucune source", "Source 1", "Source 2", "Source 3"]
            currentIndex: root.midiSource ? 1 : 0
            onCurrentTextChanged: {
                root.midiSource = currentText
                root.midiSourceChanged(currentText)
            }
        }
        
        Button {
            Layout.fillWidth: true
            text: root.midiLearn ? "Arrêter l'apprentissage" : "Apprentissage MIDI"
            enabled: root.midiEnabled
            onClicked: {
                root.midiLearn = !root.midiLearn
                root.midiLearnToggled(root.midiLearn)
            }
        }
        
        Text {
            Layout.fillWidth: true
            text: root.midiLearn ? "En attente d'entrée MIDI..." : ""
            color: "#4a90e2"
            font.pixelSize: 11
            visible: root.midiLearn
        }
    }
}
