import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property var configController: null
    
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
                border.color: "#333"
                border.width: 1
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
                            color: parent.checked ? "#FFD700" : "#AAA"
                            font.pixelSize: 14
                            leftPadding: parent.indicator.width + parent.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: udpRadio.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 10
                            border.color: udpRadio.checked ? "#FFD700" : "#666"
                            border.width: 2
                            color: "transparent"
                            
                            Rectangle {
                                width: 10
                                height: 10
                                x: 5
                                y: 5
                                radius: 5
                                color: "#FFD700"
                                visible: udpRadio.checked
                            }
                        }
                        
                        onClicked: {
                            if (root.configController) {
                                root.configController.setValueAtPath(["outputConfig", "sirenMode"], "udp")
                            }
                        }
                    }
                    
                    RadioButton {
                        id: rtpmidiRadio
                        text: "Sirènes V2 via RTPMIDI"
                        checked: root.configController ? root.configController.getValueAtPath(["outputConfig", "sirenMode"], "udp") === "rtpmidi" : false
                        ButtonGroup.group: sirenModeGroup
                        
                        contentItem: Text {
                            text: parent.text
                            color: parent.checked ? "#FFD700" : "#AAA"
                            font.pixelSize: 14
                            leftPadding: parent.indicator.width + parent.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: rtpmidiRadio.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 10
                            border.color: rtpmidiRadio.checked ? "#FFD700" : "#666"
                            border.width: 2
                            color: "transparent"
                            
                            Rectangle {
                                width: 10
                                height: 10
                                x: 5
                                y: 5
                                radius: 5
                                color: "#FFD700"
                                visible: rtpmidiRadio.checked
                            }
                        }
                        
                        onClicked: {
                            if (root.configController) {
                                root.configController.setValueAtPath(["outputConfig", "sirenMode"], "rtpmidi")
                            }
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
                            color: parent.checked ? "#FFD700" : "#AAA"
                            font.pixelSize: 14
                            leftPadding: parent.indicator.width + parent.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: composeSirenCheckbox.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 3
                            border.color: composeSirenCheckbox.checked ? "#FFD700" : "#666"
                            border.width: 2
                            color: "transparent"
                            
                            Rectangle {
                                width: 12
                                height: 12
                                x: 4
                                y: 4
                                radius: 2
                                color: "#FFD700"
                                visible: composeSirenCheckbox.checked
                            }
                        }
                        
                        onClicked: {
                            if (root.configController) {
                                root.configController.setValueAtPath(["composeSiren", "enabled"], checked)
                            }
                        }
                    }
                }
            }
            
            // Section volume ComposeSirene
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                color: "#1a1a1a"
                border.color: "#333"
                border.width: 1
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
                            color: "#CCC"
                            font.pixelSize: 16
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        
                        Text {
                            id: volumeValue
                            text: Math.round(volumeSlider.value)
                            color: "#FFD700"
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
                                color: "#FFD700"
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
                            border.color: "#FFD700"
                            border.width: 2
                        }
                        
                        onValueChanged: {
                            if (root.configController && !volumeSlider.pressed) {
                                return // Ne mettre à jour que quand l'utilisateur relâche
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
                        
                        Text {
                            text: "0"
                            color: "#666"
                            font.pixelSize: 12
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Text {
                            text: "64"
                            color: "#666"
                            font.pixelSize: 12
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Text {
                            text: "127"
                            color: "#666"
                            font.pixelSize: 12
                        }
                    }
                }
            }
            
            // Section Reverb
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: reverbColumn.implicitHeight + 40
                color: "#1a1a1a"
                border.color: "#333"
                border.width: 1
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
                                color: parent.checked ? "#00FF00" : "#AAA"
                                font.pixelSize: 14
                                leftPadding: parent.indicator.width + parent.spacing
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            indicator: Rectangle {
                                implicitWidth: 20
                                implicitHeight: 20
                                x: reverbEnableCheckbox.leftPadding
                                y: parent.height / 2 - height / 2
                                radius: 3
                                border.color: reverbEnableCheckbox.checked ? "#00FF00" : "#666"
                                border.width: 2
                                color: "transparent"
                                
                                Rectangle {
                                    width: 12
                                    height: 12
                                    x: 4
                                    y: 4
                                    radius: 2
                                    color: "#00FF00"
                                    visible: reverbEnableCheckbox.checked
                                }
                            }
                            
                            onClicked: {
                                if (root.configController) {
                                    root.configController.setValueAtPath(["composeSiren", "controllers", "reverbEnable", "value"], checked ? 127 : 0)
                                }
                            }
                        }
                    }
                    
                    // Room Size
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Text {
                            text: "Room Size"
                            color: "#AAA"
                            font.pixelSize: 14
                            Layout.preferredWidth: 120
                        }
                        
                        Slider {
                            id: roomSizeSlider
                            Layout.fillWidth: true
                            from: 0
                            to: 127
                            value: root.configController ? root.configController.getValueAtPath(["composeSiren", "controllers", "roomSize", "value"], 64) : 64
                            stepSize: 1
                            
                            background: Rectangle {
                                x: roomSizeSlider.leftPadding
                                y: roomSizeSlider.topPadding + roomSizeSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200
                                implicitHeight: 4
                                width: roomSizeSlider.availableWidth
                                height: implicitHeight
                                radius: 2
                                color: "#333"
                                
                                Rectangle {
                                    width: roomSizeSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: "#4CAF50"
                                    radius: 2
                                }
                            }
                            
                            handle: Rectangle {
                                x: roomSizeSlider.leftPadding + roomSizeSlider.visualPosition * (roomSizeSlider.availableWidth - width)
                                y: roomSizeSlider.topPadding + roomSizeSlider.availableHeight / 2 - height / 2
                                implicitWidth: 16
                                implicitHeight: 16
                                radius: 8
                                color: roomSizeSlider.pressed ? "#4CAF50" : "#FFF"
                                border.color: "#4CAF50"
                                border.width: 2
                            }
                            
                            onPressedChanged: {
                                if (!pressed && root.configController) {
                                    root.configController.setValueAtPath(["composeSiren", "controllers", "roomSize", "value"], Math.round(value))
                                }
                            }
                        }
                        
                        Text {
                            text: Math.round(roomSizeSlider.value)
                            color: "#4CAF50"
                            font.pixelSize: 14
                            font.bold: true
                            Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                    
                    // Dry/Wet
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Text {
                            text: "Dry/Wet"
                            color: "#AAA"
                            font.pixelSize: 14
                            Layout.preferredWidth: 120
                        }
                        
                        Slider {
                            id: dryWetSlider
                            Layout.fillWidth: true
                            from: 0
                            to: 127
                            value: root.configController ? root.configController.getValueAtPath(["composeSiren", "controllers", "dryWet", "value"], 38) : 38
                            stepSize: 1
                            
                            background: Rectangle {
                                x: dryWetSlider.leftPadding
                                y: dryWetSlider.topPadding + dryWetSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200
                                implicitHeight: 4
                                width: dryWetSlider.availableWidth
                                height: implicitHeight
                                radius: 2
                                color: "#333"
                                
                                Rectangle {
                                    width: dryWetSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: "#2196F3"
                                    radius: 2
                                }
                            }
                            
                            handle: Rectangle {
                                x: dryWetSlider.leftPadding + dryWetSlider.visualPosition * (dryWetSlider.availableWidth - width)
                                y: dryWetSlider.topPadding + dryWetSlider.availableHeight / 2 - height / 2
                                implicitWidth: 16
                                implicitHeight: 16
                                radius: 8
                                color: dryWetSlider.pressed ? "#2196F3" : "#FFF"
                                border.color: "#2196F3"
                                border.width: 2
                            }
                            
                            onPressedChanged: {
                                if (!pressed && root.configController) {
                                    root.configController.setValueAtPath(["composeSiren", "controllers", "dryWet", "value"], Math.round(value))
                                }
                            }
                        }
                        
                        Text {
                            text: Math.round(dryWetSlider.value)
                            color: "#2196F3"
                            font.pixelSize: 14
                            font.bold: true
                            Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                    
                    // Damp
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Text {
                            text: "Damping"
                            color: "#AAA"
                            font.pixelSize: 14
                            Layout.preferredWidth: 120
                        }
                        
                        Slider {
                            id: dampSlider
                            Layout.fillWidth: true
                            from: 0
                            to: 127
                            value: root.configController ? root.configController.getValueAtPath(["composeSiren", "controllers", "damp", "value"], 64) : 64
                            stepSize: 1
                            
                            background: Rectangle {
                                x: dampSlider.leftPadding
                                y: dampSlider.topPadding + dampSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200
                                implicitHeight: 4
                                width: dampSlider.availableWidth
                                height: implicitHeight
                                radius: 2
                                color: "#333"
                                
                                Rectangle {
                                    width: dampSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: "#FF9800"
                                    radius: 2
                                }
                            }
                            
                            handle: Rectangle {
                                x: dampSlider.leftPadding + dampSlider.visualPosition * (dampSlider.availableWidth - width)
                                y: dampSlider.topPadding + dampSlider.availableHeight / 2 - height / 2
                                implicitWidth: 16
                                implicitHeight: 16
                                radius: 8
                                color: dampSlider.pressed ? "#FF9800" : "#FFF"
                                border.color: "#FF9800"
                                border.width: 2
                            }
                            
                            onPressedChanged: {
                                if (!pressed && root.configController) {
                                    root.configController.setValueAtPath(["composeSiren", "controllers", "damp", "value"], Math.round(value))
                                }
                            }
                        }
                        
                        Text {
                            text: Math.round(dampSlider.value)
                            color: "#FF9800"
                            font.pixelSize: 14
                            font.bold: true
                            Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                    
                    // Width
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Text {
                            text: "Stereo Width"
                            color: "#AAA"
                            font.pixelSize: 14
                            Layout.preferredWidth: 120
                        }
                        
                        Slider {
                            id: reverbWidthSlider
                            Layout.fillWidth: true
                            from: 0
                            to: 127
                            value: root.configController ? root.configController.getValueAtPath(["composeSiren", "controllers", "reverbWidth", "value"], 64) : 64
                            stepSize: 1
                            
                            background: Rectangle {
                                x: reverbWidthSlider.leftPadding
                                y: reverbWidthSlider.topPadding + reverbWidthSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200
                                implicitHeight: 4
                                width: reverbWidthSlider.availableWidth
                                height: implicitHeight
                                radius: 2
                                color: "#333"
                                
                                Rectangle {
                                    width: reverbWidthSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: "#9C27B0"
                                    radius: 2
                                }
                            }
                            
                            handle: Rectangle {
                                x: reverbWidthSlider.leftPadding + reverbWidthSlider.visualPosition * (reverbWidthSlider.availableWidth - width)
                                y: reverbWidthSlider.topPadding + reverbWidthSlider.availableHeight / 2 - height / 2
                                implicitWidth: 16
                                implicitHeight: 16
                                radius: 8
                                color: reverbWidthSlider.pressed ? "#9C27B0" : "#FFF"
                                border.color: "#9C27B0"
                                border.width: 2
                            }
                            
                            onPressedChanged: {
                                if (!pressed && root.configController) {
                                    root.configController.setValueAtPath(["composeSiren", "controllers", "reverbWidth", "value"], Math.round(value))
                                }
                            }
                        }
                        
                        Text {
                            text: Math.round(reverbWidthSlider.value)
                            color: "#9C27B0"
                            font.pixelSize: 14
                            font.bold: true
                            Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }
            
            // Section Limiter
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: limiterColumn.implicitHeight + 40
                color: "#1a1a1a"
                border.color: "#333"
                border.width: 1
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
                                color: parent.checked ? "#FF5722" : "#AAA"
                                font.pixelSize: 14
                                leftPadding: parent.indicator.width + parent.spacing
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            indicator: Rectangle {
                                implicitWidth: 20
                                implicitHeight: 20
                                x: limiterEnableCheckbox.leftPadding
                                y: parent.height / 2 - height / 2
                                radius: 3
                                border.color: limiterEnableCheckbox.checked ? "#FF5722" : "#666"
                                border.width: 2
                                color: "transparent"
                                
                                Rectangle {
                                    width: 12
                                    height: 12
                                    x: 4
                                    y: 4
                                    radius: 2
                                    color: "#FF5722"
                                    visible: limiterEnableCheckbox.checked
                                }
                            }
                            
                            onClicked: {
                                if (root.configController) {
                                    root.configController.setValueAtPath(["composeSiren", "controllers", "limiterEnable", "value"], checked ? 127 : 0)
                                }
                            }
                        }
                    }
                    
                    // Threshold
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Text {
                            text: "Threshold"
                            color: "#AAA"
                            font.pixelSize: 14
                            Layout.preferredWidth: 120
                        }
                        
                        Slider {
                            id: limiterThresholdSlider
                            Layout.fillWidth: true
                            from: 0
                            to: 127
                            value: root.configController ? root.configController.getValueAtPath(["composeSiren", "controllers", "limiterThreshold", "value"], 100) : 100
                            stepSize: 1
                            
                            background: Rectangle {
                                x: limiterThresholdSlider.leftPadding
                                y: limiterThresholdSlider.topPadding + limiterThresholdSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200
                                implicitHeight: 4
                                width: limiterThresholdSlider.availableWidth
                                height: implicitHeight
                                radius: 2
                                color: "#333"
                                
                                Rectangle {
                                    width: limiterThresholdSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: "#FF5722"
                                    radius: 2
                                }
                            }
                            
                            handle: Rectangle {
                                x: limiterThresholdSlider.leftPadding + limiterThresholdSlider.visualPosition * (limiterThresholdSlider.availableWidth - width)
                                y: limiterThresholdSlider.topPadding + limiterThresholdSlider.availableHeight / 2 - height / 2
                                implicitWidth: 16
                                implicitHeight: 16
                                radius: 8
                                color: limiterThresholdSlider.pressed ? "#FF5722" : "#FFF"
                                border.color: "#FF5722"
                                border.width: 2
                            }
                            
                            onPressedChanged: {
                                if (!pressed && root.configController) {
                                    root.configController.setValueAtPath(["composeSiren", "controllers", "limiterThreshold", "value"], Math.round(value))
                                }
                            }
                        }
                        
                        Text {
                            text: Math.round(limiterThresholdSlider.value)
                            color: "#FF5722"
                            font.pixelSize: 14
                            font.bold: true
                            Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignRight
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
            // Force la mise à jour des RadioButtons, Checkbox et Slider
            var currentSirenMode = root.configController.getValueAtPath(["outputConfig", "sirenMode"], "udp")
            udpRadio.checked = (currentSirenMode === "udp")
            rtpmidiRadio.checked = (currentSirenMode === "rtpmidi")
            
            // ComposeSiren Enable
            var composeSirenEnabled = root.configController.getValueAtPath(["composeSiren", "enabled"], true)
            composeSirenCheckbox.checked = composeSirenEnabled
            
            // Master Volume
            var currentVolume = root.configController.getValueAtPath(["composeSiren", "controllers", "masterVolume", "value"], 100)
            if (!volumeSlider.pressed) {
                volumeSlider.value = currentVolume
            }
            
            // Reverb Enable
            var reverbEnabled = root.configController.getValueAtPath(["composeSiren", "controllers", "reverbEnable", "value"], 127)
            reverbEnableCheckbox.checked = (reverbEnabled >= 64)
            
            // Reverb Parameters
            if (!roomSizeSlider.pressed) {
                roomSizeSlider.value = root.configController.getValueAtPath(["composeSiren", "controllers", "roomSize", "value"], 64)
            }
            if (!dryWetSlider.pressed) {
                dryWetSlider.value = root.configController.getValueAtPath(["composeSiren", "controllers", "dryWet", "value"], 38)
            }
            if (!dampSlider.pressed) {
                dampSlider.value = root.configController.getValueAtPath(["composeSiren", "controllers", "damp", "value"], 64)
            }
            if (!reverbWidthSlider.pressed) {
                reverbWidthSlider.value = root.configController.getValueAtPath(["composeSiren", "controllers", "reverbWidth", "value"], 64)
            }
            
            // Limiter Enable
            var limiterEnabled = root.configController.getValueAtPath(["composeSiren", "controllers", "limiterEnable", "value"], 127)
            limiterEnableCheckbox.checked = (limiterEnabled >= 64)
            
            // Limiter Threshold
            if (!limiterThresholdSlider.pressed) {
                limiterThresholdSlider.value = root.configController.getValueAtPath(["composeSiren", "controllers", "limiterThreshold", "value"], 100)
            }
        }
    }
}
