import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../../../utils" as Utils

Item {
    id: gameModeTab
    
    // Instance de NetworkUtils pour obtenir l'URL de base de l'API
    Utils.NetworkUtils {
        id: networkUtils
    }
    
    property var pupitre: null
    property int currentPupitreIndex: 0
    property int updateTrigger: 0
    property bool isAllMode: false
    property var allPupitres: []
    property var currentPresetSnapshot: null
    
    function forceRefresh() {
        updateTrigger++
    }
    
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
    
    function updateSnapshotGameMode(pupitreId, gameMode) {
        if (!gameModeTab.currentPresetSnapshot || !gameModeTab.currentPresetSnapshot.config) return
        var list = gameModeTab.currentPresetSnapshot.config.pupitres || []
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === pupitreId) {
                list[i].gameMode = gameMode
                break
            }
        }
    }
    
    // Fonctions utilitaires pour le mode "All"
    function areAllGameModesEqual() {
        if (!isAllMode || !allPupitres || allPupitres.length <= 1) return true
        if (!currentPresetSnapshot || !currentPresetSnapshot.config) return true
        var list = currentPresetSnapshot.config.pupitres || []
        if (list.length === 0) return true
        
        var firstValue = list[0].gameMode !== undefined ? list[0].gameMode : false
        for (var i = 1; i < list.length; i++) {
            var val = list[i].gameMode !== undefined ? list[i].gameMode : false
            if (val !== firstValue) {
                return false
            }
        }
        return true
    }
    
    function getFirstGameModeValue() {
        if (!currentPresetSnapshot || !currentPresetSnapshot.config) return false
        var list = currentPresetSnapshot.config.pupitres || []
        if (list.length === 0) return false
        return list[0].gameMode !== undefined ? list[0].gameMode : false
    }
    
    function applyToAllPupitres(gameMode) {
        if (!isAllMode || !allPupitres || allPupitres.length === 0) return
        if (!currentPresetSnapshot || !currentPresetSnapshot.config) return
        
        var list = currentPresetSnapshot.config.pupitres || []
        var appliedCount = 0
        
        for (var i = 0; i < allPupitres.length; i++) {
            var pupitre = allPupitres[i]
            if (!pupitre || !pupitre.id) continue
            
            var pupitreId = pupitre.id
            var found = false
            for (var j = 0; j < list.length; j++) {
                if (list[j].id === pupitreId) {
                    list[j].gameMode = gameMode
                    found = true
                    break
                }
            }
            if (!found) {
                var newEntry = { id: pupitreId, gameMode: gameMode }
                list.push(newEntry)
            }
            
            // Envoyer PATCH pour chaque pupitre
            var apiUrl = networkUtils.getApiBaseUrl()
            patchAndApply(
                apiUrl + "/api/presets/current/game-mode",
                { pupitreId: pupitreId, gameMode: gameMode },
                function() { updateSnapshotGameMode(pupitreId, gameMode) }
            )
            appliedCount++
        }
        
        updateTrigger++
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15
        
        Text {
            text: "Mode Jeu"
            color: "#ffffff"
            font.pixelSize: 18
            font.bold: true
        }
        
        Text {
            text: isAllMode ? "Applique le mode jeu à tous les pupitres" : "Active ou désactive le mode jeu pour ce pupitre"
            color: "#cccccc"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        
        CheckBox {
            text: "Activer le mode jeu"
            Layout.preferredWidth: 200
            
            property bool isGameModeEnabled: {
                var _ = gameModeTab.updateTrigger
                if (gameModeTab.isAllMode) {
                    return gameModeTab.getFirstGameModeValue()
                } else {
                    if (!gameModeTab.currentPresetSnapshot || !gameModeTab.currentPresetSnapshot.config || !pupitre) return false
                    var list = gameModeTab.currentPresetSnapshot.config.pupitres || []
                    for (var i = 0; i < list.length; i++) {
                        if (list[i].id === pupitre.id) {
                            return list[i].gameMode !== undefined ? !!list[i].gameMode : false
                        }
                    }
                    return false
                }
            }
            
            checked: isGameModeEnabled
            
            indicator: Rectangle {
                implicitWidth: 16
                implicitHeight: 16
                x: parent.leftPadding
                y: parent.height / 2 - height / 2
                radius: 2
                border.color: {
                    if (gameModeTab.isAllMode && !gameModeTab.areAllGameModesEqual()) {
                        return parent.checked ? "#ffaa00" : "#cc8800"
                    } else {
                        return parent.checked ? "#4a90e2" : "#666666"
                    }
                }
                color: {
                    if (gameModeTab.isAllMode && !gameModeTab.areAllGameModesEqual()) {
                        return parent.checked ? "#ffaa00" : "#444444"
                    } else {
                        return parent.checked ? "#4a90e2" : "#444444"
                    }
                }
                
                Text {
                    text: "✓"
                    color: "#ffffff"
                    anchors.centerIn: parent
                    visible: parent.parent.checked
                    font.pixelSize: 10
                }
            }
            
            contentItem: Text {
                text: parent.text
                color: "#ffffff"
                leftPadding: parent.indicator.width + parent.spacing
                font.pixelSize: 14
            }
            
            onToggled: {
                if (gameModeTab.isAllMode) {
                    // Mode "All" : appliquer à tous les pupitres
                    gameModeTab.applyToAllPupitres(checked)
                } else {
                    // Mode normal : appliquer au pupitre actuel
                    if (!pupitre) return
                    
                    var pupitreId = pupitre.id || "pupitre" + (gameModeTab.currentPupitreIndex + 1)
                    var apiUrl = networkUtils.getApiBaseUrl()
                    patchAndApply(
                        apiUrl + "/api/presets/current/game-mode",
                        { pupitreId: pupitreId, gameMode: checked },
                        function() { updateSnapshotGameMode(pupitreId, checked) }
                    )
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}



