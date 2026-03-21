import QtQuick
import "."
import "MicrotonalMath.js" as Mt

/**
 * État partagé des vues microtonales. Données de démo via applyMockTimeline() / tick démo.
 */
Item {
    id: root
    width: 0
    height: 0

    MicrotonalTypes { id: types }

    /** modeDirected | modeSequencedStrict | modeSequencedContinuous */
    property int subMode: types.modeDirected

    property int phase: types.phasePartial
    property int harmonicIndex: 5
    property string partialLabel: "H5"
    property real midiAnchor: 69.0
    property string anchorNoteName: "La4"
    property real targetCents: 12.0
    property real currentCents: 3.0
    property real voletOpen: 0.35
    property int glissSpeed: types.glissSlow
    property string conductorCue: "Entrée mesure 12 — attaque partielle, puis gliss vers accord"

    property real sessionTimeMs: 0
    property real beatPeriodMs: 500
    property int currentBeatInBar: 1
    property int beatsPerBar: 4

    property var sequencedEvents: []

    readonly property string glissSpeedLabel: {
        switch (glissSpeed) {
        case types.glissInstant: return "instantané"
        case types.glissVeryFast: return "très rapide"
        case types.glissFast: return "rapide"
        case types.glissSlow: return "lent"
        case types.glissVerySlow: return "très lent"
        default: return "—"
        }
    }

    function reset() {
        root.sessionTimeMs = 0
        root.sequencedEvents = []
        root.currentBeatInBar = 1
    }

    function applyMockTimeline() {
        var t = types
        var now = 0
        var ev = []
        var add = function(tMs, beatSlot, label, ph, harm, centsT, centsC, volet, gs) {
            ev.push({
                tMs: tMs,
                beatSlot: beatSlot,
                label: label,
                phase: ph,
                harmonicIndex: harm,
                targetCents: centsT,
                currentCents: centsC,
                volet: volet,
                glissSpeed: gs
            })
        }
        add(0, 1, "Partielle → La tempéré", t.phasePartial, 5, 18, 2, 0.2, t.glissSlow)
        add(500, 2, "Gliss vers grille", t.phasePartial, 5, 8, 5, 0.45, t.glissFast)
        add(1500, 3, "Ancre tempérée", t.phaseTempered, 5, 0, 0, 0.8, t.glissVeryFast)
        add(2500, 4, "Bend plein −", t.phaseFullBend, 5, -95, -80, 0.9, t.glissVerySlow)
        add(4000, 1, "Nouvelle partielle H7", t.phasePartial, 7, 22, 10, 0.15, t.glissSlow)
        root.sequencedEvents = ev
        root.harmonicIndex = 5
        root.phase = t.phasePartial
        root.targetCents = 18
        root.currentCents = 2
        root.voletOpen = 0.2
        root.glissSpeed = t.glissSlow
        root.sessionTimeMs = 0
    }

    function advanceDemoStep() {
        var t = types
        root.phase = (root.phase + 1) % 3
        if (root.phase === t.phasePartial) {
            root.harmonicIndex = root.harmonicIndex === 5 ? 7 : 5
            root.partialLabel = "H" + root.harmonicIndex
            root.targetCents = 15 + Math.random() * 10
            root.currentCents = -5 + Math.random() * 8
        } else if (root.phase === t.phaseTempered) {
            root.targetCents = 0
            root.currentCents = 2
        } else {
            root.targetCents = -90
            root.currentCents = -40
        }
    }

    Timer {
        id: demoTimer
        interval: 80
        running: root._demoPlaying
        repeat: true
        onTriggered: {
            var step = demoTimer.interval
            root.sessionTimeMs += step
            var period = Math.max(200, root.beatPeriodMs)
            var beatFloat = root.sessionTimeMs / period
            root.currentBeatInBar = (Math.floor(beatFloat) % root.beatsPerBar) + 1
            var i = 0
            for (i = 0; i < root.sequencedEvents.length; i++) {
                var e = root.sequencedEvents[i]
                if (root.sessionTimeMs >= e.tMs && root.sessionTimeMs < e.tMs + step * 2) {
                    root.phase = e.phase
                    root.harmonicIndex = e.harmonicIndex
                    root.partialLabel = "H" + e.harmonicIndex
                    root.targetCents = e.targetCents
                    root.currentCents = e.currentCents
                    root.voletOpen = e.volet
                    root.glissSpeed = e.glissSpeed
                    break
                }
            }
            root.currentCents += (root.targetCents - root.currentCents) * 0.04
        }
    }

    property bool _demoPlaying: false

    function startDemoClock() {
        root._demoPlaying = true
    }

    function stopDemoClock() {
        root._demoPlaying = false
    }

    function applyPitchBend14(value14, semitoneRange) {
        root.currentCents = Mt.pitchBendToCents(value14, semitoneRange !== undefined ? semitoneRange : 2)
    }

    Component.onCompleted: applyMockTimeline()
}
