import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: controllersTab
    
    property var pupitre: null
    
    function patchControllerMapping(ctrlKey, cc, curve) {
        if (!pupitre || !pupitre.id) return
        var payload = { pupitreId: pupitre.id, controller: ctrlKey }
        if (cc !== undefined) payload.cc = cc
        if (curve !== undefined) payload.curve = curve
        var xhr = new XMLHttpRequest()
        xhr.open("PATCH", "http://localhost:8001/api/presets/current/controller-mapping")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify(payload))
    }
    
    // Fond gris pour l'ensemble du tab
    Rectangle {
        anchors.fill: parent
        color: "#333333"
        border.color: "#555555"
        border.width: 1
        radius: 8
    }
    
    ScrollView {
        anchors.fill: parent
        anchors.margins: 15
        contentWidth: parent.width - 30
        
        ColumnLayout {
            width: parent.width
            spacing: 15
            
            Repeater {
                model: [
                    {name: "Joystick X", key: "joystickX"},
                    {name: "Joystick Y", key: "joystickY"},
                    {name: "Joystick Z", key: "joystickZ"}, 
                    {name: "Fader", key: "fader"},
                    {name: "Selector", key: "selector"},
                    {name: "Pedal ID", key: "pedalId"}
                ]
                
                GroupBox {
                    title: modelData.name
                    Layout.fillWidth: true
                    
                    background: Rectangle {
                        color: "#2a2a2a"
                        border.color: "#666666"
                        border.width: 1
                        radius: 6
                    }
                    
                    label: Text {
                        text: parent.title
                        color: "#ffffff"
                        font.pixelSize: 14
                        font.bold: true
                        leftPadding: 10
                        topPadding: 8
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        
                        Text {
                            text: "CC:"
                            color: "#cccccc"
                            Layout.preferredWidth: 40
                        }
                        SpinBox {
                            Layout.preferredWidth: 150
                            Layout.preferredHeight: 35
                            from: 0
                            to: 127
                            value: pupitre && pupitre.controllerMapping && pupitre.controllerMapping[modelData.key] ? pupitre.controllerMapping[modelData.key].cc : 1
                            
                            editable: true
                            
                            background: Rectangle {
                                color: "#444444"
                                border.color: "#666666"
                                border.width: 1
                                radius: 4
                            }
                            
                            textFromValue: function(value, locale) {
                                return value.toString()
                            }
                            
                            valueFromText: function(text, locale) {
                                var val = parseInt(text)
                                return isNaN(val) ? 0 : Math.max(0, Math.min(127, val))
                            }
                            
                            onValueChanged: {
                                if (pupitre && pupitre.controllerMapping) {
                                    if (!pupitre.controllerMapping[modelData.key]) pupitre.controllerMapping[modelData.key] = {}
                                    pupitre.controllerMapping[modelData.key].cc = value
                                    patchControllerMapping(modelData.key, value, undefined)
                                }
                            }
                        }
                        Text {
                            text: "Courbe:"
                            color: "#cccccc"
                            Layout.preferredWidth: 60
                        }
                        ComboBox {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 35
                            model: ["linear", "parabolic", "hyperbolic", "s curve"]
                            currentIndex: {
                                if (pupitre && pupitre.controllerMapping && pupitre.controllerMapping[modelData.key]) {
                                    return model.indexOf(pupitre.controllerMapping[modelData.key].curve)
                                }
                                return 0
                            }
                            
                            background: Rectangle {
                                color: "#444444"
                                border.color: "#666666"
                                border.width: 1
                                radius: 4
                            }
                            
                            contentItem: Text {
                                text: parent.displayText
                                color: "#ffffff"
                                leftPadding: 10
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 12
                            }
                            
                            indicator: Rectangle {
                                x: parent.width - width - 5
                                y: parent.topPadding + (parent.availableHeight - height) / 2
                                width: 12
                                height: 8
                                color: "#cccccc"
                                radius: 2
                            }
                            
                            onCurrentTextChanged: {
                                if (pupitre && pupitre.controllerMapping) {
                                    if (!pupitre.controllerMapping[modelData.key]) pupitre.controllerMapping[modelData.key] = {}
                                    pupitre.controllerMapping[modelData.key].curve = currentText
                                    patchControllerMapping(modelData.key, undefined, currentText)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
