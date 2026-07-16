import QtQuick
import "../../sirenSpec.js" as SirenSpec

// Harnais de données simulées (Phase 1) : reproduit clock + états de boucles
// au format attendu, pour vérifier visuellement la vue de jeu sans PureData.
// Sera remplacé par le vrai flux WebSocket en Phase 2.
QtObject {
    id: sim

    property real bpm: 108
    property int beatsPerBar: 4
    property int mainBars: 4
    property int mainLoop: 2          // S3 (index) = boucle de référence
    property int focusIndex: 4        // S5 enregistre (boucle secondaire)

    // --- carte du morceau (statique en Phase 1) ---
    readonly property string compName: "Vertiges"
    readonly property int compButton: 12
    readonly property int banks: 3
    readonly property int currentBank: 1
    readonly property var sections: [
        { btn: 1, name: "intro",  modes: ["play","empty","play","empty","empty","empty","oneshot"], past: true },
        { btn: 2, name: "montée", modes: ["play","play","play","stop","play","empty","play"], past: true },
        { btn: 4, name: "plein",  modes: ["play","play","play","play","play","mute","play"], current: true },
        { btn: 5, name: "creux",  modes: ["stop","mute","solo","play","stop","empty","stop"] },
        { btn: 7, name: "coda",   modes: ["play","stop","empty","empty","mute","play","oneshot"] }
    ]

    // --- harmonie de la scène courante (statique en Phase 1/3) ---
    readonly property string chordName: "Do dorien"
    readonly property string chordSub: "poly · 4 voix"
    readonly property var voicing: [        // ordre de hauteur : grave → aigu
        { label: "S3", deg: 0, fund: true },
        { label: "S4", deg: 2 },
        { label: "S1", deg: 4 },
        { label: "S5", deg: 7 }
    ]

    // --- sorties, réévaluées à chaque tick ---
    property int clockBeat: 0
    property int clockBar: 1
    property var ringStates: []
    property var focusState: ({})

    // scénario « session » : source par sirène (index 0..6 = S1..S7)
    readonly property var _scn: [
        { mode: "playing", ratio: 2 },      // S1
        { mode: "empty" },                   // S2
        { mode: "playing", ratio: 1 },      // S3 (réf)
        { mode: "stopped", ratio: 1 },      // S4
        { mode: "recording" },               // S5 (focus)
        { mode: "playing", ratio: 4 },      // S6
        { mode: "empty" }                    // S7
    ]
    readonly property var _ratios: [
        { label: "÷4", mul: 0.25 }, { label: "÷2", mul: 0.5 }, { label: "×1", mul: 1 },
        { label: "×2", mul: 2 }, { label: "×4", mul: 4 }, { label: "×8", mul: 8 }
    ]

    property real _bars: 0
    property real _lastMs: 0

    function _ratioLabel(mul) {
        for (var i = 0; i < _ratios.length; i++) if (_ratios[i].mul === mul) return _ratios[i].label;
        return "×" + mul;
    }

    function _tick() {
        var now = Date.now();
        if (_lastMs === 0) _lastMs = now;
        var dt = Math.min(now - _lastMs, 100);
        _lastMs = now;
        _bars += dt / ((60000 / bpm) * beatsPerBar);

        var pulse = 0.3 + 0.35 * (0.5 + 0.5 * Math.sin(now / 190));

        clockBeat = Math.floor((_bars % 1) * beatsPerBar);
        clockBar = Math.floor(_bars) + 1;

        // --- états des 7 anneaux ---
        var rs = [];
        for (var i = 0; i < 7; i++) {
            var s = _scn[i];
            var e = { progress: 0, halo: false, haloOpacity: 0, meta: "", present: 1 };
            if (s.mode === "empty") {
                e.present = 0.45; e.meta = "—";
            } else if (s.mode === "recording") {
                var p = (i === mainLoop) ? (_bars % 1) : (_bars % mainBars) / mainBars;
                e.progress = p; e.halo = true; e.haloOpacity = pulse * 0.6; e.meta = "";
            } else if (s.mode === "playing") {
                var len = mainBars / s.ratio;
                e.progress = (_bars % len) / len;
                e.meta = (i === mainLoop) ? "REF" : _ratioLabel(s.ratio);
            } else { // stopped
                e.progress = 0; e.meta = _ratioLabel(s.ratio); e.present = 0.7;
            }
            rs.push(e);
        }
        ringStates = rs;

        // --- zone focus : S5 enregistre, bornée par le cycle principal ---
        var f = SirenSpec.SPEC["siren" + (focusIndex + 1)] || {};
        var cyc = (_bars % mainBars) / mainBars;
        var landing = -1;
        var stops = [];
        for (var j = 0; j < _ratios.length; j++) {
            var bars = mainBars * _ratios[j].mul;
            var passed = (_bars >= bars && bars >= 1);
            if (passed) landing = j;
            stops.push({ label: _ratios[j].label, bars: bars < 1 ? 0 : bars, passed: passed, landing: false });
        }
        if (landing >= 0) stops[landing].landing = true;

        focusState = {
            label: f.label || "S5",
            ringColor: f.color || "#F7F177",
            progress: cyc,
            showHalo: true,
            haloOpacity: pulse * 0.5,
            sub: "cycle principal",
            statusWord: "ENREGISTRE",
            statusColor: "#FFFFFF",
            statusNote: "Bornée par S3 — " + mainBars + " mesures.",
            mBar: (Math.floor(_bars) + 1).toString(),
            mLen: landing >= 0 ? (mainBars * _ratios[landing].mul).toString() : "—",
            mRatio: landing >= 0 ? _ratios[landing].label : "—",
            mRev: "—",
            ladderActive: true,
            ladderStops: stops,
            ladderVerdict: landing >= 0 ? ("arrêt maintenant → " + (mainBars * _ratios[landing].mul) + " mesures") : "trop court"
        };
    }

    property Timer _timer: Timer {
        interval: 33; running: true; repeat: true
        onTriggered: sim._tick()
    }
}
