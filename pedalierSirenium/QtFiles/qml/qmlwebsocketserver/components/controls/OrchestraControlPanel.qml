pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

// Contrôle de l'orchestre virtuel côté PD (composeSiren~, mode DSP du
// sélecteur V1/V2/DSP existant dans pedalier.pd) -- une commande par
// message WebSocket, déjà au format composeSiren~ ("<id> champ valeur").
Rectangle {
    id: root
    property var webSocketController
    property bool dspEnabled: false

    property var voiceLabels: ["S1", "S2", "S3", "S4", "S5", "S6", "S7"]
    property var volumes: [55, 55, 55, 55, 55, 55, 55]
    property var pans: [10, 28, 46, 64, 82, 100, 118]

    color: "#2a2a2a"
    radius: 8
    border.color: "#444"
    implicitHeight: content.implicitHeight + 30

    function sendDsp(enabled) {
        dspEnabled = enabled;
        if (!webSocketController) return;
        for (let i = 0; i < voiceLabels.length; i++) {
            webSocketController.sendOrchestraDsp(i + 1, enabled);
        }
    }

    function sendVolume(index) {
        if (webSocketController) webSocketController.sendOrchestraVolume(index + 1, volumes[index]);
    }

    function sendPan(index) {
        if (webSocketController) webSocketController.sendOrchestraPan(index + 1, pans[index]);
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 15
        spacing: 10

        Row {
            spacing: 10
            Text {
                text: "Orchestre virtuel"
                color: "#00aaff"
                font.pixelSize: 14
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            CheckBox {
                text: "DSP (monitoring)"
                checked: root.dspEnabled
                onToggled: root.sendDsp(checked)
            }
        }

        Repeater {
            model: root.voiceLabels.length
            delegate: Row {
                id: voiceRow
                required property int index
                readonly property int voiceIndex: index
                spacing: 12

                Text {
                    text: root.voiceLabels[voiceRow.voiceIndex]
                    color: "#ccc"
                    width: 24
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "vol"
                    color: "#888"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    from: 0
                    to: 100
                    value: root.volumes[voiceRow.voiceIndex]
                    width: 120
                    onMoved: {
                        root.volumes[voiceRow.voiceIndex] = Math.round(value);
                        root.sendVolume(voiceRow.voiceIndex);
                    }
                }
                Text {
                    text: "pan"
                    color: "#888"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    from: 0
                    to: 127
                    value: root.pans[voiceRow.voiceIndex]
                    width: 120
                    onMoved: {
                        root.pans[voiceRow.voiceIndex] = Math.round(value);
                        root.sendPan(voiceRow.voiceIndex);
                    }
                }
            }
        }
    }
}
