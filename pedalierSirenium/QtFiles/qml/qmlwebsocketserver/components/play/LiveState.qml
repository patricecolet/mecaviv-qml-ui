import QtQuick
import "../../sirenSpec.js" as SirenSpec

// État réel, alimenté par le vrai flux WebSocket (voir docs/PD_WORK.md).
// Même interface de sortie que SimulationHarness.qml — main.qml bascule de
// l'un à l'autre sans changer un seul binding de composant.
//
// PD pousse des événements discrets (clock, loops, scènes) ; entre deux
// messages, on interpole localement à 30 fps pour une animation fluide des
// anneaux — même mécanique que SimulationHarness._tick, mais la source de
// vérité (bpm, transport, source par sirène...) vient de PD, pas d'un
// scénario scripté.
QtObject {
    id: live

    // ---------- horloge ----------
    property real bpm: 120
    readonly property int minBpm: 40
    readonly property int maxBpm: 440

    property int signatureNum: 4
    readonly property int minSignatureNum: 1
    readonly property int maxSignatureNum: 21
    property int signatureDen: 4
    readonly property var signatureDenValues: [4, 8, 16]

    readonly property int beatsPerBar: signatureNum
    // Groupage des vrais temps : fourni par PD (clock.groups) ; à défaut,
    // même calcul de secours que SimulationHarness (voir PD_WORK.md §7).
    property var beatGroups: [1, 1, 1, 1]

    // Mutateurs locaux — même signature que SimulationHarness pour que
    // main.qml appelle `state.stepBpm(...)` sans savoir laquelle est active.
    // Retour tactile immédiat ; PD écrase avec la valeur confirmée au
    // prochain `applyClock` (voir PD_WORK.md §7 — PD doit échoïser).
    function stepBpm(delta) {
        bpm = Math.max(minBpm, Math.min(maxBpm, bpm + delta));
    }
    function stepSignatureNum(delta) {
        signatureNum = Math.max(minSignatureNum, Math.min(maxSignatureNum, signatureNum + delta));
    }
    function cycleSignatureDen() {
        var i = signatureDenValues.indexOf(signatureDen);
        signatureDen = signatureDenValues[(i + 1) % signatureDenValues.length];
    }

    // ---------- boucles ----------
    property int mainBars: 4
    property int mainLoopSiren: -1     // siren_id (1-based) de la boucle de référence, -1 = aucune

    // ---------- composition / carte du morceau ----------
    property string compName: "—"
    property int compButton: 0
    property int banks: 1
    property int currentBank: 1
    property bool dirty: false
    property var sections: []          // construit depuis scenesList + sceneLoaded

    // ---------- harmonie de la scène active ----------
    property string chordName: "—"
    property var voicing: []

    // La scène dit poly ou mono ; en mono, c'est la pédale key qui désigne la
    // sirène — le sous-titre suit donc l'état réel, pas seulement la scène.
    property string _scenePolyphony: "poly"
    property int _sceneVoiceCount: 0
    readonly property bool monoMode: _scenePolyphony === "mono"
    readonly property string chordSub: _scenePolyphony === "mono"
        ? (monoArmed ? "mono · " + ((SirenSpec.SPEC["siren" + monoSiren] || {}).label || ("S" + monoSiren))
                     : "mono · désarmé")
        : "poly" + (_sceneVoiceCount ? " · " + _sceneVoiceCount + " voix" : "")

    // ---------- sirenium : la note source, avant harmonisation ----------
    // Alimenté par PD depuis $0.harmoniseur.in. La note place le curseur sur
    // l'ambitus, la vélocité ouvre le volet obturateur (voir SireniumMonitor2D).
    property int sireniumNote: 0
    property int sireniumVelocity: 0

    function applySirenium(data) {
        if (data.note !== undefined) sireniumNote = data.note;
        if (data.velocity !== undefined) sireniumVelocity = data.velocity;
    }

    // ---------- MIDI par sirène : ce que chacune joue, après harmonisation ----------
    // Alimenté par le canal BINAIRE, pas par le JSON. PD pousse les notes
    // harmonisées sur l'inlet `binary` de websocket-server, qui ne traverse pas son
    // spigot de 30 ms : ce flux est immédiat là où le JSON est lissé à 40 ms.
    // Canal 0 → S1 … canal 6 → S7, déjà aligné sur sirenSpec (aucun décalage).
    // Vélocité 1 = note fantôme (moteur en rotation, muet), comme pour le sirenium.
    property var sirenMidi: [{}, {}, {}, {}, {}, {}, {}]

    function applyMidi(note, velocity, bend, channel) {
        if (channel < 0 || channel > 6) return;
        var arr = sirenMidi.slice();
        var prev = arr[channel] || {};
        arr[channel] = {
            note: note,
            velocity: velocity,
            bend: bend,
            // Compteur d'attaques plutôt qu'un signal : la vue le regarde pour
            // pulser, et deux notes de suite à la même hauteur se voient quand même.
            // Toute note compte, vélocité 1 comprise : une fantôme est un événement
            // de jeu comme un autre, elle ne doit pas être filtrée ici.
            attacks: (prev.attacks || 0) + (velocity > 0 ? 1 : 0)
        };
        sirenMidi = arr;
    }

    // ---------- mono : la sirène choisie par la pédale key ----------
    // Alimenté par PD depuis $0.loop.voice.select. siren 0 / voix -1 = mono
    // désarmé : aucune sirène ne reçoit la note du sirenium.
    property int monoSiren: 0
    property int monoVoice: -1
    readonly property bool monoArmed: monoSiren > 0

    function applyVoiceSelect(data) {
        if (!data) return;
        if (data.siren !== undefined) monoSiren = data.siren;
        if (data.voice !== undefined) monoVoice = data.voice;
    }

    // ---------- maintenance : la sortie des sirènes ----------
    // PD la persiste dans `.sortie` et la renvoie en écho ; ici on ne fait que
    // refléter ce qu'il annonce, jamais ce qu'on a cliqué.
    property string outputDevice: "v1"

    function applyOutputDevice(data) {
        if (data === undefined || data === null) return;
        outputDevice = String(data);
    }

    // ---------- sorties temps réel (recalculées à chaque tick) ----------
    // Transport annonce par PD : `start`/`continue` = en marche, `stop` = arrete.
    // Sans lui, l'accumulateur local ci-dessous continuait de compter les temps
    // pendant que PD etait a l'arret — l'ecran affichait un metronome qui tourne
    // alors que rien ne sonnait.
    property string transport: "stop"
    readonly property bool transportRunning: transport !== "stop"

    // Clic audible, tenu par PD et persiste dans son config.json. L'ecran
    // demande, PD applique et renvoie l'echo — comme pour la sortie des sirenes.
    property bool clicEnabled: false
    property int clicVolume: 100

    function applyClic(data) {
        if (!data) return;
        if (data.enable !== undefined) clicEnabled = data.enable > 0;
        if (data.volume !== undefined) clicVolume = data.volume;
    }

    property int clockBeat: 0
    property int clockBar: 1
    property var ringStates: []
    property var focusState: ({})

    readonly property var _ratios: [
        { label: "÷4", mul: 0.25 }, { label: "÷2", mul: 0.5 }, { label: "×1", mul: 1 },
        { label: "×2", mul: 2 }, { label: "×4", mul: 4 }, { label: "×8", mul: 8 }
    ]
    function _ratioLabel(mul) {
        for (var i = 0; i < _ratios.length; i++)
            if (Math.abs(_ratios[i].mul - mul) < 1e-6) return _ratios[i].label;
        // Un rapport non canonique tombe d'une division réelle (5 mesures / 3) :
        // sans arrondi il s'affiche avec quatorze décimales.
        return "×" + (Math.round(mul * 100) / 100);
    }
    // Sous l'anneau, un rapport bâtard ne dit rien à personne ; la longueur, si.
    function _lenLabel(mul, bars) {
        for (var i = 0; i < _ratios.length; i++)
            if (Math.abs(_ratios[i].mul - mul) < 1e-6) return _ratios[i].label;
        return bars > 0 ? bars + " mes." : _ratioLabel(mul);
    }

    // Ordre de hauteur fixe, grave → aigu (voir mémoire siren-pitch-order) —
    // l'étiquette S1..S7 est historique, pas musicale.
    readonly property var _pitchOrder: ["S3", "S4", "S1", "S2", "S5", "S6", "S7"]
    readonly property var _rootToSolfege: ({
        "C": "Do", "D": "Ré", "E": "Mi", "F": "Fa", "G": "Sol", "A": "La", "B": "Si"
    })

    // ---------- état brut reçu de PD, par sirène (1..7) ----------
    // { source, transport, current_bar, loopSize, ratio, revolutions, degree }
    property var _loopStates: ({})

    // ================= entrées : PD → LiveState =================

    function applyClock(data) {
        if (!data) return;
        if (data.bpm !== undefined) bpm = data.bpm;
        if (data.signature !== undefined) {
            var parts = String(data.signature).split("/");
            if (parts.length === 2) {
                signatureNum = parseInt(parts[0], 10) || signatureNum;
                signatureDen = parseInt(parts[1], 10) || signatureDen;
            }
        }
        if (data.groups !== undefined && Array.isArray(data.groups) && data.groups.length > 0) {
            beatGroups = data.groups;
        }
        // `beat`/`bar` bruts de PD resynchronisent l'accumulateur local ;
        // entre deux messages, _tick() continue d'interpoler depuis là.
        if (data.transport !== undefined) transport = String(data.transport);
        if (data.beat !== undefined) clockBeat = data.beat;
        if (data.bar !== undefined) clockBar = data.bar;
        _bars = (clockBar - 1) + (clockBeat / Math.max(beatsPerBar, 1));
    }

    function applyLoops(data) {
        if (!data) return;
        if (data.main_loop !== undefined) mainLoopSiren = data.main_loop;
        if (Array.isArray(data.states)) {
            var map = {};
            for (var i = 0; i < data.states.length; i++) {
                var s = data.states[i];
                if (s.siren_id !== undefined) map[s.siren_id] = s;
            }
            _loopStates = map;
            // La longueur de la boucle de référence fixe l'échelle des paliers.
            if (mainLoopSiren > 0 && map[mainLoopSiren] && map[mainLoopSiren].loopSize) {
                mainBars = map[mainLoopSiren].loopSize;
            }
        }
    }

    function applyComposition(data) {
        if (!data) return;
        if (data.name !== undefined) compName = data.name;
        if (data.id !== undefined) compButton = data.id;
        if (data.banks !== undefined) banks = data.banks;
        if (data.dirty !== undefined) dirty = data.dirty;
    }

    property var _scenesRaw: []
    property int _activeSceneId: -1

    function applyScenesList(scenes) {
        if (!Array.isArray(scenes)) return;
        _scenesRaw = scenes;
        _rebuildSections();
    }

    function applySceneLoaded(data) {
        if (!data) return;
        _activeSceneId = data.sceneId || data.id || data.globalSceneId || -1;
        if (data.page !== undefined) currentBank = data.page;
        // La scène porte sa sirène principale : charger une scène la change sans
        // qu'on touche à la pédale key, donc sans VOICE_SELECT (0 = aucune).
        if (data.siren !== undefined) monoSiren = data.siren;
        _rebuildSections();
        _applyHarmonyFromActiveScene();
    }

    function _rebuildSections() {
        var out = [];
        var seenCurrent = false;
        for (var i = 0; i < _scenesRaw.length; i++) {
            var sc = _scenesRaw[i];
            var id = sc.globalSceneId || sc.sceneId || sc.id;
            var isCurrent = (id === _activeSceneId);
            if (isCurrent) seenCurrent = true;
            var modes = ["empty","empty","empty","empty","empty","empty","empty"];
            var cells = [];
            for (var k = 0; k < 7; k++) cells.push({ mode: "empty", clipRef: null });
            if (Array.isArray(sc.sirens)) {
                for (var j = 0; j < sc.sirens.length; j++) {
                    var se = sc.sirens[j];
                    var idx = (se.siren || 0) - 1;
                    if (idx >= 0 && idx < 7) {
                        modes[idx] = se.mode || "empty";
                        cells[idx] = { mode: modes[idx], clipRef: se.clipRef || null };
                    }
                }
            }
            out.push({
                id: id,
                btn: sc.sceneId || sc.page && ((id - 1) % 8) + 1 || (i % 8) + 1,
                name: sc.sceneName || sc.name || "",
                modes: modes,
                cells: cells,
                current: isCurrent,
                past: !isCurrent && !seenCurrent
            });
        }
        sections = out;
    }

    function _applyHarmonyFromActiveScene() {
        for (var i = 0; i < _scenesRaw.length; i++) {
            var sc = _scenesRaw[i];
            var id = sc.globalSceneId || sc.sceneId || sc.id;
            if (id !== _activeSceneId || !sc.harmony) continue;
            var h = sc.harmony;
            var rootFr = _rootToSolfege[h.root] || h.root || "";
            chordName = (rootFr + " " + (h.scaleMode || "")).trim() || "—";
            _scenePolyphony = h.polyphony || "poly";
            _sceneVoiceCount = Array.isArray(h.voicing) ? h.voicing.length : 0;
            voicing = _sortVoicingByPitch(h.voicing || []);
            return;
        }
    }

    function _sortVoicingByPitch(raw) {
        var bySiren = {};
        for (var i = 0; i < raw.length; i++) bySiren["S" + raw[i].siren] = raw[i].degree;
        var out = [];
        for (var j = 0; j < _pitchOrder.length; j++) {
            var label = _pitchOrder[j];
            if (bySiren[label] !== undefined) {
                // La fondamentale est la sirène qui porte la première voix
                // (degré 0) — pas la plus grave : un renversement la place
                // n'importe où dans l'ordre de hauteur.
                out.push({ label: label, deg: bySiren[label], fund: bySiren[label] === 0 });
            }
        }
        return out;
    }

    // ================= boucle d'interpolation (30 fps) =================

    property real _bars: 0
    property real _lastMs: 0

    function _tick() {
        var now = Date.now();
        if (_lastMs === 0) { _lastMs = now; return; }
        var dt = Math.min(now - _lastMs, 100);
        _lastMs = now;
        // Même convention que SimulationHarness : BPM ancré sur la noire,
        // indépendant du dénominateur (voir PD_WORK.md §7).
        var quarterMs = 60000 / Math.max(bpm, 1);
        var unitMs = quarterMs * (4 / Math.max(signatureDen, 1));
        var barMs = unitMs * Math.max(beatsPerBar, 1);
        if (transportRunning) _bars += dt / barMs;

        var pulse = 0.3 + 0.35 * (0.5 + 0.5 * Math.sin(now / 190));

        clockBeat = Math.floor((_bars % 1) * beatsPerBar);
        clockBar = Math.floor(_bars) + 1;

        _recomputeRings(pulse);
        _recomputeFocus(pulse);
    }

    function _recomputeRings(pulse) {
        var rs = [];
        for (var i = 1; i <= 7; i++) {
            var s = _loopStates[i];
            var e = { progress: 0, halo: false, haloOpacity: 0, meta: "", present: 1 };
            if (!s || s.source === "out") {
                e.present = 0.2; e.meta = "";
            } else if (s.source === "free") {
                e.present = 0.5; e.meta = "";
            } else if (s.source === "voice") {
                e.meta = s.degree !== undefined ? (s.degree === 0 ? "fond." : "+" + s.degree) : "";
                e.progress = (_bars % 1);
                e.haloOpacity = pulse * 0.3;
            } else if (s.source === "lead" || s.source === "rec" || s.transport === "recording") {
                e.halo = true; e.haloOpacity = pulse * 0.6;
                e.progress = mainLoopSiren === i ? (_bars % 1) : (mainBars > 0 ? (_bars % mainBars) / mainBars : 0);
            } else if (s.transport === "playing" && s.ratio) {
                var len = mainBars / s.ratio;
                e.progress = len > 0 ? (_bars % len) / len : 0;
                e.meta = (mainLoopSiren === i) ? "REF" : _lenLabel(s.ratio, s.loopSize);
            } else if (s.transport === "stopped") {
                // Arc plein et éteint : la boucle est là, chargée, mais ne
                // défile pas. À zéro elle avait l'air effacée alors que PD la
                // garde — le clip est toujours sur le disque et dans midifile.
                e.progress = 1; e.meta = s.ratio ? _lenLabel(s.ratio, s.loopSize) : ""; e.present = 0.7;
            } else {
                e.present = 0.45;
            }
            rs.push(e);
        }
        ringStates = rs;
    }

    function _recomputeFocus(pulse) {
        // L'anneau du haut est le repère de l'interprète : la sirène principale,
        // celle qui porte la première voix — désignée au pied par la pédale key.
        // Elle ne change que sur sa décision, jamais parce qu'une autre sirène
        // s'est mise à enregistrer. À défaut de sélection, on retombe sur
        // l'ancien ordre : la sirène qui enregistre, sinon la référence.
        var recSiren = -1;
        for (var i = 1; i <= 7; i++) {
            var s = _loopStates[i];
            if (s && (s.source === "rec" || s.transport === "recording")) { recSiren = i; break; }
        }

        var focusSiren = monoArmed ? monoSiren : (recSiren > 0 ? recSiren : mainLoopSiren);

        if (focusSiren < 0) {
            focusState = { label: "—", ringColor: "#3B4855", progress: 0, arcOpacity: 1, showHalo: false, haloOpacity: 0,
                           sub: "aucune boucle", statusWord: "AU REPOS", statusColor: "#3B4855", statusNote: "Rien n'est armé.",
                           mBar: "—", mLen: "—", mRatio: "—", mRev: "—", ladderActive: false, ladderStops: [], ladderVerdict: "—" };
            return;
        }

        var spec = SirenSpec.SPEC["siren" + focusSiren] || {};
        var st = _loopStates[focusSiren] || {};
        var isMain = focusSiren === mainLoopSiren;

        // L'anneau décrit la principale et elle seule : son propre défilement,
        // son halo si c'est elle qui enregistre.
        var pRec = st.source === "rec" || st.transport === "recording";
        var pLen = st.ratio ? mainBars / st.ratio : mainBars;
        var ringProgress = 0;
        var ringArc = 1;
        if (pRec) ringProgress = isMain ? (_bars % 1) : (mainBars > 0 ? (_bars % mainBars) / mainBars : 0);
        else if (st.transport === "playing" && pLen > 0) ringProgress = (_bars % pLen) / pLen;
        else if (st.transport === "stopped") {
            // Même règle que les petits anneaux : arc plein et éteint. À zéro, la
            // sirène sélectionnée avait l'air vierge alors qu'elle porte un clip —
            // c'est justement sur elle qu'on a besoin de le voir.
            ringProgress = 1; ringArc = 0.4;
        }

        var ringLabel = spec.label || ("S" + focusSiren);
        var ringColor = spec.color || "#66E4F2";
        var ringSub = monoArmed ? "1re voix" : (isMain ? "référence" : "");

        // Le relevé suit ce qui se joue : un enregistrement ailleurs passe devant
        // avec ses paliers d'atterrissage, et dit de quelle sirène il parle.
        var rep = recSiren > 0 ? recSiren : focusSiren;
        var rSpec = SirenSpec.SPEC["siren" + rep] || {};
        var rLabel = rSpec.label || ("S" + rep);
        var rSt = _loopStates[rep] || {};
        var isRec = rSt.source === "rec" || rSt.transport === "recording";
        var repIsMain = rep === mainLoopSiren;
        var elsewhere = (rep !== focusSiren) ? " — " + rLabel : "";

        if (isRec && repIsMain) {
            var barsInto = Math.floor(_bars) + 1;
            focusState = {
                label: ringLabel, ringColor: ringColor,
                progress: ringProgress, arcOpacity: ringArc, showHalo: pRec, haloOpacity: pRec ? pulse * 0.5 : 0,
                sub: ringSub, statusWord: "ENREGISTRE" + elsewhere, statusColor: "#FFFFFF",
                statusNote: "Première boucle — la longueur sera fixée à l'arrêt.",
                mBar: barsInto.toString(), mLen: "en cours", mRatio: "référence", mRev: "—",
                ladderActive: false, ladderStops: [], ladderVerdict: "pas de référence"
            };
            return;
        }

        if (isRec) {
            var landing = -1, stops = [];
            for (var j = 0; j < _ratios.length; j++) {
                var bars = mainBars * _ratios[j].mul;
                var passed = (_bars >= bars && bars >= 1);
                if (passed) landing = j;
                stops.push({ label: _ratios[j].label, bars: bars < 1 ? 0 : bars, passed: passed, landing: false });
            }
            if (landing >= 0) stops[landing].landing = true;
            var refLabel = mainLoopSiren > 0 ? (SirenSpec.SPEC["siren" + mainLoopSiren] || {}).label || ("S" + mainLoopSiren) : "?";
            focusState = {
                label: ringLabel, ringColor: ringColor,
                progress: ringProgress, arcOpacity: ringArc, showHalo: pRec, haloOpacity: pRec ? pulse * 0.5 : 0,
                sub: ringSub,
                statusWord: "ENREGISTRE" + elsewhere, statusColor: "#FFFFFF",
                statusNote: "Bornée par " + refLabel + " — " + mainBars + " mesures.",
                mBar: (Math.floor(_bars) + 1).toString(),
                mLen: landing >= 0 ? (mainBars * _ratios[landing].mul).toString() : "—",
                mRatio: landing >= 0 ? _ratios[landing].label : "—", mRev: "—",
                ladderActive: true, ladderStops: stops,
                ladderVerdict: landing >= 0 ? ("arrêt maintenant → " + (mainBars * _ratios[landing].mul) + " mesures") : "trop court"
            };
            return;
        }

        // Lecture / arrêt, hors enregistrement — le relevé décrit alors la
        // principale elle-même (rep === focusSiren dans ce cas).
        var playing = rSt.transport === "playing";
        var len2 = rSt.ratio ? mainBars / rSt.ratio : mainBars;
        var hasLoop = rSt.transport !== undefined || rSt.source !== undefined;
        focusState = {
            label: ringLabel, ringColor: ringColor,
            progress: ringProgress, arcOpacity: ringArc, showHalo: false, haloOpacity: 0,
            sub: ringSub,
            statusWord: hasLoop ? (playing ? "LECTURE" : "ARRÊTÉE") : "EN JEU",
            statusColor: "#C7D2DC",
            statusNote: hasLoop
                ? (repIsMain ? "C'est elle qui donne le tempo aux autres." : "")
                : "La note du sirenium part sur " + ringLabel + ".",
            mBar: playing && len2 > 0 ? (Math.floor(_bars % len2) + 1) + " / " + Math.round(len2) : "—",
            mLen: rSt.loopSize ? rSt.loopSize.toString() : "—",
            mRatio: rSt.ratio ? _ratioLabel(rSt.ratio) : "—",
            mRev: rSt.revolutions !== undefined ? rSt.revolutions.toString() : "—",
            ladderActive: false, ladderStops: [], ladderVerdict: hasLoop ? "boucle posée" : "—"
        };
    }

    property Timer _timer: Timer {
        interval: 33; running: true; repeat: true
        onTriggered: live._tick()
    }
}
