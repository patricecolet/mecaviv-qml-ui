import QtQuick
import "."
import "MicrotonalMath.js" as Mt

/**
 * État partagé des vues microtonales. Rempli par ConductorCueDriver / MIDI / pitch bend — pas d’horloge démo locale.
 */
Item {
    id: root
    width: 0
    height: 0

    MicrotonalTypes { id: types }

    /** modeDirected | modeSequencedStrict */
    property int subMode: 0

    property int phase: 0 // types.phasePartial
    property int harmonicIndex: 5
    property string partialLabel: "H5"
    property real midiAnchor: 69.0
    property string anchorNoteName: "La4"
    property real targetCents: 0
    property real currentCents: 0
    property real voletOpen: 0
    /** Note d'arrivée du glissando (midiFloat). -1 = pas de gliss actif. */
    property real glissTargetMidi: -1
    /** Ouverture volet réelle (ex. vélocité WebSocket /127) — jauge bleue à gauche. */
    property real voletOpenLive: 0
    property int glissSpeed: 0 // types.glissInstant
    property string conductorCue: ""

    property real sequencedAnticipationProgress: 0
    /** Rail jaune : segments dans la fenêtre d’anticipation. Chaque entrée : { leftNorm, widthNorm, heightNorm } (hauteur ∝ volet / vélocité). */
    property var sequencedNoteSegments: []
    property real sequencedNextVoletOpen: 0
    /** Durée note on→off (prochaine consigne), ms — pour le rail jaune. */
    property real sequencedNextNoteDurationMs: 0
    property int sequencedPlayheadTick: -1
    property var cueTextLines: []
    /** Tableau des consignes chargées (lecture/repérage humain). */
    property var cueBookLines: []

    property real sessionTimeMs: 0
    property real beatPeriodMs: 500
    property int currentBeatInBar: 1
    property int beatsPerBar: 4

    /** Réservé (ex. rail démo retiré) — laissé vide pour compat */
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

    function clearCueTextLines() {
        root.cueTextLines = []
        root.conductorCue = ""
    }

    function appendCueTextLine(line) {
        if (line === undefined || line === null || String(line).length === 0)
            return
        var s = String(line)
        var arr = root.cueTextLines ? root.cueTextLines.slice() : []
        arr.push(s)
        if (arr.length > 24)
            arr = arr.slice(-24)
        root.cueTextLines = arr
        root.conductorCue = s
    }

    function setCueBookLines(lines) {
        root.cueBookLines = Array.isArray(lines) ? lines : []
    }

    /** État d’attente avant consigne / transport (tests JSON, synchro réelle). */
    function applyNeutralState() {
        var t = types
        root.phase = t.phasePartial
        root.harmonicIndex = 5
        root.partialLabel = "H5"
        root.midiAnchor = 69.0
        root.targetCents = 0
        root.currentCents = 0
        root.voletOpen = 0
        root.voletOpenLive = 0
        root.glissSpeed = t.glissInstant
        root.sessionTimeMs = 0
    }

    function reset() {
        root.sessionTimeMs = 0
        root.sequencedEvents = []
        root.currentBeatInBar = 1
        root.sequencedAnticipationProgress = 0
        root.sequencedNoteSegments = []
        root.sequencedNextVoletOpen = 0
        root.sequencedNextNoteDurationMs = 0
        root.sequencedPlayheadTick = -1
        root.clearCueTextLines()
        root.applyNeutralState()
    }

    function applyPitchBend14(value14, semitoneRange) {
        root.currentCents = Mt.pitchBendToCents(value14, semitoneRange !== undefined ? semitoneRange : 2)
    }

    Component.onCompleted: applyNeutralState()
}
