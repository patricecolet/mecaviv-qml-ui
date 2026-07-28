import QtQuick
import "../../sirenSpec.js" as SirenSpec

// Harnais de données simulées (Phase 1) : reproduit clock + états de boucles
// au format attendu, pour vérifier visuellement la vue de jeu sans PureData.
// Sera remplacé par le vrai flux WebSocket en Phase 2.
QtObject {
    id: sim

    property real bpm: 108
    property int minBpm: 40
    property int maxBpm: 440
    function stepBpm(delta) {
        bpm = Math.max(minBpm, Math.min(maxBpm, bpm + delta));
    }

    // Signature éditable à l'écran (voir docs/PD_WORK.md §7) — deux réglages
    // indépendants. Le dénominateur donne la VALEUR (4=noire, 8=croche,
    // 16=double-croche) ; le numérateur compte combien de CES unités-là
    // remplissent la mesure — ce n'est PAS le nombre de temps musicaux.
    // 7/8 = 7 croches, pas 7 temps (voir beatGroups plus bas).
    property int signatureNum: 4
    readonly property int minSignatureNum: 1
    readonly property int maxSignatureNum: 21
    property int signatureDen: 4
    readonly property var signatureDenValues: [4, 8, 16]

    function stepSignatureNum(delta) {
        signatureNum = Math.max(minSignatureNum, Math.min(maxSignatureNum, signatureNum + delta));
    }
    function cycleSignatureDen() {
        var i = signatureDenValues.indexOf(signatureDen);
        signatureDen = signatureDenValues[(i + 1) % signatureDenValues.length];
    }

    // Nombre d'unités brutes (croches/doubles/noires selon signatureDen) par
    // mesure — sert au calcul de position (_tick), pas à l'affichage des
    // temps : `beat` ci-dessous reste indexé sur ces unités brutes.
    readonly property int beatsPerBar: signatureNum

    // Les VRAIS temps musicaux, groupés (ex. 7/8 → [2,2,3] : deux temps de
    // 2 croches, un de 3). PD a une horloge musicale classique et fournira
    // ce groupage explicitement (configurable, pas déductible d'une formule
    // unique). En attendant, calcul par défaut ci-dessous — PLACEHOLDER
    // uniquement pour la démo, à remplacer par la valeur envoyée par PD.
    readonly property var beatGroups: _computeDefaultGroups(signatureNum, signatureDen)

    function _computeDefaultGroups(num, den) {
        // Mesures simples : chaque unité est son propre temps (comportement
        // historique, ex. 4/4 → quatre temps d'une noire).
        if (num <= 4) {
            var simple = [];
            for (var i = 0; i < num; i++) simple.push(1);
            return simple;
        }
        // Mesures composées classiques en /8 (6, 9, 12) : groupes de 3 croches.
        if (den === 8 && num % 3 === 0 && num >= 6) {
            var compound = [];
            for (var j = 0; j < num / 3; j++) compound.push(3);
            return compound;
        }
        // Mesures irrégulières : convention usuelle par groupes de 2, le
        // dernier groupe absorbant le reste (souvent 3) — ex. 7/8 → [2,2,3].
        var groups = [];
        var remaining = num;
        while (remaining > 4) { groups.push(2); remaining -= 2; }
        if (remaining > 0) groups.push(remaining);
        return groups;
    }

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

    // --- sirenium : note source simulée, pour voir la jauge vivre sans PD ---
    property int sireniumNote: 62
    property int sireniumVelocity: 96
    property real sireniumBend: 4096

    // --- mono : sirène désignée par la pédale key ---
    // La scène simulée est poly, donc rien n'est armé — même interface que
    // LiveState pour que main.qml bascule sans changer un binding.
    readonly property bool monoMode: false
    readonly property int monoSiren: 0
    readonly property int monoVoice: -1
    readonly property bool monoArmed: monoSiren > 0

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
        // BPM = noires par minute, référence fixe indépendante du dénominateur
        // (convention standard). Une unité (croche/double/noire) dure une
        // fraction de la noire selon signatureDen : croche = moitié d'une
        // noire, double-croche = quart. Vérifié sur l'exemple de Patrice :
        // à 60 BPM, 3/4 dure 3s (3 noires) ET 6/8 dure aussi 3s (6 croches
        // à 0,5s chacune) — même durée, la croche est deux fois plus rapide.
        var quarterMs = 60000 / bpm;
        var unitMs = quarterMs * (4 / signatureDen);
        var barMs = unitMs * beatsPerBar;
        _bars += dt / barMs;

        var pulse = 0.3 + 0.35 * (0.5 + 0.5 * Math.sin(now / 190));

        // Sirenium simulé : une note par mesure dans le mode dorien affiché,
        // avec un vibrato lent — de quoi voir la jauge bouger sans PD.
        var degrees = [62, 64, 65, 67, 69];
        sireniumNote = degrees[Math.floor(_bars) % degrees.length];
        sireniumBend = 4096 + 3600 * Math.sin(now / 420);   // balaie presque toute la course

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
