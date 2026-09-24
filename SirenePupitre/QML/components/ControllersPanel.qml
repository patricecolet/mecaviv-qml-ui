import QtQuick
import QtQuick.Layouts

// Panneau des contrôleurs, en 2D : une carte par contrôleur, dans une grille qui
// s'adapte à la largeur. Remplace la vue 3D (indicateurs QtQuick3D), dont la
// caméra à champ fixe faisait déborder les indicateurs dès que le panneau
// changeait de proportions. L'interface publique (propriétés, fonctions appelées
// par Test2D et le WebSocket) est inchangée.
Rectangle {
    id: root

    // Données des contrôleurs (message 0x02, voir WebSocketController)
    property real wheelPosition: 0          // 0-360 degrés
    property real wheelSpeed: 0
    property real joystickX: 0              // -1..1
    property real joystickY: 0
    property real joystickZ: 0
    property bool joystickButton: false
    property int gearShiftPosition: 0       // 0-4
    property string gearShiftMode: "0"      // demi-tons : 0, 1, 12, 24, 48
    property int faderValue: 0
    property int modPedalValue: 0
    property real modPedalPercent: 0
    property int pad1Velocity: 0
    property int pad1Aftertouch: 0
    property bool pad1Active: false
    property int pad2Velocity: 0
    property int pad2Aftertouch: 0
    property bool pad2Active: false
    property bool button1: false
    property bool button2: false
    property int encoderValue: 0
    property bool encoderPressed: false

    // Apparence
    property color backgroundColor: "#0a0a0a"
    property color borderColor: "#2a2a2a"
    property color accent: "#00ff00"
    property color cardColor: "#141414"
    property color dimText: "#7a7a7a"
    property color valueText: "#ccffcc"
    property int headerHeight: 5
    property var configController: null
    property var webSocketController: null

    // Tests
    property bool faderTestActive: false
    property bool leftSpeakerTestOn: false
    property bool rightSpeakerTestOn: false

    // Calibrage pads (protocole actuel, vers PureData)
    property string padCalibrationMode: "min"  // "min" | "max"
    property bool pad1CalibrationActive: false
    property bool pad2CalibrationActive: false
    property int pad1CalibMinV: 0
    property int pad1CalibMaxV: 127
    property int pad1CalibMinA: 0
    property int pad1CalibMaxA: 127
    property int pad2CalibMinV: 0
    property int pad2CalibMaxV: 127
    property int pad2CalibMinA: 0
    property int pad2CalibMaxA: 127
    /** Valeurs brutes des deux pads [pad0, pad1] (PAD_CALIBRATION_VALUE). */
    property var padCalibDisplayValues: [0, 0]

    // Calibrage joystick : min, 0.min, 0.max, max
    property string joystickCalibrationMode: "min"  // "min" | "zero_min" | "zero_max" | "max"
    property real joystickRawX: 0
    property real joystickRawY: 0
    property var joyCalibStateX: []
    property var joyCalibStateY: []
    property real joystickFilteredX: 0
    property real joystickFilteredY: 0
    property bool joystickFilteredReceived: false

    color: backgroundColor
    border.color: borderColor
    border.width: 1
    radius: 5

    onConfigControllerChanged: {
        if (root.configController)
            Qt.callLater(function () { root.refreshJoystickCalibrationStateFromConfig() })
    }

    // ------------------------------------------------------------------
    // Fonctions publiques (inchangées)
    // ------------------------------------------------------------------

    function setPadCalibrationValues(values) {
        if (values && Array.isArray(values) && values.length >= 2)
            root.padCalibDisplayValues = [values[0], values[1]]
    }

    function sendJoystickCalibration(axis) {
        if (!webSocketController || !webSocketController.connected)
            return
        webSocketController.sendBinaryMessage({
            type: "JOYSTICK_CALIBRATION",
            axis: axis,
            mode: root.joystickCalibrationMode,
            source: "pupitre"
        })
    }

    function _axisToFour(raw) {
        if (raw === undefined || raw === null)
            return null
        var a, b, c, d
        if (Array.isArray(raw)) {
            if (raw.length < 4)
                return null
            a = Number(raw[0]); b = Number(raw[1]); c = Number(raw[2]); d = Number(raw[3])
        } else if (typeof raw === "object") {
            a = Number(raw.min)
            b = Number(raw.zeroMin !== undefined ? raw.zeroMin : raw.zero_min)
            c = Number(raw.zeroMax !== undefined ? raw.zeroMax : raw.zero_max)
            d = Number(raw.max)
        } else {
            return null
        }
        if (!isFinite(a) || !isFinite(b) || !isFinite(c) || !isFinite(d))
            return null
        return [a, b, c, d]
    }

    function setJoystickCalibrationState(data) {
        if (!data)
            return
        var xa = root._axisToFour(data.x)
        var ya = root._axisToFour(data.y)
        if (xa)
            root.joyCalibStateX = xa
        if (ya)
            root.joyCalibStateY = ya
    }

    function refreshJoystickCalibrationStateFromConfig() {
        if (!configController)
            return
        var j = configController.getValueAtPath(["calibration", "joystick"], null)
        if (!j || typeof j !== "object")
            return
        var payload = {}
        if (j.x !== undefined)
            payload.x = j.x
        if (j.y !== undefined)
            payload.y = j.y
        if (payload.x !== undefined || payload.y !== undefined)
            root.setJoystickCalibrationState(payload)
    }

    function joyCalibSlot(axis, index) {
        var arr = axis === "x" ? root.joyCalibStateX : root.joyCalibStateY
        if (!arr || !Array.isArray(arr) || arr.length <= index)
            return "—"
        var v = Number(arr[index])
        return isFinite(v) ? String(Math.round(v)) : "—"
    }

    function setJoystickFilteredValues(fx, fy) {
        var x = Number(fx)
        var y = Number(fy)
        if (!isFinite(x) || !isFinite(y))
            return
        root.joystickFilteredX = x
        root.joystickFilteredY = y
        root.joystickFilteredReceived = true
    }

    function showControllerValues() {
        return configController ? configController.isComponentVisible("controllerValues") : true
    }

    function isShown(key) {
        if (!configController)
            return true
        configController.updateCounter
        return configController.isSubComponentVisible("controllers", key)
    }

    function testFader(active) {
        if (!webSocketController || !webSocketController.connected)
            return
        webSocketController.sendBinaryMessage({ type: "FADER_TEST", value: active ? 1 : 0 })
    }

    function testSpeaker(channel, active) {
        if (!webSocketController || !webSocketController.connected)
            return
        webSocketController.sendBinaryMessage({ type: "SPEAKER_TEST", channel: channel, active: active })
    }

    function sendPadCalibration(pad) {
        if (!webSocketController || !webSocketController.connected)
            return
        webSocketController.sendBinaryMessage({ type: "PAD_CALIBRATION", pad: pad, mode: root.padCalibrationMode })
    }

    function updateControllers(controllersData) {
        if (controllersData.wheel) {
            wheelPosition = controllersData.wheel.position || 0
            wheelSpeed = controllersData.wheel.velocity || 0
        }
        if (controllersData.joystick) {
            var j = controllersData.joystick
            function joyNum(v) {
                var n = typeof v === "number" ? v : parseFloat(v)
                return isFinite(n) ? n : 0
            }
            joystickRawX = joyNum(j.x)
            joystickRawY = joyNum(j.y)
            joystickX = joystickRawX / 127.0
            joystickY = joystickRawY / 127.0
            joystickZ = joyNum(j.z) / 127.0
            joystickButton = j.button || false
        }
        if (controllersData.gearShift) {
            gearShiftPosition = controllersData.gearShift.position || 0
            gearShiftMode = controllersData.gearShift.mode || "0"
        }
        if (controllersData.fader)
            faderValue = controllersData.fader.value || 0
        if (controllersData.modPedal) {
            modPedalValue = controllersData.modPedal.value || 0
            modPedalPercent = controllersData.modPedal.percent || 0
        }
        var p1 = controllersData.pad1 || (controllersData.pad && !controllersData.pad1 ? controllersData.pad : null)
        if (p1) {
            pad1Velocity = p1.velocity || 0
            pad1Aftertouch = p1.aftertouch || 0
            pad1Active = p1.active || false
            if (root.pad1CalibrationActive) {
                if (root.padCalibrationMode === "min") {
                    root.pad1CalibMinV = Math.min(root.pad1CalibMinV, pad1Velocity)
                    root.pad1CalibMinA = Math.min(root.pad1CalibMinA, pad1Aftertouch)
                } else {
                    root.pad1CalibMaxV = Math.max(root.pad1CalibMaxV, pad1Velocity)
                    root.pad1CalibMaxA = Math.max(root.pad1CalibMaxA, pad1Aftertouch)
                }
            }
        }
        if (controllersData.pad2) {
            pad2Velocity = controllersData.pad2.velocity || 0
            pad2Aftertouch = controllersData.pad2.aftertouch || 0
            pad2Active = controllersData.pad2.active || false
            if (root.pad2CalibrationActive) {
                if (root.padCalibrationMode === "min") {
                    root.pad2CalibMinV = Math.min(root.pad2CalibMinV, pad2Velocity)
                    root.pad2CalibMinA = Math.min(root.pad2CalibMinA, pad2Aftertouch)
                } else {
                    root.pad2CalibMaxV = Math.max(root.pad2CalibMaxV, pad2Velocity)
                    root.pad2CalibMaxA = Math.max(root.pad2CalibMaxA, pad2Aftertouch)
                }
            }
        }
        if (controllersData.buttons) {
            button1 = controllersData.buttons.button1 || false
            button2 = controllersData.buttons.button2 || false
        }
        if (controllersData.encoder) {
            encoderValue = controllersData.encoder.value || 0
            encoderPressed = controllersData.encoder.pressed || false
        }
    }

    Connections {
        target: root.configController
        ignoreUnknownSignals: true
        function onSettingsUpdated() { root.refreshJoystickCalibrationStateFromConfig() }
    }

    Component.onCompleted: root.refreshJoystickCalibrationStateFromConfig()

    // ------------------------------------------------------------------
    // Briques visuelles
    // ------------------------------------------------------------------

    // Carte : titre + contenu empilé
    component Card: Rectangle {
        id: card
        property string title: ""
        property bool lit: false            // allumée quand le contrôleur est actif
        default property alias content: body.data
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 200
        implicitHeight: body.implicitHeight + 40
        color: "#141414"
        radius: 6
        border.width: 1
        border.color: lit ? "#00ff00" : "#2a2a2a"
        Text {
            id: cardTitle
            text: card.title
            color: card.lit ? "#00ff00" : "#88ff88"
            font.pixelSize: 13
            font.bold: true
            font.letterSpacing: 1.5
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 10
        }
        Column {
            id: body
            spacing: 8
            anchors.top: cardTitle.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
        }
    }

    // Jauge horizontale 0..max, avec libellé et valeur
    component Gauge: Item {
        id: gauge
        property string label: ""
        property real value: 0
        property real maximum: 127
        property string text: String(Math.round(value))
        width: parent ? parent.width : 150
        implicitHeight: 22
        Text {
            id: gaugeLabel
            text: gauge.label
            color: "#7a7a7a"
            font.pixelSize: 12
            width: 44
            anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
            id: track
            anchors.left: gaugeLabel.right
            anchors.right: gaugeValue.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 10
            radius: 3
            color: "#262626"
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, gauge.value / gauge.maximum))
                height: parent.height
                radius: 3
                color: "#00ff00"
            }
        }
        Text {
            id: gaugeValue
            text: gauge.text
            color: "#ccffcc"
            font.pixelSize: 13
            font.family: "monospace"
            horizontalAlignment: Text.AlignRight
            width: 48
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Voyant rond + libellé (boutons)
    component Lamp: Row {
        property string label: ""
        property bool on: false
        spacing: 6
        Rectangle {
            width: 14; height: 14; radius: 7
            color: parent.on ? "#00ff00" : "#262626"
            border.color: parent.on ? "#00ff00" : "#444444"
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: parent.label
            color: parent.on ? "#00ff00" : "#7a7a7a"
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Bouton plat : simple ou à état (choisi)
    component FlatButton: Rectangle {
        id: fb
        property string label: ""
        property bool selected: false
        signal clicked()
        implicitWidth: Math.max(44, fbText.implicitWidth + 16)
        implicitHeight: 26
        radius: 4
        color: selected ? "#00aa00" : (fbMouse.containsMouse ? "#3a3a3a" : "#2a2a2a")
        border.color: "#00ff00"
        border.width: selected ? 2 : 1
        Text {
            id: fbText
            anchors.centerIn: parent
            text: fb.label
            color: fb.selected ? "#000000" : "#00ff00"
            font.pixelSize: 11
            font.bold: fb.selected
        }
        MouseArea {
            id: fbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fb.clicked()
        }
    }

    // ------------------------------------------------------------------
    // Mise en page
    // ------------------------------------------------------------------

    // Barre d'outils : tests
    Row {
        id: toolBar
        visible: root.showControllerValues()
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 10
        spacing: 8
        FlatButton {
            label: root.leftSpeakerTestOn ? "HP G ON" : "HP G"
            selected: root.leftSpeakerTestOn
            onClicked: { root.leftSpeakerTestOn = !root.leftSpeakerTestOn; root.testSpeaker("left", root.leftSpeakerTestOn) }
        }
        FlatButton {
            label: root.rightSpeakerTestOn ? "HP D ON" : "HP D"
            selected: root.rightSpeakerTestOn
            onClicked: { root.rightSpeakerTestOn = !root.rightSpeakerTestOn; root.testSpeaker("right", root.rightSpeakerTestOn) }
        }
        FlatButton {
            visible: root.isShown("fader")
            label: root.faderTestActive ? "TEST FADER ON" : "TEST FADER"
            selected: root.faderTestActive
            onClicked: { root.faderTestActive = !root.faderTestActive; root.testFader(root.faderTestActive) }
        }
    }

    GridLayout {
        id: grid
        anchors.top: toolBar.visible ? toolBar.bottom : parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        columns: Math.max(2, Math.floor(width / 260))
        rowSpacing: 10
        columnSpacing: 10

        // --- Volant ---
        Card {
            title: "VOLANT"
            visible: root.isShown("wheel")
            lit: root.wheelSpeed !== 0
            Item {
                width: parent.width
                height: 90
                Rectangle {
                    id: dial
                    width: 80; height: 80; radius: 40
                    anchors.centerIn: parent
                    color: "transparent"
                    border.color: "#444444"
                    border.width: 2
                    Rectangle {
                        width: 3; height: 36
                        color: root.accent
                        antialiasing: true
                        x: dial.width / 2 - width / 2
                        y: dial.height / 2 - height
                        transform: Rotation {
                            origin.x: 1.5; origin.y: 36
                            angle: root.wheelPosition
                        }
                    }
                }
            }
            Gauge { label: "angle"; value: root.wheelPosition; maximum: 360; text: Math.round(root.wheelPosition) + "°" }
            Gauge { label: "vitesse"; value: Math.abs(root.wheelSpeed); maximum: 127; text: String(Math.round(root.wheelSpeed)) }
        }

        // --- Levier ---
        Card {
            title: "LEVIER"
            visible: root.isShown("gearShift")
            Row {
                spacing: 6
                anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: [0, 1, 12, 24, 48]
                    Rectangle {
                        width: 40; height: 40; radius: 4
                        color: index === root.gearShiftPosition ? root.accent : "#262626"
                        border.color: "#444444"
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: index === root.gearShiftPosition ? "#000000" : root.dimText
                            font.pixelSize: 13
                            font.bold: index === root.gearShiftPosition
                        }
                    }
                }
            }
            Text {
                text: "position " + root.gearShiftPosition + " · " + root.gearShiftMode + " demi-tons"
                color: root.valueText
                font.pixelSize: 12
            }
        }

        // --- Joystick ---
        Card {
            title: "JOYSTICK"
            visible: root.isShown("joystick")
            lit: root.joystickButton || Math.abs(root.joystickX) > 0.05 || Math.abs(root.joystickY) > 0.05
            Layout.columnSpan: grid.columns >= 4 ? 2 : 1
            Row {
                spacing: 14
                width: parent.width
                // Position X/Y
                Rectangle {
                    id: joyBox
                    width: 110; height: 110
                    color: "#1a1a1a"
                    border.color: "#444444"
                    Rectangle { width: 1; height: parent.height; x: parent.width / 2; color: "#333333" }
                    Rectangle { width: parent.width; height: 1; y: parent.height / 2; color: "#333333" }
                    Rectangle {
                        width: 12; height: 12; radius: 6
                        color: root.joystickButton ? "#ffffff" : root.accent
                        x: joyBox.width / 2 + Math.max(-1, Math.min(1, root.joystickX)) * (joyBox.width / 2 - 6) - 6
                        y: joyBox.height / 2 - Math.max(-1, Math.min(1, root.joystickY)) * (joyBox.height / 2 - 6) - 6
                    }
                }
                Column {
                    spacing: 6
                    width: parent.width - joyBox.width - 14
                    Gauge { label: "X"; value: Math.abs(root.joystickX) * 127; text: String(Math.round(root.joystickRawX)) }
                    Gauge { label: "Y"; value: Math.abs(root.joystickY) * 127; text: String(Math.round(root.joystickRawY)) }
                    Gauge { label: "Z"; value: Math.abs(root.joystickZ) * 127; text: String(Math.round(root.joystickZ * 127)) }
                    Lamp { label: "bouton"; on: root.joystickButton }
                    Text {
                        visible: root.joystickFilteredReceived
                        text: "filtré  X " + Math.round(root.joystickFilteredX) + "   Y " + Math.round(root.joystickFilteredY)
                        color: "#ffeeaa"
                        font.pixelSize: 12
                        font.family: "monospace"
                    }
                }
            }
            // Calibrage
            Row {
                spacing: 4
                Repeater {
                    model: [["min", "min"], ["zero_min", "0.min"], ["zero_max", "0.max"], ["max", "max"]]
                    FlatButton {
                        label: modelData[1]
                        selected: root.joystickCalibrationMode === modelData[0]
                        onClicked: root.joystickCalibrationMode = modelData[0]
                    }
                }
                Item { width: 8; height: 1 }
                FlatButton { label: "Calibrer X"; onClicked: root.sendJoystickCalibration("x") }
                FlatButton { label: "Calibrer Y"; onClicked: root.sendJoystickCalibration("y") }
            }
            Text {
                text: "seuils X  " + [0, 1, 2, 3].map(function (i) { return root.joyCalibSlot("x", i) }).join(" / ")
                      + "     Y  " + [0, 1, 2, 3].map(function (i) { return root.joyCalibSlot("y", i) }).join(" / ")
                color: root.valueText
                font.pixelSize: 11
                font.family: "monospace"
            }
        }

        // --- Pads ---
        Repeater {
            model: 2
            Card {
                readonly property bool active: index === 0 ? root.pad1Active : root.pad2Active
                title: "PAD " + (index + 1)
                visible: root.isShown("pad")
                lit: active
                Gauge { label: "frappe"; value: index === 0 ? root.pad1Velocity : root.pad2Velocity }
                Gauge { label: "pression"; value: index === 0 ? root.pad1Aftertouch : root.pad2Aftertouch }
                Text {
                    text: "brut " + root.padCalibDisplayValues[index]
                    color: root.dimText
                    font.pixelSize: 12
                    font.family: "monospace"
                }
                Row {
                    spacing: 4
                    FlatButton { label: "Min"; selected: root.padCalibrationMode === "min"; onClicked: root.padCalibrationMode = "min" }
                    FlatButton { label: "Max"; selected: root.padCalibrationMode === "max"; onClicked: root.padCalibrationMode = "max" }
                    FlatButton { label: "Calibrer"; onClicked: root.sendPadCalibration(index) }
                }
            }
        }

        // --- Slider (fader) ---
        Card {
            title: "SLIDER"
            visible: root.isShown("fader")
            lit: root.faderTestActive
            Gauge { label: "valeur"; value: root.faderValue }
        }

        // --- Pédale ---
        Card {
            title: "PÉDALE"
            visible: root.isShown("modPedal")
            Gauge { label: "valeur"; value: root.modPedalValue }
            Text {
                text: Math.round(root.modPedalPercent) + " %"
                color: root.valueText
                font.pixelSize: 12
            }
        }

        // --- Encodeur ---
        Card {
            title: "ENCODEUR"
            visible: root.isShown("encoder")
            lit: root.encoderPressed
            Gauge { label: "valeur"; value: root.encoderValue }
            Lamp { label: "appuyé"; on: root.encoderPressed }
        }

        // --- Boutons ---
        Card {
            title: "BOUTONS"
            lit: root.button1 || root.button2
            Row {
                spacing: 18
                Lamp { label: "bouton 1"; on: root.button1 }
                Lamp { label: "bouton 2"; on: root.button2 }
            }
        }
    }
}
