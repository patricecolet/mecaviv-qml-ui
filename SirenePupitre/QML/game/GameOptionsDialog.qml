import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

pragma ComponentBehavior: Bound

/**
 * Dialog « Options du jeu » : accompagnement + 4 parties en mode autonome.
 * Même style que SongSelectorDialog. Envoie ACCOMPANIMENT_ENABLED et
 * AUTONOMY_MODE via webSocketController à chaque changement.
 */
Dialog {
    id: gameOptionsDialog
    modal: true
    focus: true
    width: Math.min(parent ? parent.width * 0.5 : 480, 480)
    title: "Options du jeu"

    property var configController: null
    property string pupitreId: "P1"
    property bool playAccompaniment: true
    signal accompanimentChanged(bool enabled)

    // Envoyer AUTONOMY_MODE au serveur
    function sendAutonomy(device, enabled) {
        if (configController && configController.webSocketController) {
            configController.webSocketController.sendBinaryMessage({
                type: "AUTONOMY_MODE",
                pupitreId: gameOptionsDialog.pupitreId,
                device: device,
                enabled: enabled,
                source: "pupitre"
            })
        }
    }

    // Envoyer ACCOMPANIMENT_ENABLED au serveur
    function sendAccompaniment(enabled) {
        if (configController && configController.webSocketController) {
            configController.webSocketController.sendBinaryMessage({
                type: "ACCOMPANIMENT_ENABLED",
                enabled: enabled,
                source: "pupitre"
            })
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 20

        // ——— Lecture ———
        Label {
            text: "Lecture"
            color: "#aaa"
            font.pixelSize: 12
            font.bold: true
            Layout.fillWidth: true
        }
        Row {
            spacing: 10
            Layout.fillWidth: true
            CheckBox {
                id: accompanimentCheck
                checked: gameOptionsDialog.playAccompaniment
                onCheckedChanged: {
                    gameOptionsDialog.sendAccompaniment(checked)
                    gameOptionsDialog.accompanimentChanged(checked)
                }
            }
            Text {
                text: "Jouer l'accompagnement"
                color: "#eee"
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ——— Mode autonome (device = nom envoyé en WebSocket) ———
        Label {
            text: "Mode autonome"
            color: "#aaa"
            font.pixelSize: 12
            font.bold: true
            Layout.fillWidth: true
            Layout.topMargin: 8
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            CheckBox {
                checked: false
                onCheckedChanged: gameOptionsDialog.sendAutonomy("volant", checked)
            }
            Text {
                text: "Volant – Note (vitesse moteur)"
                color: "#eee"
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            CheckBox {
                checked: false
                onCheckedChanged: gameOptionsDialog.sendAutonomy("volet", checked)
            }
            Text {
                text: "Volet – Vélocité / Aftertouch (ouverture)"
                color: "#eee"
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            CheckBox {
                checked: false
                onCheckedChanged: gameOptionsDialog.sendAutonomy("vibrato", checked)
            }
            Text {
                text: "Vibrato – Modulation moteur"
                color: "#eee"
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            CheckBox {
                checked: false
                onCheckedChanged: gameOptionsDialog.sendAutonomy("tremolo", checked)
            }
            Text {
                text: "Tremolo – Modulation volet"
                color: "#eee"
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }

    standardButtons: Dialog.Close
    onAccepted: close()
    onRejected: close()
}
