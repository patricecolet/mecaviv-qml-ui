import QtQuick
import "."

/**
 * Consignes chef d’orchestre :
 * - Mode séquencé : lecture du JSON via /api/midi/conductor-cues + position Pure Data (tick ou mesure).
 * - Mode dirigé : messages WebSocket type CONDUCTOR_CUE (console).
 */
Item {
    id: root
    width: 0
    height: 0

    property var viewModel: null
    property var webSocketController: null
    property var sequencerController: null
    /** Sirène courante : canal MIDI lu sur primarySiren.midiChannel (config) */
    property var configController: null

    property bool useMicrotonalDisplay: false
    property int subMode: 0
    /** Horodatage du clic Play côté UI (ms epoch). */
    property real playRequestedAtMs: 0
    /** Pré-roll UI/transport en ms avant démarrage effectif des consignes. */
    property int transportDelayMs: 0
    /** true tant que l’UI considère le transport actif (stop immédiat côté pupitre). */
    property bool transportRunActive: false

    /** Si 1–16, surcharge le canal ; 0 = sirène courante (config) */
    property int midiChannelFilter: 0

    MicrotonalTypes { id: types }

    readonly property int _effectiveMidiChannel: {
        var _ = configController ? configController.updateCounter : 0
        if (root.midiChannelFilter >= 1 && root.midiChannelFilter <= 16)
            return root.midiChannelFilter
        if (!configController || !configController.primarySiren) {
            return 1
        }
        var s = configController.primarySiren
        if (typeof s.midiChannel === "number" && s.midiChannel >= 1 && s.midiChannel <= 16)
            return Math.floor(s.midiChannel)
        var idn = parseInt(s.id, 10)
        if (!isNaN(idn) && idn >= 1 && idn <= 16)
            return idn
        return 1
    }

    readonly property bool isSequenced: root.subMode === types.modeSequencedStrict
    readonly property bool isDirected: root.subMode === types.modeDirected

    property var _tickCues: []
    property var _barCues: []
    property int _tickNext: 0
    property int _barNext: 0
    property int _lastTick: -1
    property int _lastBar: -1
    property real _lastBeatCmp: -1
    property bool _seenTickTransport: false
    property int _ppq: 480
    property int _lastActiveIdx: -2
    property int _lastActiveBarIdx: -2
    property bool _didLogFirstTick: false
    property bool _tickOffsetLocked: false
    property real _tickOffset: 0
    property bool _barOffsetLocked: false
    property real _barOffsetBeats: 0

    readonly property real _anticipationWindowMs: 5000

    function _resetTransportOffsets() {
        root._tickOffsetLocked = false
        root._tickOffset = 0
        root._barOffsetLocked = false
        root._barOffsetBeats = 0
    }

    function _effectiveTickFromTransport(playing, tick) {
        var runGate = root.transportRunActive || root.playRequestedAtMs <= 0
        if (!playing || !runGate) {
            root._resetTransportOffsets()
            return tick
        }
        var delay = root.transportDelayMs > 0 ? root.transportDelayMs : 0
        if (root.playRequestedAtMs <= 0)
            return tick
        var elapsedMs = Math.max(0, Date.now() - root.playRequestedAtMs)
        var bpm = root._bpm()
        var ppq = root._ppq > 0 ? root._ppq : 480
        var msPerTick = 60000 / (bpm * ppq)
        // Horloge unique avant/après t=0 : vitesse parfaitement continue.
        return (elapsedMs - delay) / msPerTick
    }

    function _effectiveBarBeatFromTransport(playing, bar, beatF, beatsPerBar) {
        var runGate = root.transportRunActive || root.playRequestedAtMs <= 0
        if (!playing || !runGate) {
            root._resetTransportOffsets()
            return { bar: bar, beat: beatF }
        }
        var bpb = (typeof beatsPerBar === "number" && beatsPerBar > 0) ? beatsPerBar : 4
        var delay = root.transportDelayMs > 0 ? root.transportDelayMs : 0
        if (root.playRequestedAtMs <= 0)
            return { bar: bar, beat: beatF }
        var elapsedMs = Math.max(0, Date.now() - root.playRequestedAtMs)
        var bpm = root._bpm()
        var msPerBeat = 60000 / bpm
        var ge = (elapsedMs - delay) / msPerBeat
        var barEff = Math.floor(ge / bpb) + 1
        var beatEff = ge - (barEff - 1) * bpb + 1
        return { bar: barEff, beat: beatEff }
    }

    function _normalizeGliss(v) {
        if (typeof v === "number" && v >= 0 && v <= 4 && Math.floor(v) === v)
            return v
        if (typeof v === "string") {
            var s = v.toLowerCase()
            if (s === "instant") return 0
            if (s === "veryfast" || s === "very_fast") return 1
            if (s === "fast") return 2
            if (s === "slow") return 3
            if (s === "veryslow" || s === "very_slow") return 4
        }
        return 3
    }

    /** Durée note on→off en ms (JSON `durationTicks` / `endTick`). */
    function _cueNoteDurationMs(cue, msPerTick) {
        if (!cue || typeof msPerTick !== "number" || !isFinite(msPerTick) || msPerTick <= 0)
            return 0
        var dtick = 0
        if (cue.durationTicks !== undefined && typeof cue.durationTicks === "number")
            dtick = Math.max(0, cue.durationTicks)
        else if (cue.endTick !== undefined && cue.tick !== undefined
                && typeof cue.endTick === "number" && typeof cue.tick === "number")
            dtick = Math.max(0, cue.endTick - cue.tick)
        return dtick * msPerTick
    }

    function _hzToAnchorCents(hz) {
        if (typeof hz !== "number" || !isFinite(hz) || hz <= 0)
            return { anchor: 69.0, cents: 0.0 }
        var mf = 69.0 + 12.0 * (Math.log(hz / 440.0) / Math.LN2)
        var anchor = Math.floor(mf)
        var cents = (mf - anchor) * 100.0
        return { anchor: anchor, cents: cents }
    }

    /** Pitch / volet / gliss — sans texte (affichage jeu) */
    function applyVisualOnly(vm, data) {
        if (!vm || !data)
            return
        var ma = root._asFiniteNumber(data.midiAnchor)
        var tc = root._asFiniteNumber(data.targetCents)
        var hz = root._asFiniteNumber(data.targetFrequencyHz)
        if (isFinite(ma)) {
            vm.midiAnchor = ma
            if (isFinite(tc))
                vm.targetCents = tc
            else if (isFinite(hz) && hz > 0) {
                var mf = root._midiFromHz(hz)
                vm.targetCents = isFinite(mf) ? (mf - ma) * 100.0 : 0
            } else
                vm.targetCents = 0
        } else if (isFinite(hz) && hz > 0) {
            var ac = root._hzToAnchorCents(hz)
            vm.midiAnchor = ac.anchor
            vm.targetCents = ac.cents
        } else if (isFinite(tc)) {
            vm.targetCents = tc
        }
        if (data.glissSpeed !== undefined)
            vm.glissSpeed = root._normalizeGliss(data.glissSpeed)

        // Note cible du glissando
        var gs2 = root._asFiniteNumber(data.glissSpeed)
        var gtc = root._asFiniteNumber(data.glissTargetCents)
        var gthz = root._asFiniteNumber(data.glissTargetFrequencyHz)
        var centsNow = isFinite(root._asFiniteNumber(data.targetCents)) ? root._asFiniteNumber(data.targetCents) : 0
        var glissDelta = isFinite(gtc) ? Math.abs(gtc - centsNow) : 0
        if (isFinite(gs2) && gs2 > 0 && glissDelta > 3.0) {
            var gtMidi = -1
            if (isFinite(gthz) && gthz > 0) {
                gtMidi = root._midiFromHz(gthz)
            } else if (isFinite(root._asFiniteNumber(data.midiAnchor)) && isFinite(gtc)) {
                gtMidi = root._asFiniteNumber(data.midiAnchor) + gtc / 100.0
            }
            vm.glissTargetMidi = (isFinite(gtMidi) && gtMidi >= 0) ? gtMidi : -1
        } else {
            vm.glissTargetMidi = -1
        }

        if (data.voletOpen !== undefined) {
            var vo = root._asFiniteNumber(data.voletOpen)
            if (isFinite(vo))
                vm.voletOpen = Math.max(0, Math.min(1, vo))
        }
        if (data.phase !== undefined && typeof data.phase === "number")
            vm.phase = data.phase
        if (data.harmonicIndex !== undefined && typeof data.harmonicIndex === "number")
            vm.harmonicIndex = data.harmonicIndex
        if (data.partialLabel !== undefined)
            vm.partialLabel = String(data.partialLabel)
        if (data.currentCents !== undefined) {
            var cc = root._asFiniteNumber(data.currentCents)
            if (isFinite(cc))
                vm.currentCents = cc
        }
    }

    /** Mode dirigé ou rafraîchissement complet : inclut le texte */
    function applyPayload(vm, data) {
        if (!vm || !data)
            return
        var line = root.cueDisplayText(data)
        if (line !== "")
            vm.appendCueTextLine(line)
        applyVisualOnly(vm, data)
    }

    function _cueMatchesChannel(cue) {
        var ch = root._effectiveMidiChannel
        if (cue.sirenTrackIndex === undefined || cue.sirenTrackIndex === null)
            return true
        return cue.sirenTrackIndex === ch
    }

    function _sortBar(a, b) {
        var ba = a.bar
        var bb = b.bar
        if (ba !== bb)
            return ba - bb
        var bta = a.beatInBar !== undefined ? a.beatInBar : 1
        var btb = b.beatInBar !== undefined ? b.beatInBar : 1
        return bta - btb
    }

    function _rewindTickPointer(tick) {
        var i = 0
        for (; i < root._tickCues.length; i++) {
            if (root._tickCues[i].tick > tick)
                break
        }
        root._tickNext = i
    }

    function _rewindBarPointer(bar, beatF) {
        var j = 0
        for (; j < root._barCues.length; j++) {
            var c = root._barCues[j]
            var cb = c.bar
            var cbeat = c.beatInBar !== undefined ? c.beatInBar : 1
            if (bar < cb || (bar === cb && beatF < cbeat))
                break
        }
        root._barNext = j
    }

    function _barBeatAhead(bar, beatF, cue) {
        var cb = cue.bar
        var cbeat = cue.beatInBar !== undefined ? cue.beatInBar : 1
        if (bar > cb)
            return true
        if (bar < cb)
            return false
        return beatF >= cbeat
    }

    function resetSessionState() {
        root._tickNext = 0
        root._barNext = 0
        root._lastTick = -1
        root._lastBar = -1
        root._lastBeatCmp = -1
        root._seenTickTransport = false
        root._didLogFirstTick = false
    }

    function clearBook() {
        root._tickCues = []
        root._barCues = []
        resetSessionState()
        root._lastActiveIdx = -2
        root._lastActiveBarIdx = -2
        if (root.viewModel) {
            root.viewModel.clearCueTextLines()
            root.viewModel.setCueBookLines([])
        }
    }

    /** Nombre JSON fiable (Qt/QML peut exposer des nombres en string selon la chaîne de parse). */
    function _asFiniteNumber(x) {
        if (x === undefined || x === null)
            return NaN
        if (typeof x === "number")
            return isFinite(x) ? x : NaN
        if (typeof x === "string" && x.trim() !== "") {
            var n = Number(x)
            return isFinite(n) ? n : NaN
        }
        return NaN
    }

    function _midiFromHz(hz) {
        if (typeof hz !== "number" || !isFinite(hz) || hz <= 0)
            return NaN
        return 69.0 + 12.0 * (Math.log(hz / 440.0) / Math.LN2)
    }

    function _centsDisplayTrunc(cents) {
        if (typeof cents !== "number" || !isFinite(cents))
            return 0
        if (cents >= 0)
            return Math.floor(cents)
        return Math.ceil(cents)
    }

    function _frenchNoteNameFromMidi(midiFloat) {
        var n = Math.round(midiFloat)
        if (n < 0)
            n = 0
        if (n > 127)
            n = 127
        var names = ["Do", "Do#", "Ré", "Ré#", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "La#", "Si"]
        var pc = n % 12
        var oct = Math.floor(n / 12) - 1
        return names[pc] + oct
    }

    /** Décalage d'affichage (en demi-tons) issu de la config sirène. */
    function _displayOctaveOffsetSemitones() {
        var o = NaN
        if (root.configController && root.configController.primarySiren
                && root.configController.primarySiren.displayOctaveOffset !== undefined) {
            o = root._asFiniteNumber(root.configController.primarySiren.displayOctaveOffset)
        } else if (root.configController && root.configController.currentSirenInfo
                && root.configController.currentSirenInfo.displayOctaveOffset !== undefined) {
            o = root._asFiniteNumber(root.configController.currentSirenInfo.displayOctaveOffset)
        }
        if (!isFinite(o))
            return 0
        return Math.round(o) * 12
    }

    function _displayMidi(midiFloat) {
        if (!isFinite(midiFloat))
            return midiFloat
        return midiFloat + root._displayOctaveOffsetSemitones()
    }

    /** Texte consigne : départ et cible du glissando. */
    function cueDisplayText(c) {
        if (!c)
            return ""
        var ma = root._asFiniteNumber(c.midiAnchor)
        var tcRaw = root._asFiniteNumber(c.targetCents)
        var hzNum = root._asFiniteNumber(c.targetFrequencyHz)

        // Note de départ (anchor + bend au note-on)
        var midiStart = NaN
        if (isFinite(hzNum) && hzNum > 0)
            midiStart = root._midiFromHz(hzNum)
        if (!isFinite(midiStart) && isFinite(ma))
            midiStart = ma + (isFinite(tcRaw) ? tcRaw : 0) / 100.0
        if (!isFinite(midiStart))
            return c.text !== undefined ? String(c.text) : ""

        var gs = root._asFiniteNumber(c.glissSpeed)
        if (!isFinite(gs)) gs = 0

        var centsStart = isFinite(tcRaw) ? tcRaw : (isFinite(ma) ? (midiStart - ma) * 100.0 : 0)
        var midiStartDisplay = root._displayMidi(midiStart)
        var noteFrStart = root._frenchNoteNameFromMidi(midiStartDisplay)
        var nStart = Math.round(midiStartDisplay)
        var ct = root._centsDisplayTrunc(centsStart)
        var ctStr = ct > 0 ? ("+" + ct + "ct") : (ct < 0 ? (String(ct) + "ct") : "0ct")

        var track = (c.sirenTrackName !== undefined && c.sirenTrackName !== null) ? String(c.sirenTrackName) : "?"
        var vel = 127
        if (c.text !== undefined) {
            var m = String(c.text).match(/vel\.(\d+)/)
            if (m) vel = parseInt(m[1], 10)
        }
        var vo = root._asFiniteNumber(c.voletOpen)
        if (!isFinite(vo)) vo = 0

        var glissDeltaCents = Math.abs(root._asFiniteNumber(c.glissTargetCents) - centsStart)
        if (gs > 0 && glissDeltaCents > 3.0) {
            // Glissando : note d'arrivée = bend à la fin de la note
            var gtcRaw = root._asFiniteNumber(c.glissTargetCents)
            var gtHz = root._asFiniteNumber(c.glissTargetFrequencyHz)
            var midiEnd = NaN
            if (isFinite(gtHz) && gtHz > 0)
                midiEnd = root._midiFromHz(gtHz)
            if (!isFinite(midiEnd) && isFinite(ma) && isFinite(gtcRaw))
                midiEnd = ma + gtcRaw / 100.0

            if (isFinite(midiEnd)) {
                var midiEndDisplay = root._displayMidi(midiEnd)
                var noteFrEnd = root._frenchNoteNameFromMidi(midiEndDisplay)
                var nEnd = Math.round(midiEndDisplay)
                var centsEnd = isFinite(gtcRaw) ? gtcRaw
                                                : (isFinite(ma) ? (midiEnd - ma) * 100.0 : 0)
                var ctEnd = root._centsDisplayTrunc(centsEnd)
                var ctEndStr = ctEnd > 0 ? ("+" + ctEnd + "ct") : (ctEnd < 0 ? (String(ctEnd) + "ct") : "0ct")
                var hzStart = (isFinite(hzNum) && hzNum > 0) ? Math.round(hzNum) : 0
                var hzEnd = (isFinite(gtHz) && gtHz > 0) ? Math.round(gtHz) : 0
                return track + " " + noteFrStart + " (n" + nStart + ") " + ctStr
                        + " → " + noteFrEnd + " (n" + nEnd + ") " + ctEndStr
                        + "  vel." + vel + "  " + hzStart + "→" + hzEnd + "hz"
                        + "  gliss:" + gs + "  volet: " + vo.toFixed(1)
            }
        }

        var hz = (isFinite(hzNum) && hzNum > 0) ? Math.round(hzNum) : 0
        return track + " " + noteFrStart + " (n" + nStart + ") " + ctStr + "  vel." + vel
                + "  ->  " + hz + "hz  gliss:" + gs + "  volet: " + vo.toFixed(1)
    }

    /** Affichage humain : mesure, temps, tick (transport toujours en ticks). */
    function _formatCueRowDisplay(c) {
        var measureStr = "—"
        var barN = root._asFiniteNumber(c.bar)
        if (isFinite(barN)) {
            var b = root._asFiniteNumber(c.beatInBar)
            if (!isFinite(b))
                b = 1
            var beatStr = (Math.abs(b - Math.floor(b)) < 1e-4)
                    ? String(Math.floor(b))
                    : b.toFixed(1)
            measureStr = "m" + Math.floor(barN) + "." + beatStr
        }
        var timeStr = "—"
        var tms = root._asFiniteNumber(c.tMs)
        if (isFinite(tms)) {
            var ms = tms
            var totalS = Math.floor(ms / 1000)
            var mm = Math.floor(totalS / 60)
            var s = totalS % 60
            var frac = Math.floor((ms % 1000) / 100)
            timeStr = mm + ":" + (s < 10 ? "0" : "") + s + "." + frac
        }
        var tickN = root._asFiniteNumber(c.tick)
        var tickStr = isFinite(tickN) ? String(tickN) : "—"
        return {
            measure: measureStr,
            time: timeStr,
            tick: tickStr,
            text: root.cueDisplayText(c),
        }
    }

    function _buildCueBookLines(ticks, bars) {
        var lines = []
        var i
        for (i = 0; i < ticks.length; i++)
            lines.push(root._formatCueRowDisplay(ticks[i]))
        for (i = 0; i < bars.length; i++)
            lines.push(root._formatCueRowDisplay(bars[i]))
        return lines
    }

    function _buildCueBookLinesFromTick(tick) {
        var lines = []
        var i
        for (i = 0; i < root._tickCues.length; i++) {
            var t = root._tickCues[i]
            if (t.tick < tick)
                continue
            lines.push(root._formatCueRowDisplay(t))
        }
        return lines
    }

    function _buildCueBookLinesFromBar(bar, beatF) {
        var lines = []
        var pos = root._scoreBarPos(bar, beatF)
        var i
        for (i = 0; i < root._barCues.length; i++) {
            var b = root._barCues[i]
            var bpos = root._scoreBarCue(b)
            if (bpos < pos)
                continue
            lines.push(root._formatCueRowDisplay(b))
        }
        return lines
    }

    function _updateCueBookFromTick(tick) {
        if (!root.viewModel)
            return
        root.viewModel.setCueBookLines(root._buildCueBookLinesFromTick(tick))
    }

    function _updateCueBookFromBar(bar, beatF) {
        if (!root.viewModel)
            return
        root.viewModel.setCueBookLines(root._buildCueBookLinesFromBar(bar, beatF))
    }

    /** Prévisualisation statique (sans Play) : première consigne chargée. */
    function _primeInitialPreview() {
        var vm = root.viewModel
        if (!vm)
            return
        vm.clearCueTextLines()

        if (root._tickCues.length > 0) {
            var c0 = root._tickCues[0]
            root.applyVisualOnly(vm, c0)
            var line0 = root.cueDisplayText(c0)
            if (line0 !== "")
                vm.appendCueTextLine(line0)
            root._lastActiveIdx = 0
            return
        }
        if (root._barCues.length > 0) {
            var b0 = root._barCues[0]
            root.applyVisualOnly(vm, b0)
            var lineB0 = root.cueDisplayText(b0)
            if (lineB0 !== "")
                vm.appendCueTextLine(lineB0)
            root._lastActiveBarIdx = 0
            return
        }
    }

    /** Fin d’événement tick : `endTick` ou `tick+durationTicks`, sinon début de la consigne suivante (pas de trou). */
    function _cueEndTick(i) {
        var c = root._tickCues[i]
        if (c.endTick !== undefined && typeof c.endTick === "number")
            return c.endTick
        if (c.durationTicks !== undefined && typeof c.durationTicks === "number" && c.tick !== undefined)
            return c.tick + c.durationTicks
        if (i + 1 < root._tickCues.length)
            return root._tickCues[i + 1].tick
        return 2147483647
    }

    /**
     * Fin de note pour le rail jaune :
     * 1. `endTick` / `durationTicks` issus de l'export (durée MIDI réelle) — silences respectés.
     * 2. Sinon : une noire (ppq ticks) pour que le rectangle soit visible même sur ancien export.
     *    On ne relie PAS à la note suivante pour éviter de combler les silences.
     */
    function _cueEndTickForRail(i) {
        var c = root._tickCues[i]
        if (!c)
            return -1
        if (c.endTick !== undefined && typeof c.endTick === "number")
            return c.endTick
        if (c.durationTicks !== undefined && typeof c.durationTicks === "number" && c.tick !== undefined)
            return c.tick + Math.max(0, c.durationTicks)
        var ppq = root._ppq > 0 ? root._ppq : 480
        return c.tick + ppq
    }

    /** Note « on » : tick ∈ [début, fin[ */
    function _activeCueIndexAt(tick) {
        var j
        for (j = 0; j < root._tickCues.length; j++) {
            var s = root._tickCues[j].tick
            var e = root._cueEndTick(j)
            if (tick >= s && tick < e)
                return j
        }
        return -1
    }

    /** Entre note off et note suivante : prévisualiser la consigne suivante (symboles), volet fermé. */
    function _gapPreviewIndexAt(tick) {
        var j
        for (j = 0; j < root._tickCues.length - 1; j++) {
            var e = root._cueEndTick(j)
            var sNext = root._tickCues[j + 1].tick
            if (e < sNext && tick >= e && tick < sNext)
                return j + 1
        }
        return -1
    }

    function _cueEndBarScore(i) {
        var c = root._barCues[i]
        if (c.endBar !== undefined && typeof c.endBar === "number") {
            var eb = c.endBeatInBar !== undefined ? c.endBeatInBar : 1
            return root._scoreBarPos(c.endBar, eb)
        }
        if (i + 1 < root._barCues.length)
            return root._scoreBarCue(root._barCues[i + 1])
        return 999999999
    }

    function _activeBarCueIndexAt(bar, beatF) {
        var pos = root._scoreBarPos(bar, beatF)
        var j
        for (j = 0; j < root._barCues.length; j++) {
            var s = root._scoreBarCue(root._barCues[j])
            var e = root._cueEndBarScore(j)
            if (pos >= s && pos < e)
                return j
        }
        return -1
    }

    function _gapPreviewBarIndexAt(bar, beatF) {
        var pos = root._scoreBarPos(bar, beatF)
        var j
        for (j = 0; j < root._barCues.length - 1; j++) {
            var e = root._cueEndBarScore(j)
            var sNext = root._scoreBarCue(root._barCues[j + 1])
            if (e < sNext && pos >= e && pos < sNext)
                return j + 1
        }
        return -1
    }

    function _nextIndexAfterTick(tick) {
        var j
        for (j = 0; j < root._tickCues.length; j++) {
            if (root._tickCues[j].tick > tick)
                return j
        }
        return -1
    }

    function _scoreBarPos(bar, beatF) {
        return bar * 10000 + beatF
    }

    function _scoreBarCue(c) {
        var bt = c.beatInBar !== undefined ? c.beatInBar : 1
        return c.bar * 10000 + bt
    }

    function _nextIndexAfterBar(bar, beatF) {
        var s = root._scoreBarPos(bar, beatF)
        var j
        for (j = 0; j < root._barCues.length; j++) {
            if (root._scoreBarCue(root._barCues[j]) > s)
                return j
        }
        return -1
    }

    function _bpm() {
        var b = root.sequencerController ? root.sequencerController.currentTempoBpm : 120
        if (typeof b !== "number" || !isFinite(b) || b < 1)
            return 120
        return b
    }

    /** 0–1 ouverture volet (vélocité exportée) pour hauteur du segment rail. */
    function _cueVoletOpenNorm(c) {
        if (!c)
            return 0.5
        if (c.voletOpen !== undefined && typeof c.voletOpen === "number")
            return Math.max(0, Math.min(1, c.voletOpen))
        return 0.5
    }

    /**
     * Rail jaune : une note = un segment [on, off] d’après l’export ; les silences restent gris.
     * Intersection avec ]playhead, playhead + w_ms] ; défilement vers la gauche.
     */
    function _updateNoteSegmentsFromTick(vm, tick, msPerTick, w_ms) {
        if (!vm)
            return
        var windowTicks = w_ms / msPerTick
        if (!isFinite(windowTicks) || windowTicks <= 1e-9) {
            vm.sequencedNoteSegments = []
            return
        }
        var winStart = tick
        var winEnd = tick + windowTicks
        var segs = []
        var i
        for (i = 0; i < root._tickCues.length; i++) {
            var c = root._tickCues[i]
            if (c.tick >= winEnd)
                break
            var endT = root._cueEndTickForRail(i)
            if (endT <= c.tick || endT <= winStart)
                continue
            var s = c.tick > winStart ? c.tick : winStart
            var e = endT < winEnd ? endT : winEnd
            if (s >= e)
                continue
            var durTicks = e - s
            var widthNorm = durTicks / windowTicks
            if (widthNorm <= 1e-12)
                continue
            var leftNorm = (s - tick) / windowTicks
            segs.push({
                leftNorm: leftNorm,
                widthNorm: widthNorm,
                heightNorm: root._cueVoletOpenNorm(c)
            })
        }
        vm.sequencedNoteSegments = segs
    }

    function _updateSequencedTickState(playing, tick) {
        var vm = root.viewModel
        if (!vm)
            return
        vm.sequencedPlayheadTick = tick
        var bpm = root._bpm()
        var ppq = root._ppq > 0 ? root._ppq : 480
        var msPerTick = 60000 / (bpm * ppq)

        if (!playing || root._tickCues.length === 0) {
            vm.sequencedAnticipationProgress = 0
            vm.sequencedNextVoletOpen = 0
            vm.sequencedNextNoteDurationMs = 0
            vm.sequencedNoteSegments = []
            return
        }

        var activeIdx = root._activeCueIndexAt(tick)
        var previewIdx = root._gapPreviewIndexAt(tick)
        var nextIdx = root._nextIndexAfterTick(tick)

        if (activeIdx >= 0) {
            root.applyVisualOnly(vm, root._tickCues[activeIdx])
            if (activeIdx !== root._lastActiveIdx) {
                var lineTick = root.cueDisplayText(root._tickCues[activeIdx])
                if (lineTick !== "")
                    vm.appendCueTextLine(lineTick)
            }
            if (activeIdx !== root._lastActiveIdx) {
                var ac = root._tickCues[activeIdx]
                console.log("[ConductorCue] tick", tick, "-> cue", activeIdx,
                            "id:", ac.id, "tickCue:", ac.tick,
                            "anchor:", ac.midiAnchor, "cents:", ac.targetCents,
                            "volet:", ac.voletOpen, "gliss:", ac.glissSpeed)
            }
            root._lastActiveIdx = activeIdx
        } else if (previewIdx >= 0) {
            root.applyVisualOnly(vm, root._tickCues[previewIdx])
            vm.voletOpen = 0
        } else if (root._tickCues.length > 0 && tick < root._tickCues[0].tick) {
            // Playhead avant la 1re note : afficher la cible de la 1re consigne (évite le défaut La4).
            root.applyVisualOnly(vm, root._tickCues[0])
            vm.voletOpen = 0
            root._lastActiveIdx = -1
        } else {
            vm.midiAnchor = 69
            vm.targetCents = 0
            vm.voletOpen = 0
            vm.glissSpeed = types.glissInstant
            vm.glissTargetMidi = -1
            root._lastActiveIdx = -1
        }

        var w = root._anticipationWindowMs
        if (nextIdx >= 0) {
            var nextCue = root._tickCues[nextIdx]
            var ticksUntil = nextCue.tick - tick
            if (ticksUntil < 0)
                ticksUntil = 0
            var msUntil = ticksUntil * msPerTick
            vm.sequencedNextVoletOpen = (nextCue.voletOpen !== undefined && typeof nextCue.voletOpen === "number")
                    ? Math.max(0, Math.min(1, nextCue.voletOpen))
                    : 0.5
            vm.sequencedNextNoteDurationMs = root._cueNoteDurationMs(nextCue, msPerTick)
            if (msUntil >= w)
                vm.sequencedAnticipationProgress = 0
            else
                vm.sequencedAnticipationProgress = 1 - Math.min(1, msUntil / w)
        } else {
            vm.sequencedAnticipationProgress = 0
            vm.sequencedNextVoletOpen = 0
            vm.sequencedNextNoteDurationMs = 0
        }

        root._updateNoteSegmentsFromTick(vm, tick, msPerTick, w)
    }

    function _updateSequencedBarState(playing, bar, beatF) {
        var vm = root.viewModel
        if (!vm)
            return
        var bpm = root._bpm()
        var msPerBeat = 60000 / bpm
        var beatsPerBar = 4

        if (!playing || root._barCues.length === 0) {
            vm.sequencedAnticipationProgress = 0
            vm.sequencedNextVoletOpen = 0
            vm.sequencedNextNoteDurationMs = 0
            vm.sequencedNoteSegments = []
            return
        }

        var activeIdx = root._activeBarCueIndexAt(bar, beatF)
        var previewIdx = root._gapPreviewBarIndexAt(bar, beatF)
        var nextIdx = root._nextIndexAfterBar(bar, beatF)

        if (activeIdx >= 0) {
            root.applyVisualOnly(vm, root._barCues[activeIdx])
            if (activeIdx !== root._lastActiveBarIdx) {
                var lineBar = root.cueDisplayText(root._barCues[activeIdx])
                if (lineBar !== "")
                    vm.appendCueTextLine(lineBar)
            }
            root._lastActiveBarIdx = activeIdx
        } else if (previewIdx >= 0) {
            root.applyVisualOnly(vm, root._barCues[previewIdx])
            vm.voletOpen = 0
        } else if (root._barCues.length > 0) {
            var posNow = root._scoreBarPos(bar, beatF)
            var firstPos = root._scoreBarCue(root._barCues[0])
            if (posNow < firstPos) {
                root.applyVisualOnly(vm, root._barCues[0])
                vm.voletOpen = 0
                root._lastActiveBarIdx = -1
            } else {
                vm.midiAnchor = 69
                vm.targetCents = 0
                vm.voletOpen = 0
                vm.glissSpeed = types.glissInstant
                vm.glissTargetMidi = -1
                root._lastActiveBarIdx = -1
            }
        } else {
            vm.midiAnchor = 69
            vm.targetCents = 0
            vm.voletOpen = 0
            vm.glissSpeed = types.glissInstant
            vm.glissTargetMidi = -1
            root._lastActiveBarIdx = -1
        }

        if (nextIdx >= 0) {
            var nextCue = root._barCues[nextIdx]
            var bnext = nextCue.bar
            var btNext = nextCue.beatInBar !== undefined ? nextCue.beatInBar : 1
            var beatsUntil = (bnext - bar) * beatsPerBar + (btNext - beatF)
            if (beatsUntil < 0)
                beatsUntil = 0
            var msUntil = beatsUntil * msPerBeat
            var w = root._anticipationWindowMs
            vm.sequencedNextVoletOpen = (nextCue.voletOpen !== undefined && typeof nextCue.voletOpen === "number")
                    ? Math.max(0, Math.min(1, nextCue.voletOpen))
                    : 0.5
            var ppqBar = root._ppq > 0 ? root._ppq : 480
            var msPerTickBar = 60000 / (bpm * ppqBar)
            vm.sequencedNextNoteDurationMs = root._cueNoteDurationMs(nextCue, msPerTickBar)
            if (msUntil >= w)
                vm.sequencedAnticipationProgress = 0
            else
                vm.sequencedAnticipationProgress = 1 - Math.min(1, msUntil / w)
        } else {
            vm.sequencedAnticipationProgress = 0
            vm.sequencedNextVoletOpen = 0
            vm.sequencedNextNoteDurationMs = 0
        }

        var wBar = root._anticipationWindowMs
        if (nextIdx >= 0 && vm.sequencedNextNoteDurationMs > 1e-6) {
            var widthNormB = Math.min(1, vm.sequencedNextNoteDurationMs / wBar)
            vm.sequencedNoteSegments = [{
                leftNorm: (1 - vm.sequencedAnticipationProgress) * (1 - widthNormB),
                widthNorm: widthNormB,
                heightNorm: root._cueVoletOpenNorm(nextCue)
            }]
        } else {
            vm.sequencedNoteSegments = []
        }
    }

    function loadConductorJsonForPath(relMidiPath) {
        clearBook()
        if (!relMidiPath || relMidiPath.length === 0)
            return
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            if (xhr.status !== 200) {
                console.warn("[ConductorCue] GET conductor-cues HTTP", xhr.status, relMidiPath)
                return
            }
            try {
                var response = JSON.parse(xhr.responseText)
                var doc = response.document
                if (!doc || !doc.cues || !Array.isArray(doc.cues)) {
                    console.warn("[ConductorCue] réponse invalide (pas de document.cues[])", relMidiPath)
                    return
                }
                if (doc.metadata && typeof doc.metadata.ppq === "number")
                    root._ppq = doc.metadata.ppq
                var ticks = []
                var bars = []
                var i
                for (i = 0; i < doc.cues.length; i++) {
                    var raw = doc.cues[i]
                    if (!root._cueMatchesChannel(raw))
                        continue
                    if (isFinite(root._asFiniteNumber(raw.tick))) {
                        ticks.push(raw)
                    } else if (isFinite(root._asFiniteNumber(raw.bar))) {
                        bars.push(raw)
                    }
                }
                ticks.sort(function(a, b) {
                    return a.tick - b.tick
                })
                bars.sort(function(a, b) {
                    return root._sortBar(a, b)
                })
                root._tickCues = ticks
                root._barCues = bars
                resetSessionState()
                root._lastActiveIdx = -2
                root._lastActiveBarIdx = -2
                if (root.viewModel)
                    root.viewModel.setCueBookLines(root._buildCueBookLines(ticks, bars))
                root._primeInitialPreview()
                console.log("[ConductorCue] chargé:", relMidiPath, "ticks:", ticks.length, "barres:", bars.length, "canal pupitre:", root._effectiveMidiChannel)
            } catch (e) {
                console.warn("[ConductorCue] parse erreur:", e, relMidiPath)
            }
        }
        var q = encodeURIComponent(relMidiPath)
        var apiUrl = "/api/midi/conductor-cues?path=" + q
        var resolved = Qt.resolvedUrl(apiUrl).toString()
        if (resolved.startsWith("file://") || resolved.startsWith("qrc:")) {
            var host = typeof window !== "undefined" ? window.location.host : "localhost:8000"
            apiUrl = "http://" + host + "/api/midi/conductor-cues?path=" + q
        }
        xhr.open("GET", apiUrl)
        xhr.send()
    }

    function processTick(playing, tick) {
        if (!root.useMicrotonalDisplay || !root.isSequenced || !root.viewModel)
            return
        var runGate = root.transportRunActive || root.playRequestedAtMs === 0
        var effectivePlaying = playing && runGate
        var tickEff = root._effectiveTickFromTransport(effectivePlaying, tick)
        if (!effectivePlaying) {
            root._lastTick = tickEff
            root.viewModel.sequencedAnticipationProgress = 0
            root.viewModel.sequencedNextVoletOpen = 0
            root.viewModel.sequencedNextNoteDurationMs = 0
            root.viewModel.sequencedNoteSegments = []
            root._primeInitialPreview()
            root._updateCueBookFromTick(0)
            return
        }
        if (!root._didLogFirstTick) {
            root._didLogFirstTick = true
            var firstTick = root._tickCues.length > 0 ? root._tickCues[0].tick : -1
            var lastTick = root._tickCues.length > 0 ? root._tickCues[root._tickCues.length - 1].tick : -1
            console.log("[ConductorCue] 1er tick transport:", tick, "tickEff:", tickEff,
                        "cues:", root._tickCues.length,
                        "range:", firstTick, "->", lastTick,
                        "subMode:", root.subMode,
                        "microtonal:", root.useMicrotonalDisplay)
        }
        root._seenTickTransport = true
        if (root._lastTick >= 0 && tickEff < root._lastTick) {
            root._rewindTickPointer(tickEff)
            root._lastActiveIdx = -2
            if (root.viewModel)
                root.viewModel.clearCueTextLines()
        }
        root._lastTick = tickEff
        while (root._tickNext < root._tickCues.length) {
            var c = root._tickCues[root._tickNext]
            if (tickEff < c.tick)
                break
            root._tickNext++
        }
        root._updateCueBookFromTick(tickEff)
        root._updateSequencedTickState(effectivePlaying, tickEff)
    }

    function processBarBeat(playing, bar, beatInBar, beatF) {
        if (!root.useMicrotonalDisplay || !root.isSequenced || !root.viewModel)
            return
        var runGate = root.transportRunActive || root.playRequestedAtMs === 0
        var effectivePlaying = playing && runGate
        var bpb = 4
        var adj = root._effectiveBarBeatFromTransport(effectivePlaying, bar, beatF, bpb)
        var barEff = adj.bar
        var beatEff = adj.beat
        if (root._seenTickTransport && root._tickCues.length > 0)
            return
        if (!effectivePlaying) {
            root._lastBar = barEff
            root._lastBeatCmp = beatEff
            root.viewModel.sequencedAnticipationProgress = 0
            root.viewModel.sequencedNextVoletOpen = 0
            root.viewModel.sequencedNextNoteDurationMs = 0
            root.viewModel.sequencedNoteSegments = []
            root._primeInitialPreview()
            root._updateCueBookFromBar(1, 1)
            return
        }
        var cmp = beatEff
        if (root._lastBar >= 0 && (barEff < root._lastBar || (barEff === root._lastBar && cmp < root._lastBeatCmp))) {
            root._rewindBarPointer(barEff, cmp)
            root._lastActiveBarIdx = -2
            if (root.viewModel)
                root.viewModel.clearCueTextLines()
        }
        root._lastBar = barEff
        root._lastBeatCmp = cmp
        while (root._barNext < root._barCues.length) {
            var c = root._barCues[root._barNext]
            if (!root._barBeatAhead(barEff, cmp, c))
                break
            root._barNext++
        }
        root._updateCueBookFromBar(barEff, cmp)
        root._updateSequencedBarState(effectivePlaying, barEff, cmp)
    }

    onPlayRequestedAtMsChanged: root._resetTransportOffsets()
    onTransportRunActiveChanged: {
        if (!root.transportRunActive) {
            root._resetTransportOffsets()
            if (root.viewModel) {
                root.viewModel.sequencedAnticipationProgress = 0
                root.viewModel.sequencedNextVoletOpen = 0
                root.viewModel.sequencedNextNoteDurationMs = 0
                root.viewModel.sequencedNoteSegments = []
                root.viewModel.glissTargetMidi = -1
            }
        }
    }

    Connections {
        target: root.sequencerController
        function onCurrentMidiPathChanged() {
            if (root.sequencerController && root.useMicrotonalDisplay
                    && root.sequencerController.currentMidiPath)
                root.loadConductorJsonForPath(root.sequencerController.currentMidiPath)
            else if (!root.sequencerController || !root.sequencerController.currentMidiPath)
                root.clearBook()
        }
    }

    onUseMicrotonalDisplayChanged: {
        if (root.useMicrotonalDisplay && root.sequencerController
                && root.sequencerController.currentMidiPath)
            root.loadConductorJsonForPath(root.sequencerController.currentMidiPath)
        if (!root.useMicrotonalDisplay)
            root.clearBook()
    }

    onSubModeChanged: {
        if (root.useMicrotonalDisplay && root.sequencerController && root.sequencerController.currentMidiPath)
            root.loadConductorJsonForPath(root.sequencerController.currentMidiPath)
    }

    Connections {
        target: root.webSocketController
        enabled: root.webSocketController !== null

        function onPlaybackTickReceived(playing, tick) {
            root.processTick(playing, tick)
        }

        function onPlaybackPositionReceived(playing, bar, beatInBar, beat) {
            var bf = (typeof beat === "number" && isFinite(beat)) ? beat : beatInBar
            root.processBarBeat(playing, bar, beatInBar, bf)
        }

        function onConductorCueReceived(data) {
            if (!root.useMicrotonalDisplay || !root.isDirected || !root.viewModel)
                return
            if (!data || data.type !== "CONDUCTOR_CUE")
                return
            root.applyPayload(root.viewModel, data)
        }
    }
}
