import QtQuick 2.15

Item {
    id: root

    // Références globales injectées depuis Main.qml
    property var configController: null
    property var adminPanel: null
    property var testViewLoader: null   // Loader vers la vue principale (Test2D)

    // Focus UI principal (vue normale) : 0 = ADMIN, 1 = CONTRÔLEURS
    property int mainUiFocusIndex: 0

    // Focus UI dans le panneau Admin (structure uniforme pour tous les onglets)
    // 0 = TabBar (onglets du haut), 1 = switch admin/restricted (toujours présent)
    // Onglet "Sirènes" : 2 = siren select, 3 = note max, 4 = transposition
    // Onglet "Visibilité" : 2 = menu latéral, 3+ = éléments dans la section courante
    property int adminFocusIndex: 0
    readonly property int adminFocusCount: 5  // nombre d'items navigables (peut varier selon l'onglet)

    // Noms des items pour les logs (varie selon l'onglet)
    readonly property var adminFocusNames: ["tabSelect", "modeSwitch", "sirenSelect", "noteMax", "transposition"]

    // -------- Helpers internes --------

    function _getPage() {
        return (testViewLoader && testViewLoader.item) ? testViewLoader.item : null
    }

    function _isControllersPanelVisible() {
        var page = _getPage()
        return page && page.controllersPanelVisible
    }

    function _setControllersPanelVisible(visible) {
        var page = _getPage()
        if (page && page.controllersPanelVisible !== undefined) {
            page.controllersPanelVisible = visible
        }
        if (configController) {
            configController.setValueAtPath(["controllersPanel", "visible"], visible)
        }
    }

    // Trouver l'index de la sirène courante dans le tableau sirens
    function _currentSirenIndex() {
        if (!configController || !configController.config || !configController.config.sirenConfig)
            return -1
        var sirens = configController.config.sirenConfig.sirens
        if (!sirens) return -1
        var currentId = configController.primarySiren ? configController.primarySiren.id : null
        for (var i = 0; i < sirens.length; ++i) {
            if (sirens[i].id === currentId) return i
        }
        return 0
    }

    // -------- API appelée par EncoderController --------

    function handleEncoderStep(delta) {
        // 1) AdminPanel ouvert → modifier l'item en focus
        if (adminPanel && adminPanel.visible) {
            _handleAdminStep(delta)
            return
        }
        
        // 2) Dialogs mode jeu ouverts → navigation dans les dialogs
        var page = _getPage()
        if (page && page.gameAutonomyPanel) {
            var autonomyPanel = page.gameAutonomyPanel
            if (autonomyPanel.songSelectorDialog && autonomyPanel.songSelectorDialog.visible) {
                autonomyPanel.songSelectorDialog.handleEncoderStep(delta)
                return
            }
            if (autonomyPanel.gameOptionsDialog && autonomyPanel.gameOptionsDialog.visible) {
                autonomyPanel.gameOptionsDialog.handleEncoderStep(delta)
                return
            }
        }
        
        // 3) Mode jeu actif → navigation dans les éléments du mode jeu
        if (page && page.gameMode) {
            _handleGameModeStep(delta)
            return
        }

        // 4) Vue normale → naviguer entre ADMIN et CONTRÔLEURS
        _handleMainUiStep(delta)
    }

    function handleEncoderClick() {
        // 1) AdminPanel ouvert → passer à l'item suivant
        if (adminPanel && adminPanel.visible) {
            var currentTab = adminPanel.tabBar ? adminPanel.tabBar.currentIndex : 0
            var maxFocus = _getMaxFocusForTab(currentTab)
            root.adminFocusIndex = (root.adminFocusIndex + 1) % maxFocus
            console.log("[Nav] Admin focus ->", root.adminFocusIndex, "(tab", currentTab + ")")
            return
        }
        
        // 2) Dialogs mode jeu ouverts → navigation dans les dialogs
        var page = _getPage()
        if (page && page.gameAutonomyPanel) {
            var autonomyPanel = page.gameAutonomyPanel
            if (autonomyPanel.songSelectorDialog && autonomyPanel.songSelectorDialog.visible) {
                autonomyPanel.songSelectorDialog.handleEncoderClick()
                return
            }
            if (autonomyPanel.gameOptionsDialog && autonomyPanel.gameOptionsDialog.visible) {
                autonomyPanel.gameOptionsDialog.handleEncoderClick()
                return
            }
        }
        
        // 3) Mode jeu actif → activer l'élément en focus
        if (page && page.gameMode) {
            _handleGameModeClick()
            return
        }

        // 4) Panneau Contrôleurs ouvert → le fermer
        if (_isControllersPanelVisible()) {
            _setControllersPanelVisible(false)
            return
        }

        // 5) Vue normale → activer le bouton en focus
        if (!page) return

        if (root.mainUiFocusIndex === 0) {
            // Ouvrir Admin
            root.adminFocusIndex = 0  // reset au premier item
            if (page.openAdminPanel) page.openAdminPanel()
            // Reset le focus des onglets si nécessaire
            if (adminPanel && adminPanel.visibilitySection) {
                adminPanel.visibilitySection.selectedMenuIndex = 0
            }
            if (adminPanel && adminPanel.advancedSection) {
                adminPanel.advancedSection.selectedMenuIndex = 0
            }
        } else if (root.mainUiFocusIndex === 1) {
            // Ouvrir Contrôleurs
            _setControllersPanelVisible(true)
        }
    }

    function handleEncoderLongPress() {
        // 1) AdminPanel ouvert → le fermer
        if (adminPanel && adminPanel.visible) {
            adminPanel.visible = false
            return
        }
        
        // 2) Dialogs mode jeu ouverts → les fermer
        var page = _getPage()
        if (page && page.gameAutonomyPanel) {
            var autonomyPanel = page.gameAutonomyPanel
            if (autonomyPanel.songSelectorDialog && autonomyPanel.songSelectorDialog.visible) {
                autonomyPanel.songSelectorDialog.close()
                return
            }
            if (autonomyPanel.gameOptionsDialog && autonomyPanel.gameOptionsDialog.visible) {
                autonomyPanel.gameOptionsDialog.close()
                return
            }
        }

        // 3) Panneau Contrôleurs ouvert → le fermer
        if (_isControllersPanelVisible()) {
            _setControllersPanelVisible(false)
            return
        }
    }

    // -------- Navigation Admin : rotation modifie l'item en focus --------

    function _handleAdminStep(delta) {
        var step = Math.max(-3, Math.min(3, delta))
        var currentTab = adminPanel.tabBar ? adminPanel.tabBar.currentIndex : 0
        console.log("[Nav] Admin step", step, "on focus", root.adminFocusIndex, "(tab", currentTab + ")")

        if (currentTab === 0) {
            // Onglet "Sirènes"
            _handleSirensTabStep(step)
        } else if (currentTab === 1) {
            // Onglet "Visibilité"
            _handleVisibilityTabStep(step)
        } else if (currentTab === 2) {
            // Onglet "Avancé"
            _handleAdvancedTabStep(step)
        } else if (currentTab === 3) {
            // Onglet "Sorties"
            _handleOutputsTabStep(step)
        }
    }

    function _handleSirensTabStep(step) {
        switch (root.adminFocusIndex) {
        case 0: // Tab select
            if (!adminPanel.tabBar) return
            var newTab = adminPanel.tabBar.currentIndex + step
            if (newTab < 0) newTab = 0
            if (newTab > 3) newTab = 3
            adminPanel.tabBar.currentIndex = newTab
            break

        case 1: // Switch admin/restricted
            if (!configController) return
            var isAdmin = configController.mode === "admin"
            configController.setMode(isAdmin ? "restricted" : "admin")
            break

        case 2: // Siren select
            _handleSirenSelectionStep(step)
            break

        case 3: // Note max (restrictedMax)
            _handleNoteMaxStep(step)
            break

        case 4: // Transposition (displayOctaveOffset)
            _handleTranspositionStep(step)
            break
        }
    }

    function _handleVisibilityTabStep(step) {
        if (!adminPanel) return

        if (root.adminFocusIndex === 0) {
            // Focus 0 = TabBar (onglets du haut)
            if (!adminPanel.tabBar) return
            var newTab = adminPanel.tabBar.currentIndex + step
            if (newTab < 0) newTab = 0
            if (newTab > 3) newTab = 3
            adminPanel.tabBar.currentIndex = newTab
        } else if (root.adminFocusIndex === 1) {
            // Focus 1 = Switch admin/restricted (toujours présent dans l'en-tête)
            if (!configController) return
            var isAdmin = configController.mode === "admin"
            configController.setMode(isAdmin ? "restricted" : "admin")
        } else if (root.adminFocusIndex === 2) {
            // Focus 2 = Menu latéral (Affichages principaux, Portée musicale, Contrôleurs)
            if (!adminPanel.visibilitySection) return
            var visSection = adminPanel.visibilitySection
            var newIndex = visSection.selectedMenuIndex + step
            if (newIndex < 0) newIndex = 0
            if (newIndex > 2) newIndex = 2
            visSection.selectedMenuIndex = newIndex
        } else {
            // Focus 3+ = Éléments dans la section courante (géré par les sous-composants)
            if (!adminPanel.visibilitySection) return
            var visSection = adminPanel.visibilitySection
            var contentLoader = visSection.contentLoader
            if (contentLoader && contentLoader.item && contentLoader.item.handleEncoderStep) {
                contentLoader.item.handleEncoderStep(step)
            }
        }
    }

    function _handleAdvancedTabStep(step) {
        if (!adminPanel) return

        if (root.adminFocusIndex === 0) {
            // Focus 0 = TabBar (onglets du haut)
            if (!adminPanel.tabBar) return
            var newTab = adminPanel.tabBar.currentIndex + step
            if (newTab < 0) newTab = 0
            if (newTab > 3) newTab = 3
            adminPanel.tabBar.currentIndex = newTab
        } else if (root.adminFocusIndex === 1) {
            // Focus 1 = Switch admin/restricted (toujours présent dans l'en-tête)
            if (!configController) return
            var isAdmin = configController.mode === "admin"
            configController.setMode(isAdmin ? "restricted" : "admin")
        } else if (root.adminFocusIndex === 2) {
            // Focus 2 = Menu latéral (WebSocket, Couleurs, Tailles, Animations)
            if (!adminPanel.advancedSection) return
            var advSection = adminPanel.advancedSection
            var newIndex = advSection.selectedMenuIndex + step
            if (newIndex < 0) newIndex = 0
            if (newIndex > 3) newIndex = 3
            advSection.selectedMenuIndex = newIndex
        } else {
            // Focus 3+ = Éléments dans la section courante (géré par les sous-composants)
            if (!adminPanel.advancedSection) return
            var advSection = adminPanel.advancedSection
            var currentTab = advSection.stackLayout.itemAt(advSection.stackLayout.currentIndex)
            if (currentTab && currentTab.handleEncoderStep) {
                currentTab.handleEncoderStep(step)
            }
        }
    }

    function _handleOutputsTabStep(step) {
        if (!adminPanel) return

        if (root.adminFocusIndex === 0) {
            // Focus 0 = TabBar (onglets du haut)
            if (!adminPanel.tabBar) return
            var newTab = adminPanel.tabBar.currentIndex + step
            if (newTab < 0) newTab = 0
            if (newTab > 3) newTab = 3
            adminPanel.tabBar.currentIndex = newTab
        } else if (root.adminFocusIndex === 1) {
            // Focus 1 = Switch admin/restricted
            if (!configController) return
            var isAdmin = configController.mode === "admin"
            configController.setMode(isAdmin ? "restricted" : "admin")
        } else {
            // Focus 2+ = Éléments dans OutputSection (géré par handleEncoderStep)
            if (!adminPanel.outputSection) return
            if (adminPanel.outputSection.handleEncoderStep) {
                adminPanel.outputSection.handleEncoderStep(step)
            }
        }
    }

    // Retourne le nombre max de focus pour l'onglet donné
    function _getMaxFocusForTab(tabIndex) {
        if (tabIndex === 0) {
            return 5  // Sirènes : 0=TabBar, 1=modeSwitch, 2=sirenSelect, 3=noteMax, 4=transposition
        } else if (tabIndex === 1) {
            // Visibilité : 0=TabBar, 1=modeSwitch, 2=menu latéral, 3+=éléments dans la section courante
            if (!adminPanel || !adminPanel.visibilitySection) return 3
            var visibilitySection = adminPanel.visibilitySection
            var contentLoader = visibilitySection.contentLoader
            if (contentLoader && contentLoader.item && contentLoader.item.focusCount !== undefined) {
                return 3 + contentLoader.item.focusCount  // TabBar + modeSwitch + menu + éléments section
            }
            return 3  // Par défaut, TabBar + modeSwitch + menu
        } else if (tabIndex === 2) {
            // Avancé : 0=TabBar, 1=modeSwitch, 2=menu latéral, 3+=éléments dans la section courante
            if (!adminPanel || !adminPanel.advancedSection) return 3
            var advancedSection = adminPanel.advancedSection
            var currentTab = advancedSection.stackLayout.itemAt(advancedSection.stackLayout.currentIndex)
            if (currentTab && currentTab.focusCount !== undefined) {
                return 3 + currentTab.focusCount  // TabBar + modeSwitch + menu + éléments section
            }
            return 3  // Par défaut, TabBar + modeSwitch + menu
        } else if (tabIndex === 3) {
            // Sorties : 0=TabBar, 1=modeSwitch, 2..11=éléments (focusCount=10)
            if (!adminPanel || !adminPanel.outputSection) return 2
            var outputSection = adminPanel.outputSection
            if (outputSection.focusCount !== undefined) {
                return 2 + outputSection.focusCount  // TabBar + modeSwitch + éléments
            }
            return 2
        }
        return 2  // Autres onglets : TabBar + modeSwitch
    }

    // -------- Navigation mode jeu --------
    
    function _handleGameModeStep(delta) {
        var page = _getPage()
        if (!page) return
        
        var step = Math.max(-3, Math.min(3, delta))
        var newIdx = page.gameModeFocusIndex + step
        if (newIdx < 0) newIdx = page.gameModeFocusCount - 1
        if (newIdx >= page.gameModeFocusCount) newIdx = 0
        page.gameModeFocusIndex = newIdx
        
        // Passer le focus à GameAutonomyPanel pour les boutons
        if (page.gameAutonomyPanel) {
            page.gameAutonomyPanel.gameModeFocusIndex = newIdx
            page.gameAutonomyPanel.gameModeFocusColor = page.gameModeFocusColor
        }
    }
    
    function _handleGameModeClick() {
        var page = _getPage()
        if (!page) return
        
        switch (page.gameModeFocusIndex) {
        case 0: // Options (accompagnement)
            if (page.gameAutonomyPanel && page.gameAutonomyPanel.gameOptionsDialog) {
                page.gameAutonomyPanel.gameOptionsDialog.open()
            }
            break

        case 1: // Play/Stop
            // Simuler un clic sur le bouton Play/Stop
            if (page.webSocketController) {
                var playing = page.rootWindow && page.rootWindow.isGamePlaying
                var newPlaying = !playing
                if (newPlaying) {
                    if (page.rootWindow) {
                        page.rootWindow.userRequestedStop = false
                        page.rootWindow.isGamePlaying = true
                    }
                    // Utiliser sequencerController depuis gameModeOverlay
                    var overlay = page.gameModeOverlay
                    if (overlay) {
                        // Chercher sequencerController dans les enfants
                        for (var i = 0; i < overlay.children.length; i++) {
                            var child = overlay.children[i]
                            if (child && typeof child.startFromZero === "function") {
                                child.startFromZero()
                                break
                            }
                        }
                    }
                    if (page.gameModeItem && typeof page.gameModeItem.startGame === "function")
                        page.gameModeItem.startGame()
                    page.transportDisplayActive = true
                    page.webSocketController.sendBinaryMessage({
                        type: "MIDI_TRANSPORT",
                        action: "play",
                        midiDelayMs: 5000,
                        source: "pupitre"
                    })
                } else {
                    page.transportDisplayActive = false
                    page.webSocketController.sendBinaryMessage({
                        type: "MIDI_TRANSPORT",
                        action: "stop",
                        source: "pupitre"
                    })
                    if (page.rootWindow) {
                        page.rootWindow.userRequestedStop = true
                        page.rootWindow.isGamePlaying = false
                    }
                }
            }
            break
            
        case 2: // Morceaux
            if (page.gameAutonomyPanel && page.gameAutonomyPanel.songSelectorDialog) {
                page.gameAutonomyPanel.loadMidiFilesList()
                page.gameAutonomyPanel.songSelectorDialog.open()
            }
            break
            
        case 3: // Ligne d'anticipation (ou Options en microtonal)
            if (page.useMicrotonalDisplay) {
                if (page.gameOptionsDialog)
                    page.gameOptionsDialog.open()
            } else {
                page.showAnticipationLine = !page.showAnticipationLine
            }
            break
            
        case 4: // Barres de mesure (ou Morceaux en microtonal)
            if (page.useMicrotonalDisplay) {
                if (page.gameAutonomyPanel && page.gameAutonomyPanel.songSelectorDialog) {
                    page.gameAutonomyPanel.loadMidiFilesList()
                    page.gameAutonomyPanel.songSelectorDialog.open()
                }
            } else {
                page.showMeasureBars = !page.showMeasureBars
            }
            break
            
        case 5: // Mode Normal
            if (page.setGameMode2D) {
                page.setGameMode2D(false)
                if (page.webSocketController) {
                    page.webSocketController.sendBinaryMessage({
                        type: "GAME_MODE",
                        enabled: false,
                        source: "pupitre"
                    })
                }
            } else if (page.rootWindow) {
                page.rootWindow.gameMode = false
                if (page.webSocketController) {
                    page.webSocketController.sendBinaryMessage({
                        type: "GAME_MODE",
                        enabled: false,
                        source: "pupitre"
                    })
                }
            }
            break
        }
    }

    // -------- Navigation vue normale --------

    function _handleMainUiStep(delta) {
        var page = _getPage()
        if (!page) return

        var current = page.encoderUiFocusIndex !== undefined ? page.encoderUiFocusIndex : root.mainUiFocusIndex
        var step = Math.max(-3, Math.min(3, delta))
        var newIndex = Math.max(0, Math.min(1, current + step))

        if (newIndex !== current) {
            root.mainUiFocusIndex = newIndex
            if (page.encoderUiFocusIndex !== undefined)
                page.encoderUiFocusIndex = newIndex
        }
    }

    // -------- Implémentations internes --------

    function _handleSirenSelectionStep(step) {
        if (!configController || !configController.config || !configController.config.sirenConfig) return
        var sirens = configController.config.sirenConfig.sirens
        if (!sirens || sirens.length === 0) return

        var idx = _currentSirenIndex()
        var newIdx = Math.max(0, Math.min(sirens.length - 1, idx + step))
        if (newIdx !== idx) {
            configController.setValueAtPath(["sirenConfig", "currentSirens"], [sirens[newIdx].id])
        }
    }

    function _handleNoteMaxStep(step) {
        if (!configController || !configController.primarySiren) return
        var siren = configController.primarySiren
        var current = siren.restrictedMax || 72
        var newVal = current + step
        // Clamp dans l'ambitus de la sirène
        if (newVal < siren.ambitus.min) newVal = siren.ambitus.min
        if (newVal > siren.ambitus.max) newVal = siren.ambitus.max
        if (newVal !== current) {
            configController.setRestrictedMax(newVal)
        }
    }

    function _handleTranspositionStep(step) {
        if (!configController || !configController.primarySiren) return
        var siren = configController.primarySiren
        var current = siren.displayOctaveOffset || 0
        var newVal = current + step
        // Clamp -4 à +4
        if (newVal < -4) newVal = -4
        if (newVal > 4) newVal = 4
        if (newVal !== current) {
            var idx = _currentSirenIndex()
            if (idx >= 0) {
                configController.setValueAtPath(["sirenConfig", "sirens", idx, "displayOctaveOffset"], newVal)
            }
        }
    }
}
