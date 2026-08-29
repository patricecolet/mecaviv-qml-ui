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

    // Sans PD, le clic est la seule vérité disponible : le harnais garde la
    // valeur choisie pour que la page reste utilisable hors connexion.
    property string outputDevice: "v1"
    function applyOutputDevice(dev) { outputDevice = String(dev); }

    property int mainBars: 4
    property int mainLoop: 2          // S3 (index) = boucle de référence
    property int focusIndex: 4        // S5 enregistre (boucle secondaire)

    // --- carte du morceau (statique en Phase 1) ---
    readonly property string compName: "Vertiges"
    readonly property int compButton: 12
    readonly property int banks: 3
    readonly property int currentBank: 1
    // Mutable, contrairement au reste du harnais : la page de gestion des scènes
    // doit pouvoir vivre sans PD, sinon on ne peut pas la régler. Les mêmes six
    // opérations que `pd scene.edit`, avec la même règle de décalage.
    property var sections: _seed()

    function _seed() {
        var raw = [
            ["intro",  ["play","empty","play","empty","empty","empty","oneshot"], ["clip_A",null,"clip_C",null,null,null,"clip_D"]],
            ["montée", ["play","play","play","stop","play","empty","play"],        ["clip_A","clip_B","clip_C","clip_E","clip_F",null,"clip_D"]],
            ["plein",  ["play","play","play","play","play","mute","play"],         ["clip_A","clip_B","clip_C","clip_E","clip_F","clip_G","clip_D"]],
            ["creux",  ["stop","mute","solo","play","stop","empty","stop"],        ["clip_A","clip_B","clip_C","clip_E","clip_F",null,"clip_D"]],
            ["coda",   ["play","stop","empty","empty","mute","play","oneshot"],    ["clip_A","clip_B",null,null,"clip_F","clip_G","clip_H"]]
        ];
        var out = [];
        for (var i = 0; i < raw.length; i++) out.push(_mk(i + 1, raw[i][0], raw[i][1], raw[i][2]));
        out[2].current = true;
        out[0].past = true;
        out[1].past = true;
        return out;
    }

    function _mk(id, name, modes, clips) {
        var cells = [];
        for (var s = 0; s < 7; s++) cells.push({ mode: modes[s], clipRef: clips ? clips[s] : null });
        return { id: id, btn: ((id - 1) % 8) + 1, name: name, modes: modes.slice(),
                 cells: cells, current: false, past: false };
    }

    function _renumber(list) {
        for (var i = 0; i < list.length; i++) { list[i].id = i + 1; list[i].btn = (i % 8) + 1; }
        return list;
    }

    function _at(list, id) {
        for (var i = 0; i < list.length; i++) if (list[i].id === id) return i;
        return -1;
    }

    function simNewScene() {
        var l = sections.slice();
        l.push(_mk(l.length + 1, "nouvelle",
                   ["empty","empty","empty","empty","empty","empty","empty"], null));
        sections = _renumber(l);
    }
    function simRenameScene(id, name) {
        var l = sections.slice(); var i = _at(l, id);
        if (i >= 0) l[i] = Object.assign({}, l[i], { name: name });
        sections = l;
    }
    function simDeleteScene(id) {
        var l = sections.slice(); var i = _at(l, id);
        if (i >= 0) l.splice(i, 1);
        sections = _renumber(l);
    }
    function simCopyScene(src, dst) {
        var l = sections.slice(); var a = _at(l, src), b = _at(l, dst);
        if (a < 0 || b < 0) return;
        var copy = _mk(l[b].id, l[a].name, l[a].modes,
                       l[a].cells.map(function(c) { return c.clipRef; }));
        copy.current = l[b].current;
        l[b] = copy;
        sections = l;
    }
    function simCopyCell(src, dst, siren) {
        var l = sections.slice(); var a = _at(l, src), b = _at(l, dst);
        if (a < 0 || b < 0 || siren < 1 || siren > 7) return;
        var cell = l[a].cells[siren - 1];
        var tgt = Object.assign({}, l[b]);
        tgt.cells = l[b].cells.slice();
        tgt.modes = l[b].modes.slice();
        tgt.cells[siren - 1] = { mode: cell.mode, clipRef: cell.clipRef };
        tgt.modes[siren - 1] = cell.mode;
        l[b] = tgt;
        sections = l;
    }
    function simLoadScene(id) {
        var l = sections.slice();
        var seen = false;
        for (var i = 0; i < l.length; i++) {
            l[i] = Object.assign({}, l[i], { current: l[i].id === id, past: false });
            if (l[i].current) seen = true;
            else if (!seen) l[i].past = true;
        }
        sections = l;
    }

    // --- harmonie de la scène courante (statique en Phase 1/3) ---
    readonly property string chordName: "Do dorien"
    readonly property string chordSub: "poly · 4 voix"
    readonly property var voicing: [        // ordre de hauteur : grave → aigu
        { label: "S3", deg: 0, fund: true },
        { label: "S4", deg: 2 },
        { label: "S1", deg: 4 },
        { label: "S5", deg: 7 }
    ]

    // --- sirenium : note source simulée, pour voir le curseur vivre sans PD ---
    property int sireniumNote: 62
    property int sireniumVelocity: 96

    // --- mono : sirène désignée par la pédale key ou par le doigt ---
    // La scène simulée est poly, donc rien n'est armé au départ — même interface
    // que LiveState pour que main.qml bascule sans changer un binding, y compris
    // `applyVoiceSelect` : sans PD, c'est le tap lui-même qui met la sirène.
    readonly property bool monoMode: false
    property int monoSiren: 0
    property int monoVoice: -1
    readonly property bool monoArmed: monoSiren > 0

    function applyVoiceSelect(data) {
        if (!data) return;
        if (data.siren !== undefined) monoSiren = data.siren;
        if (data.voice !== undefined) monoVoice = data.voice;
    }

    // --- sorties, réévaluées à chaque tick ---
    // Meme interface que LiveState. Sans PD il n'y a pas de transport a suivre :
    // la demonstration tourne, sinon la vue simulee serait figee.
    readonly property bool transportRunning: true

    // Meme interface que LiveState ; sans PD le clic est simplement eteint.
    readonly property bool clicEnabled: false
    readonly property int clicVolume: 100

    property int clockBeat: 0
    property int clockBar: 1
    property var ringStates: []

    // Même interface que LiveState.sirenMidi : ce que joue chaque sirène. Simulé
    // par accord sur la gamme affichée, une attaque par mesure et par sirène.
    property var sirenMidi: [{}, {}, {}, {}, {}, {}, {}]
    property int _lastMidiBar: -1
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

        // Sirenium simulé : une note par mesure dans le mode dorien affiché, et
        // un volet qui respire — de quoi voir le curseur et l'obturateur sans PD.
        var degrees = [50, 62, 64, 67, 81];
        sireniumNote = degrees[Math.floor(_bars) % degrees.length];
        sireniumVelocity = Math.round(64 + 60 * Math.sin(now / 900));

        clockBeat = Math.floor((_bars % 1) * beatsPerBar);
        clockBar = Math.floor(_bars) + 1;

        // MIDI par sirène : une attaque par mesure, pour voir la note et la
        // pulsation vivre sans PD. Les sirènes vides restent muettes.
        var bar = Math.floor(_bars);
        if (bar !== _lastMidiBar) {
            _lastMidiBar = bar;
            var chord = [38, 45, 50, 57, 62, 69, 74];
            var arr = [];
            for (var m = 0; m < 7; m++) {
                var prevM = sirenMidi[m] || {};
                var silent = _scn[m].mode === "empty";
                arr.push({
                    note: chord[(m + bar) % chord.length],
                    velocity: silent ? 0 : (m === mainLoop ? 100 : 80),
                    bend: 8192,
                    attacks: (prevM.attacks || 0) + (silent ? 0 : 1)
                });
            }
            sirenMidi = arr;
        }

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
                e.progress = 1; e.meta = _ratioLabel(s.ratio); e.present = 0.7;
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
            arcOpacity: 1,
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
