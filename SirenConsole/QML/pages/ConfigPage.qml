import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: configPage
    
    color: "#1a1a1a"
    
    property var consoleController: null
    property int currentPupitreIndex: 0
    property int currentTabIndex: 0
    
    // Déclencher la mise à jour des Loader quand consoleController devient disponible
    onConsoleControllerChanged: {
        if (consoleController) {
            // Forcer la mise à jour du PresetSelector
            if (presetSelectorLoader.item) {
                presetSelectorLoader.item.consoleController = consoleController
                if (consoleController.presetManager) {
                    presetSelectorLoader.item.presetManager = consoleController.presetManager
                }
            }
            
            // Mettre à jour le SireneManager quand il devient disponible
            if (consoleController.sireneManager) {
                if (tabLoader.item && tabLoader.item.hasOwnProperty('sireneManager')) {
                    tabLoader.item.sireneManager = consoleController.sireneManager
                }
            }
            
            // Mettre à jour le SirenRouterManager quand il devient disponible
            if (consoleController.sirenRouterManager) {
                if (tabLoader.item && tabLoader.item.hasOwnProperty('sirenRouterManager')) {
                    tabLoader.item.sirenRouterManager = consoleController.sirenRouterManager
                }
            }
        }
    }
    
    // Mettre à jour les données des tabs quand on change de pupitre
    onCurrentPupitreIndexChanged: {
        updateTabData()
    }
    
    function updateTabData() {
        // Mettre à jour les données du pupitre pour le tab actuel
        if (tabLoader.item) {
            if (tabLoader.item.hasOwnProperty('pupitre')) {
                tabLoader.item.pupitre = configPage.pupitres[configPage.currentPupitreIndex]
            }
            if (tabLoader.item.hasOwnProperty('currentPupitreIndex')) {
                tabLoader.item.currentPupitreIndex = configPage.currentPupitreIndex
            }
            if (tabLoader.item.hasOwnProperty('allPupitres')) {
                tabLoader.item.allPupitres = configPage.pupitres
            }
            if (tabLoader.item.hasOwnProperty('sireneManager') && consoleController && consoleController.sireneManager) {
                tabLoader.item.sireneManager = consoleController.sireneManager
            }
            if (tabLoader.item.hasOwnProperty('sirenRouterManager') && consoleController && consoleController.sirenRouterManager) {
                tabLoader.item.sirenRouterManager = consoleController.sirenRouterManager
            }
        }
    }
    
    // Liste des noms de pupitres
    property var pupitreNames: [
        "P1", "P2", "P3", "P4", 
        "P5", "P6", "P7"
    ]
    
    // Liste des pupitres
    property var pupitres: [
        consoleController ? consoleController.pupitre1 : null,
        consoleController ? consoleController.pupitre2 : null,
        consoleController ? consoleController.pupitre3 : null,
        consoleController ? consoleController.pupitre4 : null,
        consoleController ? consoleController.pupitre5 : null,
        consoleController ? consoleController.pupitre6 : null,
        consoleController ? consoleController.pupitre7 : null
    ]
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15
        
        // Sélecteur de presets
        Loader {
            id: presetSelectorLoader
            source: "../components/config/PresetSelector.qml"
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            
            onLoaded: {
                item.consoleController = configPage.consoleController
                if (configPage.consoleController && configPage.consoleController.presetManager) {
                    item.presetManager = configPage.consoleController.presetManager
                }
            }
        }
        
        // Sélecteur de pupitres
        Loader {
            id: pupitreSelectorLoader
            source: "../components/config/PupitreSelector.qml"
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            
            onLoaded: {
                item.pupitreNames = configPage.pupitreNames
                item.pupitres = configPage.pupitres
                item.currentPupitreIndex = configPage.currentPupitreIndex
                
                item.onPupitreSelected.connect(function(index) {
                    configPage.currentPupitreIndex = index
                })
                
                item.onAllModeToggled.connect(function(enabled) {
                    // Propager le mode "All" au SirensTab
                    if (tabLoader.item && tabLoader.item.hasOwnProperty('isAllMode')) {
                        tabLoader.item.isAllMode = enabled
                        tabLoader.item.allPupitres = configPage.pupitres
                    }
                })
            }
        }
        
        // Panneau de navigation et contenu
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20
            
            // Panneau de navigation à gauche
            Loader {
                source: "../components/config/ConfigNavigationPanel.qml"
                Layout.preferredWidth: 200
                Layout.fillHeight: true
                
                onLoaded: {
                    item.currentTabIndex = configPage.currentTabIndex
                    
                    item.onTabSelected.connect(function(index) {
                        configPage.currentTabIndex = index
                    })
                }
            }
            
            // Contenu principal à droite
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#2a2a2a"
                border.color: "#444444"
                border.width: 1
                radius: 8
                
                Loader {
                    id: tabLoader
                    anchors.fill: parent
                    anchors.margins: 15
                    source: {
                        switch(configPage.currentTabIndex) {
                            case 0: return "../components/config/tabs/SirensTab.qml"
                            case 1: return "../components/config/tabs/ControllersTab.qml"
                            case 2: return "../components/config/tabs/OutputsTab.qml"
                            default: return "../components/config/tabs/SirensTab.qml"
                        }
                    }
                    
                    onLoaded: {
                        
                        if (item.hasOwnProperty('consoleController')) {
                            item.consoleController = configPage.consoleController
                        }
                        if (item.hasOwnProperty('sireneManager') && configPage.consoleController && configPage.consoleController.sireneManager) {
                            item.sireneManager = configPage.consoleController.sireneManager
                        }
                        if (item.hasOwnProperty('allPupitres')) {
                            item.allPupitres = configPage.pupitres
                        }
                        // Délai pour s'assurer que tout est initialisé
                        Qt.callLater(function() {
                            updateTabData() // Mettre à jour les données du pupitre
                        })
                    }
                }
            }
        }
    }
}