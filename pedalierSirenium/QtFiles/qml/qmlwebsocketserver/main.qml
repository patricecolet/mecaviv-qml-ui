import QtQuick
import QtQuick.Window
import QtQuick.Layouts

import "./controllers"
import "./utils"
import "./components/play"
import "./components/config"
import "./components/scenes"

// Refonte 2D — Phase 1 : vue de jeu (horloge, boucle en cours, sept sirènes),
// animée par des données simulées. Le routage du vrai flux PD arrive en Phase 2.
Window {
    id: window
    // Cible de référence : écran Raspberry Pi en kiosque, 1280×800.
    width: 1280
    height: 800
    visible: true
    color: "#0A0D11"
    title: "Pédalier Sirenium"

    // Réglages et journal
    Settings { id: settings }
    Logger { id: logger }

    // Contrôleurs de logique (non couplés 3D) — connexion réelle, pas encore routée
    MidiMonitorController {
        id: midiMonitorController
        logger: logger
    }

    // Canal binaire → LiveState. C'est le chemin rapide : les notes harmonisées
    // arrivent sans passer par le lissage à 40 ms du canal JSON.
    Connections {
        target: midiMonitorController
        function onMidiDataChanged(note, velocity, bend, channel) {
            liveState.applyMidi(note, velocity, bend, channel);
        }
    }
    WebSocketController {
        id: wsController
        logger: logger
        mainWindow: window
        midiMonitorController: midiMonitorController
        onBatchReceived: function(batchType, data) {
            switch (batchType) {
                case "clock": liveState.applyClock(data); break;
                case "loops": liveState.applyLoops(data); break;
                case "scenesList": liveState.applyScenesList(data); break;
                case "sceneLoaded": liveState.applySceneLoaded(data); break;
                case "composition": liveState.applyComposition(data); break;
                case "sirenium": liveState.applySirenium(data); break;
                case "voiceSelect": liveState.applyVoiceSelect(data); break;
                case "outputDevice": liveState.applyOutputDevice(data); break;
                case "clic": liveState.applyClic(data); break;
                default:
                    if (logger) logger.debug("WEBSOCKET", "batch non routé:", batchType);
            }
        }
    }

    // Données simulées, gardées en secours quand PD n'est pas connecté —
    // utile pour le dev/la démo sans backend. `state` est ce que tous les
    // composants d'affichage consomment ; il bascule seul selon la connexion.
    SimulationHarness { id: sim }
    LiveState { id: liveState }
    readonly property var state: wsController.isConnected ? liveState : sim

    // Bascule vue de jeu / configuration (F2 ou bouton dans le bandeau)
    property bool configMode: false
    Shortcut { sequence: "F2"; onActivated: window.configMode = !window.configMode }

    // Gestion des scènes : troisième état du corps, ouvert depuis la carte du
    // morceau. Pas de bouton dédié dans le bandeau — la porte, c'est la carte.
    property bool scenesMode: false

    // Maintenance : la machine, pas l'instrument. Bouton SYS dans le bandeau.
    property bool maintenanceMode: false

    // Le clic ne décide pas de la sortie : il la demande. C'est l'écho de PD
    // qui met le bouton à jour, sinon l'écran mentirait dès que PD refuse.
    function _setOutput(dev) {
        if (wsController.isConnected) wsController.sendOutputDevice(dev);
        else sim.applyOutputDevice(dev);
    }

    // Taper une sirène la choisit, comme la touche piano du pédalier ; retaper
    // celle qui est déjà choisie la désarme. Le doigt n'a pas de relâchement,
    // alors c'est le même geste qui arme et désarme — -1 est la valeur que PD
    // attend pour ça, `pd pedal.play.rec` la route déjà.
    function _pickSiren(n) {
        var v = (window.state.monoSiren === n) ? -1 : n;
        if (wsController.isConnected) wsController.sendVoiceSelect(v);
        else sim.applyVoiceSelect({ siren: v > 0 ? v : 0 });
    }

    // Les éditions partent vers PD quand il est là, et restent locales sinon :
    // sans ça, la page serait inutilisable pour la régler hors connexion.
    // `window.state` porte les deux, comme pour le tempo et la signature.
    function _sceneEdit(op, a, b, c) {
        if (wsController.isConnected) {
            switch (op) {
                case "new":    return wsController.sceneNew();
                case "load":   return wsController.sceneLoad(a);
                case "rename": return wsController.sceneRename(a, b);
                case "delete": return wsController.sceneDelete(a);
                case "copy":   return wsController.sceneCopy(a, b);
                case "cell":   return wsController.sceneCellCopy(a, b, c);
            }
        } else {
            switch (op) {
                case "new":    return sim.simNewScene();
                case "load":   return sim.simLoadScene(a);
                case "rename": return sim.simRenameScene(a, b);
                case "delete": return sim.simDeleteScene(a);
                case "copy":   return sim.simCopyScene(a, b);
                case "cell":   return sim.simCopyCell(a, b, c);
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Bandeau permanent : reste visible dans les deux modes, sinon le bouton
        // de bascule serait inaccessible depuis l'écran de config.
        ClockBar2D {
            Layout.fillWidth: true
            bpm: Math.round(window.state.bpm)
            minBpm: window.state.minBpm
            maxBpm: window.state.maxBpm
            beat: window.state.clockBeat
            bar: window.state.clockBar
            beatsPerBar: window.state.beatsPerBar
            beatGroups: window.state.beatGroups
            signatureNum: window.state.signatureNum
            minSignatureNum: window.state.minSignatureNum
            maxSignatureNum: window.state.maxSignatureNum
            signatureDen: window.state.signatureDen
            configMode: window.configMode
            maintenanceMode: window.maintenanceMode
            onToggleConfig: {
                window.configMode = !window.configMode;
                if (window.configMode) window.maintenanceMode = false;
            }
            onToggleMaintenance: {
                window.maintenanceMode = !window.maintenanceMode;
                if (window.maintenanceMode) { window.configMode = false; window.scenesMode = false; }
            }
            // Éditable partout, y compris en jeu (exception délibérée) : mise à
            // jour locale immédiate + envoi à PD. Format déjà utilisé par
            // l'ancien code pour le tempo ; nouveau message pour la signature.
            // En mode simulé comme en mode live, `state` porte les mêmes
            // mutateurs — PD écrasera avec la valeur confirmée à l'écho.
            onBpmStep: function(delta) {
                window.state.stepBpm(delta);
                wsController.sendTempoChange(Math.round(window.state.bpm));
            }
            onSignatureNumStep: function(delta) {
                window.state.stepSignatureNum(delta);
                wsController.sendSignatureChange(window.state.signatureNum + "/" + window.state.signatureDen);
            }
            transportRunning: window.state.transportRunning
            clicEnabled: window.state.clicEnabled
            onClicToggle: {
                if (wsController.isConnected)
                    wsController.sendClic(!window.state.clicEnabled, window.state.clicVolume);
            }
            onTransportToggle: {
                if (wsController.isConnected) wsController.sendScenePlayStop();
            }
            onSignatureDenCycle: {
                window.state.cycleSignatureDen();
                wsController.sendSignatureChange(window.state.signatureNum + "/" + window.state.signatureDen);
            }
        }

        // Corps : jeu ou config, selon le mode
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                visible: !window.configMode && !window.scenesMode && !window.maintenanceMode

                FocusDial2D {
                    Layout.fillWidth: true
                    Layout.fillHeight: true      // absorbe l'espace disponible, borné
                    Layout.maximumHeight: 260    // au-delà, le centrage interne créerait un vide disproportionné
                    Layout.leftMargin: 32
                    Layout.rightMargin: 32
                    Layout.topMargin: 20
                    Layout.bottomMargin: 12
                    label: window.state.focusState.label || "—"
                    ringColor: window.state.focusState.ringColor || "#66E4F2"
                    progress: window.state.focusState.progress || 0
                    arcOpacity: window.state.focusState.arcOpacity !== undefined ? window.state.focusState.arcOpacity : 1
                    showHalo: window.state.focusState.showHalo || false
                    haloOpacity: window.state.focusState.haloOpacity || 0
                    sub: window.state.focusState.sub || ""
                    ticks: window.state.mainBars
                    statusWord: window.state.focusState.statusWord || ""
                    statusColor: window.state.focusState.statusColor || "#3B4855"
                    statusNote: window.state.focusState.statusNote || ""
                    mBar: window.state.focusState.mBar || "—"
                    mLen: window.state.focusState.mLen || "—"
                    mRatio: window.state.focusState.mRatio || "—"
                    mRev: window.state.focusState.mRev || "—"
                    ladderActive: window.state.focusState.ladderActive || false
                    ladderStops: window.state.focusState.ladderStops || []
                    ladderVerdict: window.state.focusState.ladderVerdict || "—"
                }

                SirenRingRow2D {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    Layout.leftMargin: 32
                    Layout.rightMargin: 32
                    states: window.state.ringStates
                    selectedSiren: window.state.monoSiren
                    midi: window.state.sirenMidi
                    onSirenTapped: function(n) { window._pickSiren(n); }
                }

                // La note du sirenium et ce que l'harmoniseur en fait, sur la
                // même ligne : source à gauche, accord produit à droite.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    Layout.leftMargin: 32
                    Layout.rightMargin: 32
                    Layout.topMargin: 12
                    spacing: 20

                    SireniumMonitor2D {
                        Layout.preferredWidth: 156
                        Layout.fillHeight: true
                        note: window.state.sireniumNote
                        velocity: window.state.sireniumVelocity
                    }

                    Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; Layout.topMargin: 6; Layout.bottomMargin: 6; color: "#171F28" }

                    ChordCartouche2D {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        chordName: window.state.chordName
                        chordSub: window.state.chordSub
                        voicing: window.state.voicing
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 14
                    height: 1
                    color: "#171F28"
                }

                SongMap2D {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 130
                    Layout.leftMargin: 32
                    Layout.rightMargin: 32
                    Layout.topMargin: 16
                    Layout.bottomMargin: 22
                    compName: window.state.compName
                    compButton: window.state.compButton
                    banks: window.state.banks
                    currentBank: window.state.currentBank
                    sections: window.state.sections
                    onOpenRequested: window.scenesMode = true
                }
            }

            // Écran de configuration
            ConfigView2D {
                anchors.fill: parent
                visible: window.configMode && !window.scenesMode && !window.maintenanceMode
            }

            // Page de maintenance
            MaintenanceView2D {
                id: maintenance
                anchors.fill: parent
                visible: window.maintenanceMode
                outputDevice: window.state.outputDevice
                connected: wsController.isConnected
                onOutputRequested: function(dev) { window._setOutput(dev); }
                onReconnectRequested: wsController.reconnect()
                onSirensConnectRequested: {
                    if (wsController.isConnected) wsController.sendSirensConnect();
                }
                onStRequested: function(on) {
                    if (!wsController.isConnected) return;
                    if (wsController.sendSirensST(on)) maintenance.stEnabled = on;
                }
                onResetOnStopRequested: function(on) {
                    if (!wsController.isConnected) return;
                    if (wsController.sendSirensResetOnStop(on)) maintenance.resetOnStop = on;
                }
                clicEnabled: window.state.clicEnabled
                clicVolume: window.state.clicVolume
                onClicVolumeRequested: function(v) {
                    if (wsController.isConnected) wsController.sendClic(window.state.clicEnabled, v);
                }
            }

            // Gestion des scènes
            SceneManager2D {
                anchors.fill: parent
                visible: window.scenesMode
                sections: window.state.sections
                compName: window.state.compName
                onClosed: window.scenesMode = false
                onNewScene: window._sceneEdit("new")
                onLoadScene: function(n) { window._sceneEdit("load", n); }
                onRenameScene: function(n, name) { window._sceneEdit("rename", n, name); }
                onDeleteScene: function(n) { window._sceneEdit("delete", n); }
                onCopyScene: function(src, dst) { window._sceneEdit("copy", src, dst); }
                onCopyCell: function(src, dst, siren) { window._sceneEdit("cell", src, dst, siren); }
            }
        }
    }

    Component.onCompleted: {
        if (logger) logger.info("INIT", "🚀 Pédalier 2D — Phase 1-4 (jeu + config simulés)");
    }
}
