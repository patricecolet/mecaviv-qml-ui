import QtQuick
import QtQuick3D

Item {
    id: root
    
    // Propriétés
    property int tempo: 120
    property int minTempo: 40
    property int maxTempo: 440
    property int stepSize: 1
    property int largeStepSize: 5
    
    // Propriétés pour les digits LED
    property var hundredsDigit: null
    property var tensDigit: null
    property var unitsDigit: null
    
    width: 190
    height: 60
    
    Component.onCompleted: {
        createDigits();
        updateDigits();
    }
    
    Rectangle {
        id: background
        anchors.fill: parent
        color: "#333333"
        radius: 10
        border.color: "#555555"
        border.width: 2
    }
    
    Rectangle {
        id: decrementButton
        width: 40
        height: 40
        anchors.left: parent.left
        anchors.leftMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        color: decrementMouse.pressed ? "#555555" : "#444444"
        radius: 5
        Text {
            anchors.centerIn: parent
            text: "◀"
            color: "white"
            font.pixelSize: 20
        }
        MouseArea {
            id: decrementMouse
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: false
            enabled: true
            onClicked: decrementTempo(stepSize)
            property bool longPressActive: false
            Timer {
                id: decrementTimer
                interval: 100
                repeat: true
                onTriggered: {
                    if (decrementMouse.longPressActive) {
                        decrementTempo(largeStepSize);
                    }
                }
            }
            onPressed: {
                longPressActive = false;
                decrementLongPressTimer.start();
            }
            onReleased: {
                decrementLongPressTimer.stop();
                decrementTimer.stop();
                longPressActive = false;
            }
            Timer {
                id: decrementLongPressTimer
                interval: 500
                onTriggered: {
                    decrementMouse.longPressActive = true;
                    decrementTimer.start();
                }
            }
        }
    }
    
    // Affichage du tempo au centre avec digits 3D
    Item {
        id: centerContainer
        anchors.centerIn: parent
        width: ledView.width + bpmText.width + 2
        height: parent.height
        
        View3D {
            id: ledView
            width: 110
            height: parent.height
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            PerspectiveCamera {
                id: camera
                position: Qt.vector3d(0, 0, 100)
            }
            DirectionalLight {
                eulerRotation.x: -30
            }
            Node {
                id: digitsContainer
                scale: Qt.vector3d(1.2, 1.0, 1.0)
            }
        }
        Text {
            id: bpmText
            anchors.left: ledView.right
            anchors.leftMargin: -25
            anchors.verticalCenter: parent.verticalCenter
            text: "BPM"
            color: "lime"
            font.pixelSize: 16
            font.bold: true
        }
    }
    
    Rectangle {
        id: incrementButton
        width: 40
        height: 40
        anchors.right: parent.right
        anchors.rightMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        color: incrementMouse.pressed ? "#555555" : "#444444"
        radius: 5
        Text {
            anchors.centerIn: parent
            text: "▶"
            font.family: window.globalEmojiFont
            color: "white"
            font.pixelSize: 20
        }
        MouseArea {
            id: incrementMouse
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: false
            enabled: true
            onClicked: incrementTempo(stepSize)
            property bool longPressActive: false
            Timer {
                id: incrementTimer
                interval: 100
                repeat: true
                onTriggered: {
                    if (incrementMouse.longPressActive) {
                        incrementTempo(largeStepSize);
                    }
                }
            }
            onPressed: {
                longPressActive = false;
                incrementLongPressTimer.start();
            }
            onReleased: {
                incrementLongPressTimer.stop();
                incrementTimer.stop();
                longPressActive = false;
            }
            Timer {
                id: incrementLongPressTimer
                interval: 500
                onTriggered: {
                    incrementMouse.longPressActive = true;
                    incrementTimer.start();
                }
            }
        }
    }
    
    function incrementTempo(step) {
        let newTempo = Math.min(tempo + step, maxTempo);
        if (newTempo !== tempo) {
            tempo = newTempo;
        }
    }
    function decrementTempo(step) {
        let newTempo = Math.max(tempo - step, minTempo);
        if (newTempo !== tempo) {
            tempo = newTempo;
        }
    }
    function createDigits() {
                    let digitComponent = Qt.createComponent("qrc:/qml/utils/DigitLED3D.qml");
        if (digitComponent.status === Component.Ready) {
            hundredsDigit = digitComponent.createObject(digitsContainer, {
                "position": Qt.vector3d(-30, 0, 0),
                "activeColor": "lime",
                "inactiveColor": "#003300",
                "segmentWidth": 5,
                "horizontalLength": 15,
                "verticalLength": 20
            });
            tensDigit = digitComponent.createObject(digitsContainer, {
                "position": Qt.vector3d(0, 0, 0),
                "activeColor": "lime",
                "inactiveColor": "#003300",
                "segmentWidth": 5,
                "horizontalLength": 15,
                "verticalLength": 20
            });
            unitsDigit = digitComponent.createObject(digitsContainer, {
                "position": Qt.vector3d(30, 0, 0),
                "activeColor": "lime",
                "inactiveColor": "#003300",
                "segmentWidth": 5,
                "horizontalLength": 15,
                "verticalLength": 20
            });
        } else if (digitComponent.status === Component.Error) {
            if (logger) logger.error("INIT", "Erreur lors du chargement du composant DigitLED3D:", digitComponent.errorString());
        }
    }
    function updateDigits() {
        if (hundredsDigit && tensDigit && unitsDigit) {
            let hundreds = Math.floor(tempo / 100);
            let tens = Math.floor((tempo % 100) / 10);
            let units = tempo % 10;
            hundredsDigit.value = hundreds;
            tensDigit.value = tens;
            unitsDigit.value = units;
            hundredsDigit.visible = tempo >= 100;
        }
    }
    onTempoChanged: {
        updateDigits();
    }
}
