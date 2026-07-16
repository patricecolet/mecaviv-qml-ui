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
            if (logger) logger.debug("WEBSOCKET", "batch reçu (Phase 1, non routé):", batchType);
        }
    }

    // Données simulées (Phase 1)
    SimulationHarness { id: sim }

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
            bpm: Math.round(sim.bpm)
            beat: sim.clockBeat
            bar: sim.clockBar
            beatsPerBar: sim.beatsPerBar
            configMode: window.configMode
            onToggleConfig: window.configMode = !window.configMode
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
                    label: sim.focusState.label || "—"
                    ringColor: sim.focusState.ringColor || "#66E4F2"
                    progress: sim.focusState.progress || 0
                    showHalo: sim.focusState.showHalo || false
                    haloOpacity: sim.focusState.haloOpacity || 0
                    sub: sim.focusState.sub || ""
                    ticks: sim.mainBars
                    statusWord: sim.focusState.statusWord || ""
                    statusColor: sim.focusState.statusColor || "#3B4855"
                    statusNote: sim.focusState.statusNote || ""
                    mBar: sim.focusState.mBar || "—"
                    mLen: sim.focusState.mLen || "—"
                    mRatio: sim.focusState.mRatio || "—"
                    mRev: sim.focusState.mRev || "—"
                    ladderActive: sim.focusState.ladderActive || false
                    ladderStops: sim.focusState.ladderStops || []
                    ladderVerdict: sim.focusState.ladderVerdict || "—"
                }

                SirenRingRow2D {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    Layout.leftMargin: 32
                    Layout.rightMargin: 32
                    states: sim.ringStates
                }

                ChordCartouche2D {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    Layout.leftMargin: 32
                    Layout.rightMargin: 32
                    Layout.topMargin: 12
                    chordName: sim.chordName
                    chordSub: sim.chordSub
                    voicing: sim.voicing
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
                    compName: sim.compName
                    compButton: sim.compButton
                    banks: sim.banks
                    currentBank: sim.currentBank
                    sections: sim.sections
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
