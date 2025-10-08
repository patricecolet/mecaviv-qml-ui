import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: outputsTab
    
    property var pupitre: null
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15
        
        CheckBox {
            text: "VST Enabled"
            checked: pupitre ? pupitre.vstEnabled : false
            onCheckedChanged: if (pupitre) pupitre.vstEnabled = checked
        }
        CheckBox {
            text: "UDP Enabled"
            checked: pupitre ? pupitre.udpEnabled : false
            onCheckedChanged: if (pupitre) pupitre.udpEnabled = checked
        }
        CheckBox {
            text: "RTP MIDI Enabled"
            checked: pupitre ? pupitre.rtpMidiEnabled : false
            onCheckedChanged: if (pupitre) pupitre.rtpMidiEnabled = checked
        }
        
        Item { Layout.fillHeight: true }
    }
}
