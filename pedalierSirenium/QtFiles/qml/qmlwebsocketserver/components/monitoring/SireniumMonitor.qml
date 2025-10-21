// ... existing imports ...
import QtQuick
import QtQuick3D
import QtQuick.Controls
import "../../../utils" as Utils
import "../../../../../../shared/qml/common" as SharedUtils

Item {
    id: sireniumMonitor
    width: 260
    height: 170

    // Propriétés publiques à lier depuis le contrôleur principal
    property int note: 0
    property int velocity: 0
    property string noteName: ""

    // Couleurs personnalisées
    property color noteColor: "#00ff00"      // Vert vif
    property color velocityColor: "#87ceeb"  // Bleu clair

    // Utilitaires musique pour nom de note
    Utils.MusicUtils { id: musicUtils }
    Component.onCompleted: { noteName = musicUtils.midiToNoteName(note) }
    onNoteChanged: { noteName = musicUtils.midiToNoteName(note) }

    Rectangle {
        id: bgRect
        width: 220
        height: 150
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.topMargin: 12
        radius: 12
        color: Qt.rgba(0.08,0.08,0.08,0.92)
        border.color: "#333"
        border.width: 1

        // Titre
        Text {
            text: "Sirénium"
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.topMargin: 10
            color: "#fff"
            font.pixelSize: 16
            font.bold: true
        }

        // Contenu principal
        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.topMargin: 40
            spacing: 20

            // Note
            Column {
                spacing: 8
                Text {
                    text: "NOTE"
                    color: noteColor
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Row {
                    spacing: 20 // Augmenté pour plus d'espace entre les digits
                    View3D {
                        width: 56; height: 44
                        camera: PerspectiveCamera { position: Qt.vector3d(0, 0, 100) }
                        DirectionalLight { eulerRotation.x: -30 }

                        // Dizaines
                        Node {
                            id: noteTensNode
                            position: Qt.vector3d(-18, 0, 0) // Plus espacé
                            property var digitObj: null

                            function createOrUpdateDigit() {
                                if (!digitObj) {
                                    let digitComponent = Qt.createComponent("qrc:/qml/utils/DigitLED3D.qml");
                                    if (digitComponent.status === Component.Ready) {
                                        digitObj = digitComponent.createObject(noteTensNode, {});
                                    }
                                }
                                if (digitObj) {
                                    digitObj.value = Math.floor(sireniumMonitor.note/10);
                                    digitObj.activeColor = sireniumMonitor.noteColor; // même couleur que le titre
                                }
                            }

                            Component.onCompleted: createOrUpdateDigit()
                            Connections {
                                target: sireniumMonitor
                                function onNoteChanged() { noteTensNode.createOrUpdateDigit() }
                                function onNoteColorChanged() { noteTensNode.createOrUpdateDigit() }
                            }
                        }

                        // Unités
                        Node {
                            id: noteUnitsNode
                            position: Qt.vector3d(18, 0, 0) // Plus espacé
                            property var digitObj: null

                            function createOrUpdateDigit() {
                                if (!digitObj) {
                                    let digitComponent = Qt.createComponent("qrc:/qml/utils/DigitLED3D.qml");
                                    if (digitComponent.status === Component.Ready) {
                                        digitObj = digitComponent.createObject(noteUnitsNode, {});
                                    }
                                }
                                if (digitObj) {
                                    digitObj.value = sireniumMonitor.note%10;
                                    digitObj.activeColor = sireniumMonitor.noteColor; // même couleur que le titre
                                }
                            }

                            Component.onCompleted: createOrUpdateDigit()
                            Connections {
                                target: sireniumMonitor
                                function onNoteChanged() { noteUnitsNode.createOrUpdateDigit() }
                                function onNoteColorChanged() { noteUnitsNode.createOrUpdateDigit() }
                            }
                        }
                    }
                }
            }

            // Nom de note (au centre) avec largeur fixe pour ne pas déplacer la colonne VEL
            Column {
                id: nameCol
                spacing: 6
                width: 70  // largeur fixe pour 4 caractères max
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: "NOM"
                    color: "#cccccc"
                    font.pixelSize: 12
                    font.bold: true
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: sireniumMonitor.noteName
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.bold: true
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }

            // Velocity
            Column {
                spacing: 8
                Text {
                    text: "VEL"
                    color: velocityColor
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Row {
                    spacing: 20 // Beaucoup plus d'espace entre les digits de vélocité
                    View3D {
                        width: 90; height: 44
                        camera: PerspectiveCamera { position: Qt.vector3d(0, 0, 100) }
                        DirectionalLight { eulerRotation.x: -30 }

                        // Centaines
                        Node {
                            id: velHundredsNode
                            position: Qt.vector3d(-32, 0, 0) // Plus espacé
                            property var digitObj: null

                            function createOrUpdateDigit() {
                                if (!digitObj) {
                                    let digitComponent = Qt.createComponent("qrc:/qml/utils/DigitLED3D.qml");
                                    if (digitComponent.status === Component.Ready) {
                                        digitObj = digitComponent.createObject(velHundredsNode, {});
                                    }
                                }
                                if (digitObj) {
                                    digitObj.value = Math.floor(sireniumMonitor.velocity/100);
                                    digitObj.activeColor = sireniumMonitor.velocityColor; // même couleur que le titre
                                }
                            }

                            Component.onCompleted: createOrUpdateDigit()
                            Connections {
                                target: sireniumMonitor
                                function onVelocityChanged() { velHundredsNode.createOrUpdateDigit() }
                                function onVelocityColorChanged() { velHundredsNode.createOrUpdateDigit() }
                            }
                        }

                        // Dizaines
                        Node {
                            id: velTensNode
                            position: Qt.vector3d(0, 0, 0)
                            property var digitObj: null

                            function createOrUpdateDigit() {
                                if (!digitObj) {
                                    let digitComponent = Qt.createComponent("qrc:/qml/utils/DigitLED3D.qml");
                                    if (digitComponent.status === Component.Ready) {
                                        digitObj = digitComponent.createObject(velTensNode, {});
                                    }
                                }
                                if (digitObj) {
                                    digitObj.value = Math.floor((sireniumMonitor.velocity%100)/10);
                                    digitObj.activeColor = sireniumMonitor.velocityColor; // même couleur que le titre
                                }
                            }

                            Component.onCompleted: createOrUpdateDigit()
                            Connections {
                                target: sireniumMonitor
                                function onVelocityChanged() { velTensNode.createOrUpdateDigit() }
                                function onVelocityColorChanged() { velTensNode.createOrUpdateDigit() }
                            }
                        }

                        // Unités
                        Node {
                            id: velUnitsNode
                            position: Qt.vector3d(32, 0, 0) // Plus espacé
                            property var digitObj: null

                            function createOrUpdateDigit() {
                                if (!digitObj) {
                                    let digitComponent = Qt.createComponent("qrc:/qml/utils/DigitLED3D.qml");
                                    if (digitComponent.status === Component.Ready) {
                                        digitObj = digitComponent.createObject(velUnitsNode, {});
                                    }
                                }
                                if (digitObj) {
                                    digitObj.value = sireniumMonitor.velocity%10;
                                    digitObj.activeColor = sireniumMonitor.velocityColor; // même couleur que le titre
                                }
                            }

                            Component.onCompleted: createOrUpdateDigit()
                            Connections {
                                target: sireniumMonitor
                                function onVelocityChanged() { velUnitsNode.createOrUpdateDigit() }
                                function onVelocityColorChanged() { velUnitsNode.createOrUpdateDigit() }
                            }
                        }
                    }
                }
            }
        }
    }
}