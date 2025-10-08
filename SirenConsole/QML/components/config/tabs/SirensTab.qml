import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: sirensTab
    
    property var consoleController: null
    property int currentPupitreIndex: 0
    property var pupitre: null
    property int updateTrigger: 0 // Pour forcer la mise à jour
    property bool isAllMode: false // Mode "All" activé
    
        onIsAllModeChanged: {
            // Mode "All" activé/désactivé
        }
    property var allPupitres: [] // Tous les pupitres pour le mode "All"
    property var sireneManager: null // Gestionnaire des sirènes
    property var sirenRouterManager: null // Gestionnaire du Router
    
    onConsoleControllerChanged: {
        // ConsoleController mis à jour
    }
    
    onSireneManagerChanged: {
        // SireneManager mis à jour
    }
    
    onAllPupitresChanged: {
        // Liste des pupitres mise à jour
    }
    
    Component.onCompleted: {
        // SirensTab initialisé
    }
    
    // Fonctions utilitaires pour le mode "All"
    function getSireneConfigForAll(sireneIndex) {
        if (!isAllMode || allPupitres.length === 0) return null
        
        var sireneId = "sirene" + (sireneIndex + 1)
        var configs = []
        
        for (var i = 0; i < allPupitres.length; i++) {
            var pupitre = allPupitres[i]
            if (pupitre && pupitre.sirenes && pupitre.sirenes[sireneId]) {
                configs.push(pupitre.sirenes[sireneId])
            } else {
                configs.push({ ambitusRestricted: false, frettedMode: false })
            }
        }
        
        return configs
    }
    
    function areAllConfigsEqual(sireneIndex, property) {
        var configs = getSireneConfigForAll(sireneIndex)
        if (!configs || configs.length <= 1) return true
        
        var firstValue = configs[0][property]
        for (var i = 1; i < configs.length; i++) {
            if (configs[i][property] !== firstValue) {
                return false
            }
        }
        return true
    }
    
    function getFirstConfigValue(sireneIndex, property) {
        var configs = getSireneConfigForAll(sireneIndex)
        if (!configs || configs.length === 0) return false
        return configs[0][property]
    }
    
    function applyToAllPupitres(sireneIndex, property, value) {
        if (!isAllMode || allPupitres.length === 0) return
        
        var sireneId = "sirene" + (sireneIndex + 1)
        
        for (var i = 0; i < allPupitres.length; i++) {
            var pupitre = allPupitres[i]
            if (!pupitre.sirenes) {
                pupitre.sirenes = {}
            }
            if (!pupitre.sirenes[sireneId]) {
                pupitre.sirenes[sireneId] = {
                    ambitusRestricted: false,
                    frettedMode: false
                }
            }
            pupitre.sirenes[sireneId][property] = value
        }
        
        console.log("🔧 Appliqué à tous les pupitres:", property, "=", value, "pour S" + (sireneIndex + 1))
        updateTrigger++
    }
    
    // Mettre à jour les sirènes d'un autre pupitre
    function updateOtherPupitreSirenes(pupitreId, sireneNumber, add) {
        if (!allPupitres || allPupitres.length === 0) {
            return
        }
        
        
        for (var i = 0; i < allPupitres.length; i++) {
            var pupitre = allPupitres[i]
            
            if (pupitre && (pupitre.id === pupitreId || pupitre.id === "pupitre" + (i + 1))) {
                if (!pupitre.assignedSirenes) {
                    pupitre.assignedSirenes = []
                }
                
                var index = pupitre.assignedSirenes.indexOf(sireneNumber)
                if (add && index === -1) {
                    pupitre.assignedSirenes.push(sireneNumber)
                } else if (!add && index !== -1) {
                    pupitre.assignedSirenes.splice(index, 1)
                }
                
                break
            }
        }
        
        // Forcer la mise à jour de l'interface pour tous les pupitres
        updateTrigger++
    }
    
    // Synchroniser le SireneManager avec les données actuelles des pupitres
    function syncSireneManager() {
        if (!sirensTab.sireneManager || !allPupitres || allPupitres.length === 0) {
            return
        }
        
        // Réinitialiser le SireneManager
        sirensTab.sireneManager.sireneOwnership = {}
        
        // Reconstruire l'ownership basé sur les données des pupitres
        for (var i = 0; i < allPupitres.length; i++) {
            var pupitre = allPupitres[i]
            if (pupitre && pupitre.assignedSirenes) {
                var pupitreId = pupitre.id || "pupitre" + (i + 1)
                for (var j = 0; j < pupitre.assignedSirenes.length; j++) {
                    var sireneId = pupitre.assignedSirenes[j]
                    sirensTab.sireneManager.sireneOwnership[sireneId] = pupitreId
                }
            }
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 15
        

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            ColumnLayout {
                width: parent.width
                spacing: 15
                  
                Repeater {
                    model: 7
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: "#555555"
                        border.color: "#777777"
                        border.width: 1
                        radius: 4
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10
                            
                            // Bouton pour activer/désactiver la sirène
                                Button {
                                    text: "S" + (index + 1)
                                    Layout.preferredWidth: 80
                                    Layout.preferredHeight: 35
                                    enabled: !sirensTab.isAllMode // Désactiver en mode "All"
                                    
                                Component.onCompleted: {
                                    // Bouton siren initialisé
                                }
                                    
                                property bool isEnabled: {
                                    // Utiliser updateTrigger pour forcer la mise à jour
                                    var _ = sirensTab.updateTrigger
                                    var sireneId = index + 1
                                    
                                    // Vérifier si la sirène est assignée au pupitre actuel
                                    if (sirensTab.pupitre && sirensTab.pupitre.assignedSirenes) {
                                        return sirensTab.pupitre.assignedSirenes.indexOf(sireneId) !== -1
                                    }
                                    
                                    return false
                                }
                                
                                background: Rectangle {
                                    color: {
                                        // Utiliser updateTrigger pour forcer la mise à jour
                                        var _ = sirensTab.updateTrigger
                                        
                                        // Mode "All" : bouton grisé
                                        if (sirensTab.isAllMode) {
                                            return "#444444"
                                        }
                                        
                                        // Utiliser l'état isEnabled du bouton
                                        return parent.isEnabled ? "#4a90e2" : "#666666"
                                    }
                                    border.color: {
                                        // Utiliser updateTrigger pour forcer la mise à jour
                                        var _ = sirensTab.updateTrigger
                                        
                                        // Mode "All" : bordure grisée
                                        if (sirensTab.isAllMode) {
                                            return "#666666"
                                        }
                                        
                                        // Utiliser l'état isEnabled du bouton
                                        return parent.isEnabled ? "#5ba0f2" : "#777777"
                                    }
                                    border.width: 1
                                    radius: 4
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    color: "#ffffff"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                
                                onClicked: {
                                    // Empêcher l'action en mode "All"
                                    if (sirensTab.isAllMode) {
                                        return
                                    }
                                    
                                    if (!sirensTab.pupitre) {
                                        return
                                    }
                                    
                                    // Vérifier l'état de la sirène via le Router
                                    var sireneNumber = index + 1
                                    if (sirensTab.sirenRouterManager && sirensTab.sirenRouterManager.connected) {
                                        var sireneState = sirensTab.sirenRouterManager.getSireneState(sireneNumber)
                                        var currentController = sirensTab.sirenRouterManager.getSireneController(sireneNumber)
                                        
                                        console.log(`🔍 État S${sireneNumber}: ${sireneState.status}, Contrôleur: ${currentController}`)
                                        
                                        // Si la sirène est contrôlée par une autre source, avertir l'utilisateur
                                        if (currentController && currentController !== "console") {
                                            console.log(`⚠️ Sirène S${sireneNumber} contrôlée par ${currentController}`)
                                            // On peut continuer ou afficher un avertissement selon les besoins
                                        }
                                    }
                                    
                                    // Synchroniser le SireneManager avant toute opération
                                    syncSireneManager()
                                    
                                    if (!sirensTab.pupitre.assignedSirenes) {
                                        sirensTab.pupitre.assignedSirenes = []
                                    }
                                    
                                    var sireneNumber = index + 1
                                    var sireneIndex = sirensTab.pupitre.assignedSirenes.indexOf(sireneNumber)
                                    var pupitreId = sirensTab.pupitre.id || "pupitre" + (sirensTab.currentPupitreIndex + 1)
                                    
                                    if (sireneIndex === -1) {
                                        // Tenter d'ajouter la sirène
                                        if (sirensTab.sireneManager) {
                                            // Vérifier si la sirène est utilisée par le séquenceur
                                            if (sirensTab.sireneManager.getSireneStatus(sireneNumber) === "sequencer") {
                                                return
                                            }
                                            
                                            // Vérifier si la sirène est assignée à un autre pupitre
                                            var currentOwner = sirensTab.sireneManager.getSireneOwner(sireneNumber)
                                            
                                            if (currentOwner && currentOwner !== pupitreId) {
                                                // Retirer de la liste de l'autre pupitre AVANT de désassigner
                                                updateOtherPupitreSirenes(currentOwner, sireneNumber, false)
                                                // Désassigner de l'autre pupitre
                                                sirensTab.sireneManager.unassignSirene(sireneNumber, currentOwner)
                                            }
                                            
                                            // Assigner au pupitre actuel
                                            if (sirensTab.sireneManager.assignSirene(sireneNumber, pupitreId)) {
                                                sirensTab.pupitre.assignedSirenes.push(sireneNumber)
                                            }
                                        } else {
                                            // Mode sans SireneManager - assignation directe
                                            sirensTab.pupitre.assignedSirenes.push(sireneNumber)
                                        }
                                    } else {
                                        // Retirer la sirène
                                        if (sirensTab.sireneManager) {
                                            sirensTab.sireneManager.unassignSirene(sireneNumber, pupitreId)
                                        }
                                        sirensTab.pupitre.assignedSirenes.splice(sireneIndex, 1)
                                    }
                                    
                                    // Forcer la mise à jour de l'interface
                                    sirensTab.updateTrigger++
                                }
                            }
                            
                            // Switch pour ambitus restreint
                            RowLayout {
                                spacing: 5
                                Layout.preferredWidth: 180
                                
                                Text {
                                    text: "Ambitus:"
                                    color: "#cccccc"
                                    font.pixelSize: 11
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                
                                Switch {
                                    id: ambitusSwitch
                                    implicitWidth: 30
                                    implicitHeight: 16
                                    
                                    property bool isRestricted: {
                                        var _ = sirensTab.updateTrigger
                                        
                                        if (sirensTab.isAllMode) {
                                            // Mode "All" : utiliser la valeur du premier pupitre
                                            return sirensTab.getFirstConfigValue(index, "ambitusRestricted")
                                        } else {
                                            // Mode normal : utiliser le pupitre actuel
                                            if (!sirensTab.pupitre) return false
                                            
                                            var sireneId = "sirene" + (index + 1)
                                            if (!sirensTab.pupitre.sirenes) {
                                                sirensTab.pupitre.sirenes = {}
                                            }
                                            if (!sirensTab.pupitre.sirenes[sireneId]) {
                                                sirensTab.pupitre.sirenes[sireneId] = {
                                                    ambitusRestricted: false,
                                                    frettedMode: false
                                                }
                                            }
                                            
                                            return sirensTab.pupitre.sirenes[sireneId].ambitusRestricted
                                        }
                                    }
                                    
                                    checked: isRestricted
                                    
                                    indicator: Rectangle {
                                        implicitWidth: 30
                                        implicitHeight: 16
                                        radius: 8
                                        color: {
                                            if (sirensTab.isAllMode && !sirensTab.areAllConfigsEqual(index, "ambitusRestricted")) {
                                                // Couleur spéciale quand les valeurs sont différentes
                                                return ambitusSwitch.checked ? "#ffaa00" : "#cc8800"
                                            } else {
                                                // Couleur normale
                                                return ambitusSwitch.checked ? "#4a90e2" : "#666666"
                                            }
                                        }
                                        
                                        Rectangle {
                                            x: ambitusSwitch.checked ? parent.width - width : 0
                                            width: parent.height
                                            height: parent.height
                                            radius: parent.height / 2
                                            color: "#ffffff"
                                        }
                                    }
                                    
                                    onToggled: {
                                        if (sirensTab.isAllMode) {
                                            // Mode "All" : appliquer à tous les pupitres
                                            sirensTab.applyToAllPupitres(index, "ambitusRestricted", checked)
                                        } else {
                                            // Mode normal : appliquer au pupitre actuel
                                            if (!sirensTab.pupitre) return
                                            
                                            var sireneId = "sirene" + (index + 1)
                                            if (!sirensTab.pupitre.sirenes) {
                                                sirensTab.pupitre.sirenes = {}
                                            }
                                            if (!sirensTab.pupitre.sirenes[sireneId]) {
                                                sirensTab.pupitre.sirenes[sireneId] = {
                                                    ambitusRestricted: false,
                                                    frettedMode: false
                                                }
                                            }
                                            
                                            sirensTab.pupitre.sirenes[sireneId].ambitusRestricted = checked
                                            console.log("🔧 Ambitus restreint S" + (index + 1), ":", checked)
                                            
                                            // Forcer la mise à jour de l'interface
                                            sirensTab.updateTrigger++
                                        }
                                    }
                                }
                            }
                            
                            // Checkbox pour mode fretté
                            CheckBox {
                                text: "Fretté"
                                Layout.preferredWidth: 120
                                
                                property bool isFretted: {
                                    var _ = sirensTab.updateTrigger
                                    
                                    if (sirensTab.isAllMode) {
                                        // Mode "All" : utiliser la valeur du premier pupitre
                                        return sirensTab.getFirstConfigValue(index, "frettedMode")
                                    } else {
                                        // Mode normal : utiliser le pupitre actuel
                                        if (!sirensTab.pupitre) return false
                                        
                                        var sireneId = "sirene" + (index + 1)
                                        if (!sirensTab.pupitre.sirenes) {
                                            sirensTab.pupitre.sirenes = {}
                                        }
                                        if (!sirensTab.pupitre.sirenes[sireneId]) {
                                            sirensTab.pupitre.sirenes[sireneId] = {
                                                ambitusRestricted: false,
                                                frettedMode: false
                                            }
                                        }
                                        
                                        return sirensTab.pupitre.sirenes[sireneId].frettedMode
                                    }
                                }
                                
                                checked: isFretted
                                
                                indicator: Rectangle {
                                    implicitWidth: 16
                                    implicitHeight: 16
                                    x: parent.leftPadding
                                    y: parent.height / 2 - height / 2
                                    radius: 2
                                    border.color: {
                                        if (sirensTab.isAllMode && !sirensTab.areAllConfigsEqual(index, "frettedMode")) {
                                            return parent.checked ? "#ffaa00" : "#cc8800"
                                        } else {
                                            return parent.checked ? "#4a90e2" : "#666666"
                                        }
                                    }
                                    color: {
                                        if (sirensTab.isAllMode && !sirensTab.areAllConfigsEqual(index, "frettedMode")) {
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
                                    font.pixelSize: 11
                                }
                                
                                onToggled: {
                                    if (sirensTab.isAllMode) {
                                        // Mode "All" : appliquer à tous les pupitres
                                        sirensTab.applyToAllPupitres(index, "frettedMode", checked)
                                    } else {
                                        // Mode normal : appliquer au pupitre actuel
                                        if (!sirensTab.pupitre) return
                                        
                                        var sireneId = "sirene" + (index + 1)
                                        if (!sirensTab.pupitre.sirenes) {
                                            sirensTab.pupitre.sirenes = {}
                                        }
                                        if (!sirensTab.pupitre.sirenes[sireneId]) {
                                            sirensTab.pupitre.sirenes[sireneId] = {
                                                ambitusRestricted: false,
                                                frettedMode: false
                                            }
                                        }
                                        
                                        sirensTab.pupitre.sirenes[sireneId].frettedMode = checked
                                        console.log("🔧 Mode fretté S" + (index + 1), ":", checked)
                                        
                                        // Forcer la mise à jour de l'interface
                                        sirensTab.updateTrigger++
                                    }
                                }
                            }
                            
                            // Élément invisible pour prendre l'espace restant
                            Item {
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }
}