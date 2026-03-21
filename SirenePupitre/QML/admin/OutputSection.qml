import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property var configController: null
    // Focus encodeur dans le panneau Admin (reçu depuis AdminPanel)
    property int adminFocusIndex: -1
    property color focusColor: "#00BFFF"

    // 10 éléments navigables :
    // 1 = mode sortie (UDP/RTPMIDI), 2 = ComposeSirene enable, 3 = Master Volume
    // 4 = Reverb enable, 5 = Room Size, 6 = Dry/Wet, 7 = Damping, 8 = Stereo Width
    // 9 = Limiter enable, 10 = Limiter Threshold
    readonly property int focusCount: 10

    function handleEncoderStep(delta) {
        if (adminFocusIndex < 2) return
        var rel = adminFocusIndex - 1  // index relatif 1..10
        var step = (delta > 0) ? 1 : -1

        switch (rel) {
        case 1: // mode sortie UDP / RTPMIDI
            if (!configController) return
            var curMode = configController.getValueAtPath(["outputConfig", "sirenMode"], "udp")
            configController.setValueAtPath(["outputConfig", "sirenMode"], curMode === "udp" ? "rtpmidi" : "udp")
            break
        case 2: // ComposeSirene enable
            if (!configController) return
            var csEnabled = configController.getValueAtPath(["composeSiren", "enabled"], true)
            configController.setValueAtPath(["composeSiren", "enabled"], !csEnabled)
            break
        case 3: // Master Volume
            _stepSlider(volumeSlider, ["composeSiren", "controllers", "masterVolume", "value"], step)
            break
        case 4: // Reverb Enable
            if (!configController) return
            var revVal = configController.getValueAtPath(["composeSiren", "controllers", "reverbEnable", "value"], 127)
            configController.setValueAtPath(["composeSiren", "controllers", "reverbEnable", "value"], revVal >= 64 ? 0 : 127)
            break
        case 5: // Room Size
            _stepSlider(roomSizeSlider, ["composeSiren", "controllers", "roomSize", "value"], step)
            break
        case 6: // Dry/Wet
            _stepSlider(dryWetSlider, ["composeSiren", "controllers", "dryWet", "value"], step)
            break
        case 7: // Damping
            _stepSlider(dampSlider, ["composeSiren", "controllers", "damp", "value"], step)
            break
        case 8: // Stereo Width
            _stepSlider(reverbWidthSlider, ["composeSiren", "controllers", "reverbWidth", "value"], step)
            break
        case 9: // Limiter Enable
            if (!configController) return
            var limVal = configController.getValueAtPath(["composeSiren", "controllers", "limiterEnable", "value"], 127)
            configController.setValueAtPath(["composeSiren", "controllers", "limiterEnable", "value"], limVal >= 64 ? 0 : 127)
            break
        case 10: // Limiter Threshold
            _stepSlider(limiterThresholdSlider, ["composeSiren", "controllers", "limiterThreshold", "value"], step)
            break
        }
    }

    function _stepSlider(slider, path, step) {
        if (!configController || !slider) return
        var cur = Math.round(slider.value)
        var nv = Math.max(slider.from, Math.min(slider.to, cur + step))
        if (nv !== cur) {
            slider.value = nv
            configController.setValueAtPath(path, nv)
        }
    }

    // Helper pour savoir si un index relatif est en focus
    function _isFocused(relIndex) {
        return (adminFocusIndex >= 2) && (adminFocusIndex - 1 === relIndex)
    }
    
    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth
        
        ColumnLayout {
            width: parent.width
            spacing: 30
            
            // Titre
            Text {
                text: "Configuration des Sorties"
                color: "#FFD700"
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
            }
            
            // Section choix du mode de sortie
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 200
                color: "#1a1a1a"
                border.color: (root._isFocused(1) || root._isFocused(2)) ? root.focusColor : "#333"
                border.width: (root._isFocused(1) || root._isFocused(2)) ? 2 : 1
                radius: 5
                
                ColumnLayout {
                    id: modeColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15
                    
                    Text {
                        text: "Sortie Sirènes"
                        color: "#CCC"
                        font.pixelSize: 16
                        font.bold: true
                    }
                    
                    // Radio buttons pour UDP vs RTPMIDI
                    ButtonGroup {
                        id: sirenModeGroup
                    }
                    
                    RadioButton {
                        id: udpRadio
                        text: "Sirènes V1 via UDP"
                        checked: root.configController ? root.configController.getValueAtPath(["outputConfig", "sirenMode"], "udp") === "udp" : true
                        ButtonGroup.group: sirenModeGroup
                        
                        contentItem: Text {
                            text: parent.text
                            color: root._isFocused(1) ? root.focusColor : (parent.checked ? "#FFD700" : "#AAA")
                            font.pixelSize: 14
                            font.bold: root._isFocused(1)
                            leftPadding: parent.indicator.width + parent.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: udpRadio.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 10
                            border.color: root._isFocused(1) ? root.focusColor : (udpRadio.checked ? "#FFD700" : "#666")
                            border.width: 2
                            color: "transparent"
                            
                            Rectangle {
                                width: 10; height: 10; x: 5; y: 5; radius: 5
                                color: root._isFocused(1) ? root.focusColor : "#FFD700"
                                visible: udpRadio.checked
                            }
                        }
                        
                        onClicked: {
                            if (root.configController)
                                root.configController.setValueAtPath(["outputConfig", "sirenMode"], "udp")
                        }
                    }
                    
                    RadioButton {
                        id: rtpmidiRadio
                        text: "Sirènes V2 via RTPMIDI"
                        checked: root.configController ? root.configController.getValueAtPath(["outputConfig", "sirenMode"], "udp") === "rtpmidi" : false
                        ButtonGroup.group: sirenModeGroup
                        
                        contentItem: Text {
                            text: parent.text
                            color: root._isFocused(1) ? root.focusColor : (parent.checked ? "#FFD700" : "#AAA")
                            font.pixelSize: 14
                            font.bold: root._isFocused(1)
                            leftPadding: parent.indicator.width + parent.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: rtpmidiRadio.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 10
                            border.color: root._isFocused(1) ? root.focusColor : (rtpmidiRadio.checked ? "#FFD700" : "#666")
                            border.width: 2
                            color: "transparent"
                            
                            Rectangle {
                                width: 10; height: 10; x: 5; y: 5; radius: 5
                                color: root._isFocused(1) ? root.focusColor : "#FFD700"
                                visible: rtpmidiRadio.checked
                            }
                        }
                        
                        onClicked: {
                            if (root.configController)
                                root.configController.setValueAtPath(["outputConfig", "sirenMode"], "rtpmidi")
                        }
                    }
                    
                    // Séparateur
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#333"
                        Layout.topMargin: 10
                        Layout.bottomMargin: 10
                    }
                    
                    // Checkbox pour ComposeSirene
                    CheckBox {
                        id: composeSirenCheckbox
                        text: "ComposeSirene via midi interne"
                        checked: root.configController ? root.configController.getValueAtPath(["composeSiren", "enabled"], true) : true
                        
                        contentItem: Text {
                            text: parent.text
                            color: root._isFocused(2) ? root.focusColor : (parent.checked ? "#FFD700" : "#AAA")
                            font.pixelSize: 14
                            font.bold: root._isFocused(2)
                            leftPadding: parent.indicator.width + parent.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: composeSirenCheckbox.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 3
                            border.color: root._isFocused(2) ? root.focusColor : (composeSirenCheckbox.checked ? "#FFD700" : "#666")
                            border.width: 2
                            color: "transparent"
                            
                            Rectangle {
                                width: 12; height: 12; x: 4; y: 4; radius: 2
                                color: root._isFocused(2) ? root.focusColor : "#FFD700"
                                visible: composeSirenCheckbox.checked
                            }
                        }
                        
                        onClicked: {
                            if (root.configController)
                                root.configController.setValueAtPath(["composeSiren", "enabled"], checked)
                        }
                    }
                }
            }
            
            // Section volume ComposeSirene
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                color: "#1a1a1a"
                border.color: root._isFocused(3) ? root.focusColor : "#333"
                border.width: root._isFocused(3) ? 2 : 1
                radius: 5
                
                ColumnLayout {
                    id: volumeColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15
                    
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Text {
                            text: "Master Volume ComposeSirene"
                            color: root._isFocused(3) ? root.focusColor : "#CCC"
                            font.pixelSize: 16
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        
                        Text {
                            id: volumeValue
                            text: Math.round(volumeSlider.value)
                            color: root._isFocused(3) ? root.focusColor : "#FFD700"
                            font.pixelSize: 16
                            font.bold: true
                            Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                    
                    Slider {
                        id: volumeSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 127
                        value: root.configController ? root.configController.getValueAtPath(["composeSiren", "controllers", "masterVolume", "value"], 100) : 100
                        stepSize: 1
                        
                        background: Rectangle {
                            x: volumeSlider.leftPadding
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 6
                            width: volumeSlider.availableWidth
                            height: implicitHeight
                            radius: 3
                            color: "#333"
                            
                            Rectangle {
                                width: volumeSlider.visualPosition * parent.width
                                height: parent.height
                                color: root._isFocused(3) ? root.focusColor : "#FFD700"
                                radius: 3
                            }
                        }
                        
                        handle: Rectangle {
                            x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: 10
                            color: volumeSlider.pressed ? "#FFD700" : "#FFF"
                            border.color: root._isFocused(3) ? root.focusColor : "#FFD700"
                            border.width: 2
                        }
                        
                        onValueChanged: {
                            if (root.configController && !volumeSlider.pressed) {
                                return
                            }
                        }
                        
                        onPressedChanged: {
                            if (!pressed && root.configController) {
                                root.configController.setValueAtPath(["composeSiren", "controllers", "masterVolume", "value"], Math.round(value))
                            }
                        }
                    }
                    
                    // Marqueurs de volume
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        
                        Text { text: "0"; color: "#666"; font.pixelSize: 12 }
                        Item { Layout.fillWidth: true }
                        Text { text: "64"; color: "#666"; font.pixelSize: 12 }
                        Item { Layout.fillWidth: true }
                        Text { text: "127"; color: "#666"; font.pixelSize: 12 }
                    }
                }
            }
            
            // Section Reverb
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: reverbColumn.implicitHeight + 40
                color: "#1a1a1a"
                border.color: (root._isFocused(4) || root._isFocused(5) || root._isFocused(6) || root._isFocused(7) || root._isFocused(8)) ? root.focusColor : "#333"
                border.width: (root._isFocused(4) || root._isFocused(5) || root._isFocused(6) || root._isFocused(7) || root._isFocused(8)) ? 2 : 1
                radius: 5
                
                ColumnLayout {
                    id: reverbColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15
                    
                    // Titre et activation
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Text {
                            text: "Reverb"
                            color: "#CCC"
                            font.pixelSize: 18
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        
                        CheckBox {
                            id: reverbEnableCheckbox
                            checked: root.configController ? root.configController.getValueAtPath(["composeSiren", "controllers", "reverbEnable", "value"], 127) >= 64 : true
                            
                            contentItem: Text {
                                text: "Activé"
                                color: root._isFocused(4) ? root.focusColor : (parent.checked ? "#00FF00" : "#AAA")
                                font.pixelSize: 14
                                font.bold: root._isFocused(4)
                                leftPadding: parent.indicator.width + parent.spacing
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            indicator: Rectangle {
                                implicitWidth: 20
                                implicitHeight: 20
                                x: reverbEnableCheckbox.leftPadding
                                y: parent.height / 2 - height / 2
                                radius: 3
                                border.color: root._isFocused(4) ? root.focusColor : (reverbEnableCheckbox.checked ? "#00FF00" : "#666")
                                border.width: 2
                                color: "transparent"
                                
                                Rectangle {
                                    width: 12; height: 12; x: 4; y: 4; radius: 2
                                    color: root._isFocused(4) ? root.focusColor : "#00FF00"
                                    visible: reverbEnableCheckbox.checked
                                }
                            }
                            
                            onClicked: {
                                if (root.configController)
                                    root.configController.setValueAtPath(["composeSiren", "controllers", "reverbEnable", "value"], checked ? 127 : 0)
                            }
                        }
                    }
                    
                    // Room Size
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Text {
                            text: "Room Size"
                            color: root._isFocused(5) ? root.focusColor : "#AAA"
                            font.pixelSize: 14
                            font.bold: root._isFocused(5)
                            Layout.preferredWidth: 120
                        }
                        
                        Slider {
                            id: roomSizeSlider
                            Layout.fillWidth: true
                            from: 0; to: 127
                            value: root.configController ? root.configController.getValueAtPath(["composeSiren", "controllers", "roomSize", "value"], 64) : 64
                            stepSize: 1
                            
                            background: Rectangle {
                                x: roomSizeSlider.leftPadding
                                y: roomSizeSlider.topPadding + roomSizeSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200; implicitHeight: 4
                                width: roomSizeSlider.availableWidth; height: implicitHeight
                                radius: 2; color: "#333"
                                Rectangle {
                                    width: roomSizeSlider.visualPosition * parent.width; height: parent.height
                                    color: root._isFocused(5) ? root.focusColor : "#4CAF50"; radius: 2
                                }
                            }
                            handle: Rectangle {
                                x: roomSizeSlider.leftPadding + roomSizeSlider.visualPosition * (roomSizeSlider.availableWidth - width)
                                y: roomSizeSlider.topPadding + roomSizeSlider.availableHeight / 2 - height / 2
                                implicitWidth: 16; implicitHeight: 16; radius: 8
                                color: roomSizeSlider.pressed ? "#4CAF50" : "#FFF"
                                border.color: root._isFocused(5) ? root.focusColor : "#4CAF50"; border.width: 2
                            }
                            onPressedChanged: {
                                if (!pressed && root.configController)
                                    root.configController.setValueAtPath(["composeSiren", "controllers", "roomSize", "value"], Math.round(value))
                            }
                        }
                        
                        Text {
                            text: Math.round(roomSizeSlider.value)
                            color: root._isFocused(5) ? root.focusColor : "#4CAF50"
                            font.pixelSize: 14; font.bold: true
                            Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight
                        }
                    }
                    
                    // Dry/Wet
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Text {
                            text: "Dry/Wet"
                            color: root._isFocused(6) ? root.focusColor : "#AAA"
                            font.pixelSize: 14
                            font.bold: root._isFocused(6)
                            Layout.preferredWidth: 120
                        }
                        
                        Slider {
                            id: dryWetSlider
                            Layout.fillWidth: true
                            from: 0; to: 127
                            value: root.configController ? root.configController.getValueAtPath(["composeSiren", "controllers", "dryWet", "value"], 38) : 38
                            stepSize: 1
                            
                            background: Rectangle {
                                x: dryWetSlider.leftPadding
                                y: dryWetSlider.topPadding + dryWetSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200; implicitHeight: 4
                                width: dryWetSlider.availableWidth; height: implicitHeight
                                radius: 2; color: "#333"
                                Rectangle {
                                    width: dryWetSlider.visualPosition * parent.width; height: parent.height
                                    color: root._isFocused(6) ? root.focusColor : "#2196F3"; radius: 2
                                }
                            }
                            handle: Rectangle {
                                x: dryWetSlider.leftPadding + dryWetSlider.visualPosition * (dryWetSlider.availableWidth - width)
                                y: dryWetSlider.topPadding + dryWetSlider.availableHeight / 2 - height / 2
                                implicitWidth: 16; implicitHeight: 16; radius: 8
                                color: dryWetSlider.pressed ? "#2196F3" : "#FFF"
                                border.color: root._isFocused(6) ? root.focusColor : "#2196F3"; border.width: 2
                            }
                            onPressedChanged: {
                                if (!pressed && root.configController)
                                    root.configController.setValueAtPath(["composeSiren", "controllers", "dryWet", "value"], Math.round(value))
                            }
                        }
                        
                        Text {
                            text: Math.round(dryWetSlider.value)
                            color: root._isFocused(6) ? root.focusColor : "#2196F3"
                            font.pixelSize: 14; font.bold: true
                            Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight
                        }
                    }
                    
                    // Damp
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Text {
                            text: "Damping"
                            color: root._isFocused(7) ? root.focusColor : "#AAA"
                            font.pixelSize: 14
                            font.bold: root._isFocused(7)
                            Layout.preferredWidth: 120
                        }
                        
                        Slider {
                            id: dampSlider
                            Layout.fillWidth: true
                            from: 0; to: 127
                            value: root.configController ? root.configController.getValueAtPath(["composeSiren", "controllers", "damp", "value"], 64) : 64
                            stepSize: 1
                            
                            background: Rectangle {
                                x: dampSlider.leftPadding
                                y: dampSlider.topPadding + dampSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200; implicitHeight: 4
                                width: dampSlider.availableWidth; height: implicitHeight
                                radius: 2; color: "#333"
                                Rectangle {
                                    width: dampSlider.visualPosition * parent.width; height: parent.height
                                    color: root._isFocused(7) ? root.focusColor : "#FF9800"; radius: 2
                                }
                            }
                            handle: Rectangle {
                                x: dampSlider.leftPadding + dampSlider.visualPosition * (dampSlider.availableWidth - width)
                                y: dampSlider.topPadding + dampSlider.availableHeight / 2 - height / 2
                                implicitWidth: 16; implicitHeight: 16; radius: 8
                                color: dampSlider.pressed ? "#FF9800" : "#FFF"
                                border.color: root._isFocused(7) ? root.focusColor : "#FF9800"; border.width: 2
                            }
                            onPressedChanged: {
                                if (!pressed && root.configController)
                                    root.configController.setValueAtPath(["composeSiren", "controllers", "damp", "value"], Math.round(value))
                            }
                        }
                        
                        Text {
                            text: Math.round(dampSlider.value)
                            color: root._isFocused(7) ? root.focusColor : "#FF9800"
                            font.pixelSize: 14; font.bold: true
                            Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight
                        }
                    }
                    
                    // Width
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Text {
                            text: "Stereo Width"
                            color: root._isFocused(8) ? root.focusColor : "#AAA"
                            font.pixelSize: 14
                            font.bold: root._isFocused(8)
                            Layout.preferredWidth: 120
                        }
                        
                        Slider {
                            id: reverbWidthSlider
                            Layout.fillWidth: true
                            from: 0; to: 127
                            value: root.configController ? root.configController.getValueAtPath(["composeSiren", "controllers", "reverbWidth", "value"], 64) : 64
                            stepSize: 1
                            
                            background: Rectangle {
                                x: reverbWidthSlider.leftPadding
                                y: reverbWidthSlider.topPadding + reverbWidthSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200; implicitHeight: 4
                                width: reverbWidthSlider.availableWidth; height: implicitHeight
                                radius: 2; color: "#333"
                                Rectangle {
                                    width: reverbWidthSlider.visualPosition * parent.width; height: parent.height
                                    color: root._isFocused(8) ? root.focusColor : "#9C27B0"; radius: 2
                                }
                            }
                            handle: Rectangle {
                                x: reverbWidthSlider.leftPadding + reverbWidthSlider.visualPosition * (reverbWidthSlider.availableWidth - width)
                                y: reverbWidthSlider.topPadding + reverbWidthSlider.availableHeight / 2 - height / 2
                                implicitWidth: 16; implicitHeight: 16; radius: 8
                                color: reverbWidthSlider.pressed ? "#9C27B0" : "#FFF"
                                border.color: root._isFocused(8) ? root.focusColor : "#9C27B0"; border.width: 2
                            }
                            onPressedChanged: {
                                if (!pressed && root.configController)
                                    root.configController.setValueAtPath(["composeSiren", "controllers", "reverbWidth", "value"], Math.round(value))
                            }
                        }
                        
                        Text {
                            text: Math.round(reverbWidthSlider.value)
                            color: root._isFocused(8) ? root.focusColor : "#9C27B0"
                            font.pixelSize: 14; font.bold: true
                            Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }
            
            // Section Limiter
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: limiterColumn.implicitHeight + 40
                color: "#1a1a1a"
                border.color: (root._isFocused(9) || root._isFocused(10)) ? root.focusColor : "#333"
                border.width: (root._isFocused(9) || root._isFocused(10)) ? 2 : 1
                radius: 5
                
                ColumnLayout {
                    id: limiterColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15
                    
                    // Titre et activation
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Text {
                            text: "Limiter"
                            color: "#CCC"
                            font.pixelSize: 18
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        
                        CheckBox {
                            id: limiterEnableCheckbox
                            checked: root.configController ? root.configController.getValueAtPath(["composeSiren", "controllers", "limiterEnable", "value"], 127) >= 64 : true
                            
                            contentItem: Text {
                                text: "Activé"
                                color: root._isFocused(9) ? root.focusColor : (parent.checked ? "#FF5722" : "#AAA")
                                font.pixelSize: 14
                                font.bold: root._isFocused(9)
                                leftPadding: parent.indicator.width + parent.spacing
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            indicator: Rectangle {
                                implicitWidth: 20
                                implicitHeight: 20
                                x: limiterEnableCheckbox.leftPadding
                                y: parent.height / 2 - height / 2
                                radius: 3
                                border.color: root._isFocused(9) ? root.focusColor : (limiterEnableCheckbox.checked ? "#FF5722" : "#666")
                                border.width: 2
                                color: "transparent"
                                
                                Rectangle {
                                    width: 12; height: 12; x: 4; y: 4; radius: 2
                                    color: root._isFocused(9) ? root.focusColor : "#FF5722"
                                    visible: limiterEnableCheckbox.checked
                                }
                            }
                            
                            onClicked: {
                                if (root.configController)
                                    root.configController.setValueAtPath(["composeSiren", "controllers", "limiterEnable", "value"], checked ? 127 : 0)
                            }
                        }
                    }
                    
                    // Threshold
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Text {
                            text: "Threshold"
                            color: root._isFocused(10) ? root.focusColor : "#AAA"
                            font.pixelSize: 14
                            font.bold: root._isFocused(10)
                            Layout.preferredWidth: 120
                        }
                        
                        Slider {
                            id: limiterThresholdSlider
                            Layout.fillWidth: true
                            from: 0; to: 127
                            value: root.configController ? root.configController.getValueAtPath(["composeSiren", "controllers", "limiterThreshold", "value"], 100) : 100
                            stepSize: 1
                            
                            background: Rectangle {
                                x: limiterThresholdSlider.leftPadding
                                y: limiterThresholdSlider.topPadding + limiterThresholdSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200; implicitHeight: 4
                                width: limiterThresholdSlider.availableWidth; height: implicitHeight
                                radius: 2; color: "#333"
                                Rectangle {
                                    width: limiterThresholdSlider.visualPosition * parent.width; height: parent.height
                                    color: root._isFocused(10) ? root.focusColor : "#FF5722"; radius: 2
                                }
                            }
                            handle: Rectangle {
                                x: limiterThresholdSlider.leftPadding + limiterThresholdSlider.visualPosition * (limiterThresholdSlider.availableWidth - width)
                                y: limiterThresholdSlider.topPadding + limiterThresholdSlider.availableHeight / 2 - height / 2
                                implicitWidth: 16; implicitHeight: 16; radius: 8
                                color: limiterThresholdSlider.pressed ? "#FF5722" : "#FFF"
                                border.color: root._isFocused(10) ? root.focusColor : "#FF5722"; border.width: 2
                            }
                            onPressedChanged: {
                                if (!pressed && root.configController)
                                    root.configController.setValueAtPath(["composeSiren", "controllers", "limiterThreshold", "value"], Math.round(value))
                            }
                        }
                        
                        Text {
                            text: Math.round(limiterThresholdSlider.value)
                            color: root._isFocused(10) ? root.focusColor : "#FF5722"
                            font.pixelSize: 14; font.bold: true
                            Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }
            
            Item { Layout.fillHeight: true }
        }
    }
    
    // Forcer la mise à jour quand le configController change
    Connections {
        target: root.configController
        function onUpdateCounterChanged() {
            var currentSirenMode = root.configController.getValueAtPath(["outputConfig", "sirenMode"], "udp")
            udpRadio.checked = (currentSirenMode === "udp")
            rtpmidiRadio.checked = (currentSirenMode === "rtpmidi")
            
            var composeSirenEnabled = root.configController.getValueAtPath(["composeSiren", "enabled"], true)
            composeSirenCheckbox.checked = composeSirenEnabled
            
            var currentVolume = root.configController.getValueAtPath(["composeSiren", "controllers", "masterVolume", "value"], 100)
            if (!volumeSlider.pressed) volumeSlider.value = currentVolume
            
            var reverbEnabled = root.configController.getValueAtPath(["composeSiren", "controllers", "reverbEnable", "value"], 127)
            reverbEnableCheckbox.checked = (reverbEnabled >= 64)
            
            if (!roomSizeSlider.pressed)
                roomSizeSlider.value = root.configController.getValueAtPath(["composeSiren", "controllers", "roomSize", "value"], 64)
            if (!dryWetSlider.pressed)
                dryWetSlider.value = root.configController.getValueAtPath(["composeSiren", "controllers", "dryWet", "value"], 38)
            if (!dampSlider.pressed)
                dampSlider.value = root.configController.getValueAtPath(["composeSiren", "controllers", "damp", "value"], 64)
            if (!reverbWidthSlider.pressed)
                reverbWidthSlider.value = root.configController.getValueAtPath(["composeSiren", "controllers", "reverbWidth", "value"], 64)
            
            var limiterEnabled = root.configController.getValueAtPath(["composeSiren", "controllers", "limiterEnable", "value"], 127)
            limiterEnableCheckbox.checked = (limiterEnabled >= 64)
            
            if (!limiterThresholdSlider.pressed)
                limiterThresholdSlider.value = root.configController.getValueAtPath(["composeSiren", "controllers", "limiterThreshold", "value"], 100)
        }
    }
}
