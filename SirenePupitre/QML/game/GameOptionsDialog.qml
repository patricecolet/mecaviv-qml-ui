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
    height: Math.min(parent ? parent.height * 0.7 : 420, 420)
    title: "Options du jeu"

    background: Rectangle {
        color: "#1a1a1a"
        border.color: "#444"
        border.width: 1
    }
    palette.window: "#1a1a1a"
    palette.windowText: "#eee"
    palette.button: "#2a2a2a"
    palette.buttonText: "#eee"
    palette.base: "#1a1a1a"

    property var configController: null
    property string pupitreId: "P1"
    property bool playAccompaniment: false
    property bool autonomyVolant: false
    property bool autonomyVolet: false
    property bool autonomyVibrato: false
    property bool autonomyTremolo: false
    signal accompanimentChanged(bool enabled)
    signal autonomyChanged(string device, bool enabled)
    
    // Navigation encodeur
    // 0 = accompagnement, 1-4 = checkboxes mode autonome
    property int encoderFocusIndex: 0
    property color focusColor: "#00BFFF"
    readonly property int focusCount: 5  // nombre d'items navigables

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
    
    function handleEncoderStep(delta) {
        // Rotation = déplacer le focus entre les items
        var step = (delta > 0) ? 1 : -1
        var newIdx = encoderFocusIndex + step
        if (newIdx < 0) newIdx = focusCount - 1
        if (newIdx >= focusCount) newIdx = 0
        encoderFocusIndex = newIdx
    }
    
    function handleEncoderClick() {
        // Clic = toggler l'item actuellement en focus
        if (encoderFocusIndex === 0) {
            accompanimentCheck.checked = !accompanimentCheck.checked
        } else if (encoderFocusIndex === 1) {
            volantCheckbox.checked = !volantCheckbox.checked
        } else if (encoderFocusIndex === 2) {
            voletCheckbox.checked = !voletCheckbox.checked
        } else if (encoderFocusIndex === 3) {
            vibratoCheckbox.checked = !vibratoCheckbox.checked
        } else if (encoderFocusIndex === 4) {
            tremoloCheckbox.checked = !tremoloCheckbox.checked
        }
    }
    
    onOpened: {
        encoderFocusIndex = 0
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.margins: 16
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        clip: true
        background: Rectangle { color: "#1a1a1a" }
        ColumnLayout {
            id: optionsColumn
            width: scrollView.width - 24
            spacing: 20

        // ——— Lecture ———
        Label {
            text: "Lecture"
            color: "#aaa"
            font.pixelSize: 12
            font.bold: true
            Layout.fillWidth: true
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            CheckBox {
                id: accompanimentCheck
                Layout.fillWidth: true
                checked: gameOptionsDialog.playAccompaniment
                property bool isFocused: gameOptionsDialog.encoderFocusIndex === 0
                onCheckedChanged: {
                    gameOptionsDialog.sendAccompaniment(checked)
                    gameOptionsDialog.accompanimentChanged(checked)
                }
                contentItem: Text {
                    text: "Jouer l'accompagnement"
                    color: accompanimentCheck.isFocused ? gameOptionsDialog.focusColor : "#eee"
                    font.pixelSize: 14
                    font.bold: accompanimentCheck.isFocused
                    leftPadding: accompanimentCheck.indicator.width + accompanimentCheck.spacing
                    verticalAlignment: Text.AlignVCenter
                }
                indicator: Rectangle {
                    implicitWidth: 20
                    implicitHeight: 20
                    x: accompanimentCheck.leftPadding
                    y: parent.height / 2 - height / 2
                    radius: 3
                    border.color: accompanimentCheck.isFocused ? gameOptionsDialog.focusColor : (accompanimentCheck.checked ? "#FFD700" : "#666")
                    border.width: accompanimentCheck.isFocused ? 2 : 1
                    color: "transparent"
                    Rectangle {
                        width: 12; height: 12; x: 4; y: 4; radius: 2
                        color: accompanimentCheck.isFocused ? gameOptionsDialog.focusColor : "#FFD700"
                        visible: accompanimentCheck.checked
                    }
                }
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
                id: volantCheckbox
                Layout.fillWidth: true
                checked: gameOptionsDialog.autonomyVolant
                property bool isFocused: gameOptionsDialog.encoderFocusIndex === 1
                onCheckedChanged: {
                    gameOptionsDialog.sendAutonomy("volant", checked)
                    gameOptionsDialog.autonomyChanged("volant", checked)
                }
                contentItem: Text {
                    text: "Volant – Note (vitesse moteur)"
                    color: volantCheckbox.isFocused ? gameOptionsDialog.focusColor : "#eee"
                    font.pixelSize: 14
                    font.bold: volantCheckbox.isFocused
                    wrapMode: Text.WordWrap
                    leftPadding: volantCheckbox.indicator.width + volantCheckbox.spacing
                    verticalAlignment: Text.AlignVCenter
                }
                indicator: Rectangle {
                    implicitWidth: 20
                    implicitHeight: 20
                    x: volantCheckbox.leftPadding
                    y: parent.height / 2 - height / 2
                    radius: 3
                    border.color: volantCheckbox.isFocused ? gameOptionsDialog.focusColor : (volantCheckbox.checked ? "#FFD700" : "#666")
                    border.width: volantCheckbox.isFocused ? 2 : 1
                    color: "transparent"
                    Rectangle {
                        width: 12; height: 12; x: 4; y: 4; radius: 2
                        color: volantCheckbox.isFocused ? gameOptionsDialog.focusColor : "#FFD700"
                        visible: volantCheckbox.checked
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            CheckBox {
                id: voletCheckbox
                Layout.fillWidth: true
                checked: gameOptionsDialog.autonomyVolet
                property bool isFocused: gameOptionsDialog.encoderFocusIndex === 2
                onCheckedChanged: {
                    gameOptionsDialog.sendAutonomy("volet", checked)
                    gameOptionsDialog.autonomyChanged("volet", checked)
                }
                contentItem: Text {
                    text: "Volet – Vélocité / Aftertouch (ouverture)"
                    color: voletCheckbox.isFocused ? gameOptionsDialog.focusColor : "#eee"
                    font.pixelSize: 14
                    font.bold: voletCheckbox.isFocused
                    wrapMode: Text.WordWrap
                    leftPadding: voletCheckbox.indicator.width + voletCheckbox.spacing
                    verticalAlignment: Text.AlignVCenter
                }
                indicator: Rectangle {
                    implicitWidth: 20
                    implicitHeight: 20
                    x: voletCheckbox.leftPadding
                    y: parent.height / 2 - height / 2
                    radius: 3
                    border.color: voletCheckbox.isFocused ? gameOptionsDialog.focusColor : (voletCheckbox.checked ? "#FFD700" : "#666")
                    border.width: voletCheckbox.isFocused ? 2 : 1
                    color: "transparent"
                    Rectangle {
                        width: 12; height: 12; x: 4; y: 4; radius: 2
                        color: voletCheckbox.isFocused ? gameOptionsDialog.focusColor : "#FFD700"
                        visible: voletCheckbox.checked
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            CheckBox {
                id: vibratoCheckbox
                Layout.fillWidth: true
                checked: gameOptionsDialog.autonomyVibrato
                property bool isFocused: gameOptionsDialog.encoderFocusIndex === 3
                onCheckedChanged: {
                    gameOptionsDialog.sendAutonomy("vibrato", checked)
                    gameOptionsDialog.autonomyChanged("vibrato", checked)
                }
                contentItem: Text {
                    text: "Vibrato – Modulation moteur"
                    color: vibratoCheckbox.isFocused ? gameOptionsDialog.focusColor : "#eee"
                    font.pixelSize: 14
                    font.bold: vibratoCheckbox.isFocused
                    wrapMode: Text.WordWrap
                    leftPadding: vibratoCheckbox.indicator.width + vibratoCheckbox.spacing
                    verticalAlignment: Text.AlignVCenter
                }
                indicator: Rectangle {
                    implicitWidth: 20
                    implicitHeight: 20
                    x: vibratoCheckbox.leftPadding
                    y: parent.height / 2 - height / 2
                    radius: 3
                    border.color: vibratoCheckbox.isFocused ? gameOptionsDialog.focusColor : (vibratoCheckbox.checked ? "#FFD700" : "#666")
                    border.width: vibratoCheckbox.isFocused ? 2 : 1
                    color: "transparent"
                    Rectangle {
                        width: 12; height: 12; x: 4; y: 4; radius: 2
                        color: vibratoCheckbox.isFocused ? gameOptionsDialog.focusColor : "#FFD700"
                        visible: vibratoCheckbox.checked
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            CheckBox {
                id: tremoloCheckbox
                Layout.fillWidth: true
                checked: gameOptionsDialog.autonomyTremolo
                property bool isFocused: gameOptionsDialog.encoderFocusIndex === 4
                onCheckedChanged: {
                    gameOptionsDialog.sendAutonomy("tremolo", checked)
                    gameOptionsDialog.autonomyChanged("tremolo", checked)
                }
                contentItem: Text {
                    text: "Tremolo – Modulation volet"
                    color: tremoloCheckbox.isFocused ? gameOptionsDialog.focusColor : "#eee"
                    font.pixelSize: 14
                    font.bold: tremoloCheckbox.isFocused
                    wrapMode: Text.WordWrap
                    leftPadding: tremoloCheckbox.indicator.width + tremoloCheckbox.spacing
                    verticalAlignment: Text.AlignVCenter
                }
                indicator: Rectangle {
                    implicitWidth: 20
                    implicitHeight: 20
                    x: tremoloCheckbox.leftPadding
                    y: parent.height / 2 - height / 2
                    radius: 3
                    border.color: tremoloCheckbox.isFocused ? gameOptionsDialog.focusColor : (tremoloCheckbox.checked ? "#FFD700" : "#666")
                    border.width: tremoloCheckbox.isFocused ? 2 : 1
                    color: "transparent"
                    Rectangle {
                        width: 12; height: 12; x: 4; y: 4; radius: 2
                        color: tremoloCheckbox.isFocused ? gameOptionsDialog.focusColor : "#FFD700"
                        visible: tremoloCheckbox.checked
                    }
                }
            }
        }
        }
    }

    standardButtons: Dialog.Close
    onAccepted: close()
    onRejected: close()
}
