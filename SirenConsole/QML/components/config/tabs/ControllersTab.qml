import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../../../utils" as Utils

Item {
    id: controllersTab
    
    // Instance de NetworkUtils pour obtenir l'URL de base de l'API
    Utils.NetworkUtils {
        id: networkUtils
    }
    
    property var pupitre: null
    // Snapshot et rafraîchissement local (comme Outputs/Sirens)
    property var currentPresetSnapshot: null
    property int updateTrigger: 0
    function forceRefresh() { updateTrigger++ }
    function patchAndApply(url, body, applyFn) {
        var xhr = new XMLHttpRequest()
        xhr.open("PATCH", url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                if (applyFn) applyFn()
                forceRefresh()
            }
        }
        xhr.send(JSON.stringify(body))
    }
    function updateSnapshotControllerMapping(pupitreId, ctrlKey, changes) {
        if (!controllersTab.currentPresetSnapshot || !controllersTab.currentPresetSnapshot.config) return
        var list = controllersTab.currentPresetSnapshot.config.pupitres || []
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === pupitreId) {
                if (!list[i].controllerMapping) list[i].controllerMapping = {}
                if (!list[i].controllerMapping[ctrlKey]) list[i].controllerMapping[ctrlKey] = {}
                for (var k in changes) list[i].controllerMapping[ctrlKey][k] = changes[k]
                break
            }
        }
    }
    
    function patchControllerMapping(ctrlKey, cc, curve) {
        if (!pupitre || !pupitre.id) return
        var payload = { pupitreId: pupitre.id, controller: ctrlKey }
        if (cc !== undefined) payload.cc = cc
        if (curve !== undefined) payload.curve = curve
        var xhr = new XMLHttpRequest()
        var apiUrl = networkUtils.getApiBaseUrl()
        xhr.open("PATCH", apiUrl + "/api/presets/current/controller-mapping")
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
        
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            visible: true
        }
        
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
                            value: {
                                var _ = controllersTab.updateTrigger
                                if (!controllersTab.currentPresetSnapshot || !controllersTab.currentPresetSnapshot.config || !pupitre) return 1
                                var list = controllersTab.currentPresetSnapshot.config.pupitres || []
                                for (var i = 0; i < list.length; i++) if (list[i].id === pupitre.id) {
                                    var m = list[i].controllerMapping || {}
                                    var entry = m[modelData.key]
                                    return (entry && entry.cc !== undefined) ? entry.cc : 1
                                }
                                return 1
                            }
                            
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
                                if (!pupitre || !controllersTab.currentPresetSnapshot || !controllersTab.currentPresetSnapshot.config) return
                                var pid = pupitre.id
                                var ctrl = modelData.key
                                // Ne pas PATCH si identique au snapshot
                                var list = controllersTab.currentPresetSnapshot.config.pupitres || []
                                for (var i = 0; i < list.length; i++) if (list[i].id === pid) {
                                    var m = list[i].controllerMapping || {}
                                    var entry = m[ctrl]
                                    var prev = (entry && entry.cc !== undefined) ? entry.cc : 1
                                    if (prev === value) return
                                    break
                                }
                                var apiUrl = networkUtils.getApiBaseUrl()
                                patchAndApply(
                                    apiUrl + "/api/presets/current/controller-mapping",
                                    { pupitreId: pid, controller: ctrl, cc: value },
                                    function() { updateSnapshotControllerMapping(pid, ctrl, { cc: value }) }
                                )
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
                                var _ = controllersTab.updateTrigger
                                if (!controllersTab.currentPresetSnapshot || !controllersTab.currentPresetSnapshot.config || !pupitre) return 0
                                var list = controllersTab.currentPresetSnapshot.config.pupitres || []
                                for (var i = 0; i < list.length; i++) if (list[i].id === pupitre.id) {
                                    var m = list[i].controllerMapping || {}
                                    var entry = m[modelData.key]
                                    var curve = entry && entry.curve ? entry.curve : "linear"
                                    return model.indexOf(curve)
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
                                if (!pupitre || !controllersTab.currentPresetSnapshot || !controllersTab.currentPresetSnapshot.config) return
                                var pid = pupitre.id
                                var ctrl = modelData.key
                                var curve = currentText
                                // Ne pas PATCH si identique au snapshot
                                var list = controllersTab.currentPresetSnapshot.config.pupitres || []
                                for (var i = 0; i < list.length; i++) if (list[i].id === pid) {
                                    var m = list[i].controllerMapping || {}
                                    var entry = m[ctrl]
                                    var prev = entry && entry.curve ? entry.curve : "linear"
                                    if (prev === curve) return
                                    break
                                }
                                var apiUrl = networkUtils.getApiBaseUrl()
                                patchAndApply(
                                    apiUrl + "/api/presets/current/controller-mapping",
                                    { pupitreId: pid, controller: ctrl, curve: curve },
                                    function() { updateSnapshotControllerMapping(pid, ctrl, { curve: curve }) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
