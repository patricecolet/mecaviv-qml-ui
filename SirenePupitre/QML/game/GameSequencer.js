/**
 * Séquenceur d'animation pour le mode jeu (lookahead).
 * Charge les notes du fichier MIDI via l'API /api/midi/notes et calcule
 * les segments dans la fenêtre [currentTime, currentTime + lookahead]
 * pour alimenter MelodicLine2D. Utilise tempo map et time signature map
 * du fichier MIDI pour mesure et temps corrects (changements de tempo/mesure).
 */

var _notes = [];
var _bpm = 120;
var _ppq = 480;
var _tempoMap = [];
var _timeSignatureMap = [];

/**
 * Retourne l'URL de base pour l'API (même logique que GameAutonomyPanel).
 */
function getApiBase() {
    if (typeof Qt === "undefined") return "http://localhost:8000";
    var apiUrl = Qt.resolvedUrl("/api/midi/notes").toString();
    if (apiUrl.indexOf("file://") === 0 || apiUrl.indexOf("qrc:") === 0) {
        return "http://" + (typeof window !== "undefined" ? window.location.host : "localhost:8000");
    }
    var idx = apiUrl.indexOf("/api/");
    return idx >= 0 ? apiUrl.substring(0, idx) : "http://localhost:8000";
}

/**
 * Charge les notes du fichier MIDI pour le canal (sirène) donné.
 * path: chemin relatif (ex. "louette/AnxioGapT.mid")
 * channelOrTrack: canal MIDI 0-15 (index sirène) si byChannel=1, sinon index de piste 0-based
 * callback: function(notes, bpm, ppq, tempoMap, timeSignatureMap) ou function(null, 0, 0, [], []) en cas d'erreur
 */
function loadNotes(path, channelOrTrack, callback) {
    if (!path || !callback) return;
    var base = getApiBase();
    var url = base + "/api/midi/notes?path=" + encodeURIComponent(path) + "&channel=" + (channelOrTrack || 0) + "&byChannel=1";
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url);
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (xhr.status === 200) {
            try {
                var resp = JSON.parse(xhr.responseText);
                if (resp.type === "MIDI_NOTES" && resp.notes) {
                    _notes = resp.notes;
                    _bpm = resp.bpm || 120;
                    _ppq = resp.ppq || 480;
                    _tempoMap = resp.tempoMap && resp.tempoMap.length > 0 ? resp.tempoMap : [{ tick: 0, microsecondsPerQuarter: 500000 }];
                    _timeSignatureMap = resp.timeSignatureMap && resp.timeSignatureMap.length > 0 ? resp.timeSignatureMap : [{ tick: 0, numerator: 4, denominator: 4 }];
                    callback(_notes, _bpm, _ppq, _tempoMap, _timeSignatureMap);
                } else {
                    _notes = [];
                    _tempoMap = [];
                    _timeSignatureMap = [];
                    callback(null, 0, 0, [], []);
                }
            } catch (e) {
                _notes = [];
                _tempoMap = [];
                _timeSignatureMap = [];
                callback(null, 0, 0, [], []);
            }
        } else {
            _notes = [];
            _tempoMap = [];
            _timeSignatureMap = [];
            callback(null, 0, 0, [], []);
        }
    };
    xhr.send();
}

/**
 * Convertir tick en ms en utilisant la tempo map (changements de tempo).
 * Si tempoMap vide ou absent, fallback BPM/ppq simple.
 */
function tickToMs(tick, ppq, tempoMap) {
    if (typeof tick !== "number" || !isFinite(tick) || tick < 0) tick = 0;
    var map = tempoMap && tempoMap.length > 0 ? tempoMap : null;
    if (!map) {
        var bpm = _bpm || 120;
        if (!ppq || ppq <= 0) ppq = 480;
        return (tick / ppq) * (60000 / bpm);
    }
    var ms = 0;
    var lastTick = 0;
    var tempo = map[0].microsecondsPerQuarter || 500000;
    for (var i = 1; i < map.length && map[i].tick <= tick; i++) {
        var segmentTicks = map[i].tick - lastTick;
        ms += (segmentTicks * tempo / ppq) / 1000;
        lastTick = map[i].tick;
        tempo = map[i].microsecondsPerQuarter || 500000;
    }
    var segmentTicks = tick - lastTick;
    ms += (segmentTicks * tempo / ppq) / 1000;
    return ms;
}

/**
 * Ticks par mesure pour une signature nn/dd.
 * Formule : numerator * (4/denominator) * ppq = nb de beats × nb de ticks par beat.
 * Ex. 7/8, ppq=480 : 7 * (4/8) * 480 = 1680. Ex. 4/4 : 4 * (4/4) * 480 = 1920.
 */
function ticksPerBar(ppq, numerator, denominator) {
    if (!denominator || denominator <= 0) denominator = 4;
    return numerator * (4 / denominator) * ppq;
}

/**
 * Convertir tick en bar/beat en utilisant la time signature map.
 * Si timeSignatureMap vide ou absent, fallback 4/4.
 */
function tickToPosition(tick, ppq, timeSignatureMap) {
    if (typeof tick !== "number" || !isFinite(tick) || tick < 0) tick = 0;
    if (!ppq || ppq <= 0) ppq = 480;
    var map = timeSignatureMap && timeSignatureMap.length > 0 ? timeSignatureMap : null;
    if (!map) {
        var totalBeats = tick / ppq;
        totalBeats = Math.max(0, totalBeats);
        var bar = Math.floor(totalBeats / 4) + 1;
        var beatInBar = (Math.floor(totalBeats) % 4) + 1;
        var beat = (totalBeats % 4) + 1;
        return { bar: bar, beatInBar: beatInBar, beat: beat };
    }
    var bar = 1;
    var lastTick = 0;
    var num = map[0].numerator || 4;
    var den = map[0].denominator || 4;
    for (var i = 1; i < map.length && map[i].tick <= tick; i++) {
        var tpb = ticksPerBar(ppq, num, den);
        var ticksInSegment = map[i].tick - lastTick;
        bar += Math.floor(ticksInSegment / tpb);
        lastTick = map[i].tick;
        num = map[i].numerator || 4;
        den = map[i].denominator || 4;
    }
    var tpb = ticksPerBar(ppq, num, den);
    var ticksInCurrentBar = (tick - lastTick) % tpb;
    var ticksPerBeat = tpb / num;
    var beatInBar = Math.floor(ticksInCurrentBar / ticksPerBeat) + 1;
    var beat = (ticksInCurrentBar / ticksPerBeat) + 1;
    return { bar: bar, beatInBar: beatInBar, beat: beat };
}

/**
 * Convertir ms en tick en utilisant la tempo map (inverse de tickToMs).
 */
function msToTick(ms, ppq, tempoMap) {
    if (typeof ms !== "number" || !isFinite(ms) || ms < 0) return 0;
    var map = tempoMap && tempoMap.length > 0 ? tempoMap : null;
    if (!map) {
        var bpm = _bpm || 120;
        if (!ppq || ppq <= 0) ppq = 480;
        return (ms / (60000 / bpm)) * ppq;
    }
    var remainingMs = ms;
    var lastTick = 0;
    var tempo = map[0].microsecondsPerQuarter || 500000;
    for (var i = 1; i < map.length; i++) {
        var segmentTicks = map[i].tick - lastTick;
        var segmentMs = (segmentTicks * tempo / ppq) / 1000;
        if (remainingMs <= segmentMs) {
            return lastTick + (remainingMs * 1000 / tempo) * ppq;
        }
        remainingMs -= segmentMs;
        lastTick = map[i].tick;
        tempo = map[i].microsecondsPerQuarter || 500000;
    }
    return lastTick + (remainingMs * 1000 / tempo) * ppq;
}

/**
 * Convertir (bar, beatInBar, beat) en tick avec la time signature map.
 */
function positionToTick(bar, beatInBar, beat, ppq, timeSignatureMap) {
    if (typeof bar !== "number" || bar < 1) bar = 1;
    var b = typeof beat === "number" ? beat : (typeof beatInBar === "number" ? beatInBar : 1);
    if (!ppq || ppq <= 0) ppq = 480;
    var map = timeSignatureMap && timeSignatureMap.length > 0 ? timeSignatureMap : null;
    if (!map) {
        var totalBeats = (bar - 1) * 4 + (b - 1);
        totalBeats = Math.max(0, totalBeats);
        return totalBeats * ppq;
    }
    var barIdx = 1;
    var lastTick = 0;
    var num = map[0].numerator || 4;
    var den = map[0].denominator || 4;
    for (var i = 1; i < map.length && barIdx < bar; i++) {
        var tpb = ticksPerBar(ppq, num, den);
        var ticksInSegment = map[i].tick - lastTick;
        barIdx += Math.floor(ticksInSegment / tpb);
        lastTick = map[i].tick;
        num = map[i].numerator || 4;
        den = map[i].denominator || 4;
    }
    var tpb = ticksPerBar(ppq, num, den);
    var ticksPerBeat = tpb / num;
    var tickInBar = (bar - barIdx) * tpb + (b - 1) * ticksPerBeat;
    return lastTick + tickInBar;
}

/**
 * Convertir (bar, beatInBar, beat) en ms avec tempo map + time signature map.
 */
function positionToMsWithMaps(bar, beatInBar, beat, ppq, tempoMap, timeSignatureMap) {
    var pq = ppq || _ppq || 480;
    var tmap = tempoMap && tempoMap.length > 0 ? tempoMap : null;
    var smap = timeSignatureMap && timeSignatureMap.length > 0 ? timeSignatureMap : null;
    if (!tmap || !smap)
        return positionToMs(bar, beatInBar, beat, _bpm || 120);
    var tick = positionToTick(bar, beatInBar, beat, pq, smap);
    return tickToMs(tick, pq, tmap);
}

/**
 * Convertir la position de lecture (bar, beatInBar, beat) en temps en ms.
 * BPM fixe et 4/4 (fallback).
 */
function positionToMs(bar, beatInBar, beat, bpm) {
    if (!bpm || bpm <= 0) bpm = 120;
    var beatsPerBar = 4;
    var b = typeof beat === "number" ? beat : (beatInBar || 1);
    var totalBeats = (bar - 1) * beatsPerBar + (b - 1);
    totalBeats = Math.max(0, totalBeats);
    return totalBeats * (60000 / bpm);
}

/**
 * Temps écoulé (ms) -> bar, beatInBar, beat (pour simulateur local).
 * Utilise tempo map + time signature map : ms -> tick -> bar/beat.
 */
function positionFromMs(currentTimeMs, bpm, ppq, tempoMap, timeSignatureMap) {
    if (typeof currentTimeMs !== "number" || !isFinite(currentTimeMs) || currentTimeMs < 0) currentTimeMs = 0;
    var pq = ppq || _ppq || 480;
    var tmap = tempoMap && tempoMap.length > 0 ? tempoMap : null;
    var smap = timeSignatureMap && timeSignatureMap.length > 0 ? timeSignatureMap : null;
    if (!tmap || !smap) {
        if (!bpm || bpm <= 0) bpm = 120;
        var totalBeats = (currentTimeMs / 1000) * (bpm / 60);
        totalBeats = Math.max(0, totalBeats);
        var bar = Math.floor(totalBeats / 4) + 1;
        var beatInBar = (Math.floor(totalBeats) % 4) + 1;
        var beat = (totalBeats % 4) + 1;
        return { bar: bar, beatInBar: beatInBar, beat: beat };
    }
    var tick = msToTick(currentTimeMs, pq, tmap);
    return tickToPosition(tick, pq, smap);
}

/**
 * Retourne la durée totale du morceau en ms (fin de la dernière note).
 * Si timestampMs manque, utilise tick + durationTicks avec tickToMs(ppq, tempoMap).
 */
function getTotalDurationMs(notes, ppq, tempoMap) {
    if (!notes || notes.length === 0) return 0;
    var end = 0;
    for (var i = 0; i < notes.length; i++) {
        var n = notes[i];
        var d = n.durationMs != null ? n.durationMs : (n.duration || 500);
        var t;
        if (n.timestampMs != null && typeof n.timestampMs === "number" && isFinite(n.timestampMs)) {
            t = n.timestampMs + d;
        } else if (n.tick != null && typeof n.tick === "number" && (ppq != null || tempoMap) && (tempoMap == null || tempoMap.length > 0)) {
            var pq = ppq || _ppq || 480;
            var endTick = n.tick + (n.durationTicks != null ? n.durationTicks : Math.round(d * pq / 60000 * (_bpm || 120)));
            t = tickToMs(endTick, ppq, tempoMap);
        } else {
            t = 0 + d;
        }
        if (t > end) end = t;
    }
    return end;
}

/**
 * Nombre total de mesures du morceau (à partir de la durée totale et des maps).
 */
function getTotalBars(notes, bpm, ppq, tempoMap, timeSignatureMap) {
    if (!notes || notes.length === 0) return 1;
    var totalMs = getTotalDurationMs(notes, ppq, tempoMap);
    var pos = positionFromMs(totalMs, bpm, ppq, tempoMap, timeSignatureMap);
    return Math.max(1, Math.floor(pos.bar));
}

/**
 * Nombre total de mesures en respectant les changements de signature :
 * 1) On regarde les changements de signature (timeSignatureMap).
 * 2) On calcule le nombre de ticks entre chaque paire de changements (ou jusqu'à la fin).
 * 3) On convertit les ticks en mesures avec la signature du segment (ticksPerBar).
 */
function getTotalBarsFromSignatures(totalDurationMs, ppq, tempoMap, timeSignatureMap) {
    if (typeof totalDurationMs !== "number" || !isFinite(totalDurationMs) || totalDurationMs < 0) return 1;
    var pq = ppq || _ppq || 480;
    var smap = timeSignatureMap && timeSignatureMap.length > 0 ? timeSignatureMap : null;
    var endTick = msToTick(totalDurationMs, pq, tempoMap);
    if (!smap || smap.length === 0) {
        var beats = (endTick / pq) * 4; // 4 beats par mesure en fallback 4/4
        return Math.max(1, Math.ceil(beats / 4));
    }
    var totalBars = 0;
    for (var i = 0; i < smap.length; i++) {
        var segStart = smap[i].tick;
        // Fin du segment : prochain changement de signature OU fin du morceau (ne pas dépasser endTick)
        var segEndRaw = (i + 1 < smap.length) ? smap[i + 1].tick : endTick;
        var segEnd = Math.min(segEndRaw, endTick);
        if (segStart >= endTick) continue;  // segment après la fin du morceau
        if (segEnd <= segStart) continue;
        var num = smap[i].numerator || 4;
        var den = smap[i].denominator || 4;
        var tpb = ticksPerBar(pq, num, den);
        var ticksInSegment = segEnd - segStart;
        var measuresInSegment = ticksInSegment / tpb;
        totalBars += measuresInSegment;
    }
    return Math.max(1, Math.floor(totalBars));
}

/**
 * BPM au temps donné (ms), d'après la tempo map. Sinon BPM par défaut.
 */
function getBpmAtMs(ms, ppq, tempoMap, defaultBpm) {
    if (typeof ms !== "number" || !isFinite(ms) || ms < 0) ms = 0;
    var map = tempoMap && tempoMap.length > 0 ? tempoMap : null;
    if (!map) return defaultBpm || 120;
    var tick = msToTick(ms, ppq, map);
    var lastTempo = map[0].microsecondsPerQuarter || 500000;
    for (var i = 1; i < map.length && map[i].tick <= tick; i++)
        lastTempo = map[i].microsecondsPerQuarter || 500000;
    return Math.round(60000000 / lastTempo);
}

/**
 * Retourne les segments (format MelodicLine2D / processMidiEvents) dont le
 * timestamp est dans [currentTimeMs, currentTimeMs + lookaheadMs].
 * Utilise bar/beat pour calculer currentMs (positionToMs).
 */
function getSegmentsInWindow(notes, bpm, bar, beatInBar, beat, lookaheadMs) {
    if (!notes || notes.length === 0) return [];
    var currentMs = positionToMs(bar, beatInBar, beat, bpm);
    var endMs = currentMs + (lookaheadMs || 8000);
    return getSegmentsInWindowFromMs(notes, currentMs, lookaheadMs);
}

/**
 * Retourne les segments dont le timestamp est dans [currentTimeMs, currentTimeMs + lookaheadMs].
 * Utilisé par le simulateur quand on a déjà currentTimeMs (elapsed).
 */
function getSegmentsInWindowFromMs(notes, currentTimeMs, lookaheadMs) {
    if (!notes || notes.length === 0) return [];
    var endMs = currentTimeMs + (lookaheadMs || 8000);
    var pq = _ppq || 480;
    var tmap = _tempoMap && _tempoMap.length > 0 ? _tempoMap : null;
    var out = [];
    for (var i = 0; i < notes.length; i++) {
        var n = notes[i];
        var t = n.timestampMs;
        if (typeof t !== "number" || !isFinite(t)) {
            if (n.tick != null && typeof n.tick === "number" && pq > 0 && tmap && tmap.length > 0)
                t = tickToMs(n.tick, pq, tmap);
            else
                t = (n.timestamp != null && typeof n.timestamp === "number" && isFinite(n.timestamp)) ? n.timestamp : 0;
        }
        var dur = n.durationMs;
        if (typeof dur !== "number" || !isFinite(dur) || dur <= 0) {
            if (n.durationTicks != null && typeof n.durationTicks === "number" && n.tick != null && pq > 0 && tmap && tmap.length > 0)
                dur = tickToMs(n.tick + n.durationTicks, pq, tmap) - tickToMs(n.tick, pq, tmap);
            else
                dur = n.duration || 500;
        }
        if (t >= currentTimeMs && t <= endMs) {
            out.push({
                timestamp: t,
                note: n.note,
                velocity: n.velocity || 100,
                duration: dur,
                x: 0,
                vibrato: false,
                tremolo: false,
                volume: (n.velocity || 100) / 127.0
            });
        }
    }
    return out;
}

/**
 * Calcule la durée de chute (fallDurationMs) pour un élément (note ou barre de mesure).
 * Prend en compte le délai MIDI : la note au temps t sera jouée à currentTimeMs = t + midiDelay.
 * 
 * @param {number} targetTimeMs - Temps de début de l'élément (note ou mesure)
 * @param {number} currentTimeMs - Temps actuel du séquenceur
 * @param {number} midiDelay - Délai MIDI en ms (= fixedFallTime, typiquement 5000ms)
 * @returns {number} Durée de chute (ms), 0 si l'élément est déjà passé
 */
function calculateFallDurationMs(targetTimeMs, currentTimeMs, midiDelay) {
    var fallDurationMs = targetTimeMs + midiDelay - currentTimeMs;
    return fallDurationMs > 0 ? fallDurationMs : 0;
}
