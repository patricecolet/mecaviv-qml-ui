import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../../../utils" as Utils

Item {
    id: outputsTab
    
    // Instance de NetworkUtils pour obtenir l'URL de base de l'API
    Utils.NetworkUtils {
        id: networkUtils
    }
    
    property var pupitre: null
    // Snapshot du preset courant, injecté par ConfigPage si présent
    property var currentPresetSnapshot: null
    // Pour forcer la mise à jour visuelle
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
    
    function updateSnapshotOutputs(pupitreId, changes) {
        if (!outputsTab.currentPresetSnapshot || !outputsTab.currentPresetSnapshot.config) return
        var list = outputsTab.currentPresetSnapshot.config.pupitres || []
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === pupitreId) {
                if (changes.hasOwnProperty('vstEnabled')) list[i].vstEnabled = !!changes.vstEnabled
                if (changes.hasOwnProperty('udpEnabled')) list[i].udpEnabled = !!changes.udpEnabled
                if (changes.hasOwnProperty('rtpMidiEnabled')) list[i].rtpMidiEnabled = !!changes.rtpMidiEnabled
                break
            }
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15
        
        CheckBox {
            text: "VST Enabled"
            checked: {
                var _ = outputsTab.updateTrigger
                if (!outputsTab.currentPresetSnapshot || !outputsTab.currentPresetSnapshot.config || !pupitre) return false
                var list = outputsTab.currentPresetSnapshot.config.pupitres || []
                for (var i = 0; i < list.length; i++) if (list[i].id === pupitre.id) return !!list[i].vstEnabled
                return false
            }
            onCheckedChanged: if (pupitre) {
                var apiUrl = networkUtils.getApiBaseUrl()
                patchAndApply(
                    apiUrl + "/api/presets/current/outputs",
                    { pupitreId: pupitre.id, changes: { vstEnabled: !!checked } },
                    function() { updateSnapshotOutputs(pupitre.id, { vstEnabled: !!checked }) }
                )
            }
        }
        CheckBox {
            text: "UDP Enabled"
            checked: {
                var _ = outputsTab.updateTrigger
                if (!outputsTab.currentPresetSnapshot || !outputsTab.currentPresetSnapshot.config || !pupitre) return false
                var list = outputsTab.currentPresetSnapshot.config.pupitres || []
                for (var i = 0; i < list.length; i++) if (list[i].id === pupitre.id) return !!list[i].udpEnabled
                return false
            }
            onCheckedChanged: if (pupitre) {
                var apiUrl = networkUtils.getApiBaseUrl()
                patchAndApply(
                    apiUrl + "/api/presets/current/outputs",
                    { pupitreId: pupitre.id, changes: { udpEnabled: !!checked } },
                    function() { updateSnapshotOutputs(pupitre.id, { udpEnabled: !!checked }) }
                )
            }
        }
        CheckBox {
            text: "RTP MIDI Enabled"
            checked: {
                var _ = outputsTab.updateTrigger
                if (!outputsTab.currentPresetSnapshot || !outputsTab.currentPresetSnapshot.config || !pupitre) return false
                var list = outputsTab.currentPresetSnapshot.config.pupitres || []
                for (var i = 0; i < list.length; i++) if (list[i].id === pupitre.id) return !!list[i].rtpMidiEnabled
                return false
            }
            onCheckedChanged: if (pupitre) {
                var apiUrl = networkUtils.getApiBaseUrl()
                patchAndApply(
                    apiUrl + "/api/presets/current/outputs",
                    { pupitreId: pupitre.id, changes: { rtpMidiEnabled: !!checked } },
                    function() { updateSnapshotOutputs(pupitre.id, { rtpMidiEnabled: !!checked }) }
                )
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}
