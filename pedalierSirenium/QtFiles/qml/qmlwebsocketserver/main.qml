import QtQuick
import QtQuick.Window
import QtQuick.Layouts

import "./controllers"
import "./utils"
import "./components/play"
import "./components/config"

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
            onToggleConfig: window.configMode = !window.configMode
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
                visible: !window.configMode

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
                }
            }

            // Écran de configuration
            ConfigView2D {
                anchors.fill: parent
                visible: window.configMode
            }
        }
    }

    Component.onCompleted: {
        if (logger) logger.info("INIT", "🚀 Pédalier 2D — Phase 1-4 (jeu + config simulés)");
    }
}
