import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: outputsTab
    
    property var pupitre: null
    
    function patchOutputs(changes) {
        if (!pupitre || !pupitre.id) return
        var xhr = new XMLHttpRequest()
        xhr.open("PATCH", "http://localhost:8001/api/presets/current/outputs")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify({ pupitreId: pupitre.id, changes: changes }))
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15
        
        CheckBox {
            text: "VST Enabled"
            checked: pupitre ? pupitre.vstEnabled : false
            onCheckedChanged: if (pupitre) { pupitre.vstEnabled = checked; patchOutputs({ vstEnabled: checked }) }
        }
        CheckBox {
            text: "UDP Enabled"
            checked: pupitre ? pupitre.udpEnabled : false
            onCheckedChanged: if (pupitre) { pupitre.udpEnabled = checked; patchOutputs({ udpEnabled: checked }) }
        }
        CheckBox {
            text: "RTP MIDI Enabled"
            checked: pupitre ? pupitre.rtpMidiEnabled : false
            onCheckedChanged: if (pupitre) { pupitre.rtpMidiEnabled = checked; patchOutputs({ rtpMidiEnabled: checked }) }
        }
        
        Item { Layout.fillHeight: true }
    }
}
