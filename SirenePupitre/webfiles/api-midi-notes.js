/**
 * API pour extraire les notes d'un fichier MIDI (séquenceur d'animation, lookahead).
 * GET /api/midi/notes?path=xxx&channel=N&byChannel=0|1
 * - path: chemin relatif du fichier (ex. louette/AnxioGapT.mid)
 * - channel: si byChannel=1 = canal MIDI 0-15 (chaque sirène = un canal) ; sinon index de piste 0-based
 * - byChannel: 1 = filtrer par canal MIDI (toutes pistes), 0 ou absent = extraire une piste (comportement historique)
 * Retourne: { bpm, ppq, tempoMap, timeSignatureMap, notes: [{ tick, note, velocity, durationMs, timestampMs }, ...] }
 * - tempoMap: [{ tick, microsecondsPerQuarter }] pour conversion tick → ms avec changements de tempo
 * - timeSignatureMap: [{ tick, numerator, denominator }] pour conversion tick → bar/beat avec changements de mesure
 */

const fs = require('fs');
const path = require('path');
const { loadConfig } = require('../../config-loader.js');

let parseMidi;
try {
    parseMidi = require('midi-file').parseMidi;
} catch (e) {
    console.warn('⚠️ midi-file non installé. Exécuter: npm install');
    parseMidi = null;
}

const config = loadConfig();
const MIDI_REPO_PATH = process.env.MECAVIV_COMPOSITIONS_PATH || config.paths.midiRepository;

const DEFAULT_MICROSECONDS_PER_QUARTER = 500000; // 120 BPM
const DEFAULT_NUMERATOR = 4;
const DEFAULT_DENOMINATOR = 4;

/**
 * Construire tempo map et time signature map à partir de la piste 0 (conductor).
 * Retourne { tempoMap, timeSignatureMap, ppq }.
 * tempoMap: [{ tick, microsecondsPerQuarter }], trié par tick, au moins un élément à tick 0.
 * timeSignatureMap: [{ tick, numerator, denominator }], trié par tick, au moins un élément à tick 0.
 */
function buildTempoAndTimeSignatureMaps(parsed) {
    const ppq = parsed.header && parsed.header.ticksPerBeat ? parsed.header.ticksPerBeat : 480;
    const tempoMap = [{ tick: 0, microsecondsPerQuarter: DEFAULT_MICROSECONDS_PER_QUARTER }];
    const timeSignatureMap = [{ tick: 0, numerator: DEFAULT_NUMERATOR, denominator: DEFAULT_DENOMINATOR }];

    if (!parsed.tracks || !parsed.tracks[0]) return { tempoMap, timeSignatureMap, ppq };

    let absTick = 0;
    for (const ev of parsed.tracks[0]) {
        absTick += ev.deltaTime;
        if (ev.type === 'setTempo') {
            const us = ev.microsecondsPerBeat ?? ev.microsecondsPerQuarter ?? DEFAULT_MICROSECONDS_PER_QUARTER;
            if (absTick === 0)
                tempoMap[0] = { tick: 0, microsecondsPerQuarter: us };
            else
                tempoMap.push({ tick: absTick, microsecondsPerQuarter: us });
        } else if (ev.type === 'timeSignature') {
            const nn = ev.numerator ?? DEFAULT_NUMERATOR;
            const dd = ev.denominator ?? DEFAULT_DENOMINATOR;
            timeSignatureMap.push({ tick: absTick, numerator: nn, denominator: dd });
        }
    }

    return { tempoMap, timeSignatureMap, ppq };
}

/**
 * Convertir un tick en millisecondes en utilisant la tempo map (changements de tempo).
 */
function tickToMs(tick, ppq, tempoMap) {
    if (tempoMap.length === 0) return 0;
    let ms = 0;
    let lastTick = 0;
    let tempo = tempoMap[0].microsecondsPerQuarter;
    for (let i = 1; i < tempoMap.length && tempoMap[i].tick <= tick; i++) {
        const segmentTicks = tempoMap[i].tick - lastTick;
        ms += (segmentTicks * tempo / ppq) / 1000;
        lastTick = tempoMap[i].tick;
        tempo = tempoMap[i].microsecondsPerQuarter;
    }
    const segmentTicks = tick - lastTick;
    ms += (segmentTicks * tempo / ppq) / 1000;
    return ms;
}

/**
 * Ticks par mesure pour une signature nn/dd (denominator = puissance de 2 : 2=noire, 3=croche, etc.).
 */
function ticksPerBar(ppq, numerator, denominator) {
    const beatUnit = 4 / Math.pow(2, denominator);
    return ppq * numerator * beatUnit;
}

/**
 * Convertir un tick en bar / beat en utilisant la time signature map.
 * Retourne { bar, beatInBar, beat } (beat peut être décimal, ex. 3.5).
 */
function tickToBarBeat(tick, ppq, timeSignatureMap) {
    if (timeSignatureMap.length === 0) return { bar: 1, beatInBar: 1, beat: 1 };
    let bar = 1;
    let lastTick = 0;
    let num = timeSignatureMap[0].numerator;
    let den = timeSignatureMap[0].denominator;
    for (let i = 1; i < timeSignatureMap.length && timeSignatureMap[i].tick <= tick; i++) {
        const tpb = ticksPerBar(ppq, num, den);
        const ticksInSegment = timeSignatureMap[i].tick - lastTick;
        bar += Math.floor(ticksInSegment / tpb);
        lastTick = timeSignatureMap[i].tick;
        num = timeSignatureMap[i].numerator;
        den = timeSignatureMap[i].denominator;
    }
    const tpb = ticksPerBar(ppq, num, den);
    const ticksInCurrentBar = (tick - lastTick) % tpb;
    const ticksPerBeat = tpb / num;
    const beatInBar = Math.floor(ticksInCurrentBar / ticksPerBeat) + 1;
    const beat = (ticksInCurrentBar / ticksPerBeat) + 1;
    return { bar, beatInBar, beat };
}

/**
 * Extraire les notes (noteOn/noteOff) d'une piste et calculer durée / timestamp en ms avec la tempo map.
 */
function extractNotesFromTrack(parsed, trackIndex, tempoMap, ppq) {
    const track = parsed.tracks[trackIndex];
    if (!track) return [];

    let absTick = 0;
    const noteOns = {};
    const notes = [];

    for (const ev of track) {
        absTick += ev.deltaTime;

        if (ev.type === 'noteOn') {
            const note = ev.noteNumber ?? ev.note;
            const vel = ev.velocity ?? 0;
            if (vel > 0) {
                noteOns[note] = { tick: absTick, velocity: vel };
            } else {
                if (noteOns[note]) {
                    const start = noteOns[note].tick;
                    const durationTicks = absTick - start;
                    notes.push({
                        tick: start,
                        note,
                        velocity: noteOns[note].velocity,
                        durationTicks,
                        durationMs: tickToMs(start + durationTicks, ppq, tempoMap) - tickToMs(start, ppq, tempoMap),
                        timestampMs: tickToMs(start, ppq, tempoMap)
                    });
                    delete noteOns[note];
                }
            }
        } else if (ev.type === 'noteOff') {
            const note = ev.noteNumber ?? ev.note;
            if (noteOns[note]) {
                const start = noteOns[note].tick;
                const durationTicks = absTick - start;
                notes.push({
                    tick: start,
                    note,
                    velocity: noteOns[note].velocity,
                    durationTicks,
                    durationMs: tickToMs(start + durationTicks, ppq, tempoMap) - tickToMs(start, ppq, tempoMap),
                    timestampMs: tickToMs(start, ppq, tempoMap)
                });
                delete noteOns[note];
            }
        }
    }

    notes.sort((a, b) => a.tick - b.tick);
    return notes;
}

/**
 * Extraire les notes d'un canal MIDI (0-15) sur toutes les pistes (sauf piste 0 conducteur).
 * Sirène = canal : S1 = canal 0, S2 = canal 1, etc.
 */
function extractNotesByMidiChannel(parsed, midiChannel, tempoMap, ppq) {
    if (!parsed.tracks || parsed.tracks.length < 2) return [];
    const ch = midiChannel >= 0 && midiChannel <= 15 ? midiChannel : 0;
    const raw = [];
    for (let ti = 1; ti < parsed.tracks.length; ti++) {
        const track = parsed.tracks[ti];
        let absTick = 0;
        for (const ev of track) {
            absTick += ev.deltaTime;
            const evChannel = ev.channel !== undefined ? ev.channel : 0;
            if (evChannel !== ch) continue;
            if (ev.type === 'noteOn') {
                const note = ev.noteNumber ?? ev.note;
                const vel = ev.velocity ?? 0;
                raw.push({ absTick, type: 'noteOn', note, velocity: vel });
            } else if (ev.type === 'noteOff') {
                const note = ev.noteNumber ?? ev.note;
                raw.push({ absTick, type: 'noteOff', note });
            }
        }
    }
    raw.sort((a, b) => a.absTick - b.absTick);
    const noteOns = {};
    const notes = [];
    for (const e of raw) {
        if (e.type === 'noteOn' && e.velocity > 0) {
            noteOns[e.note] = { tick: e.absTick, velocity: e.velocity };
        } else if (e.type === 'noteOff' || (e.type === 'noteOn' && e.velocity === 0)) {
            if (noteOns[e.note]) {
                const start = noteOns[e.note].tick;
                const durationTicks = e.absTick - start;
                notes.push({
                    tick: start,
                    note: e.note,
                    velocity: noteOns[e.note].velocity,
                    durationTicks,
                    durationMs: tickToMs(start + durationTicks, ppq, tempoMap) - tickToMs(start, ppq, tempoMap),
                    timestampMs: tickToMs(start, ppq, tempoMap)
                });
                delete noteOns[e.note];
            }
        }
    }
    notes.sort((a, b) => a.tick - b.tick);
    return notes;
}

/**
 * Retourne le tick de fin du morceau : max des ticks de fin de chaque piste
 * (somme des deltaTime = position du dernier événement ou meta end-of-track).
 */
function getEndOfTrackTick(parsed) {
    if (!parsed.tracks || parsed.tracks.length === 0) return null;
    let maxTick = 0;
    for (const track of parsed.tracks) {
        let tick = 0;
        for (const ev of track) {
            tick += ev.deltaTime;
        }
        if (tick > maxTick) maxTick = tick;
    }
    return maxTick;
}

/**
 * GET /api/midi/notes?path=xxx&channel=N&byChannel=0|1
 * byChannel=1 : channel = canal MIDI 0-15 (sirène = canal). Sinon channel = index de piste 0-based.
 */
async function getMidiNotes(req, res) {
    if (!parseMidi) {
        res.writeHead(503, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ type: 'ERROR', message: 'midi-file non installé' }));
        return;
    }

    const url = new URL(req.url, 'http://localhost');
    const pathParam = url.searchParams.get('path');
    const channelParam = url.searchParams.get('channel');
    const byChannel = url.searchParams.get('byChannel') === '1';
    const channelOrTrackIndex = channelParam !== null ? parseInt(channelParam, 10) : 0;

    if (!pathParam || pathParam.includes('..')) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ type: 'ERROR', message: 'paramètre path requis et sécurisé' }));
        return;
    }

    const fullPath = path.join(MIDI_REPO_PATH, pathParam.replace(/\\/g, '/'));

    try {
        const buffer = fs.readFileSync(fullPath);
        const parsed = parseMidi(buffer);
        const { tempoMap, timeSignatureMap, ppq } = buildTempoAndTimeSignatureMaps(parsed);
        const notes = byChannel
            ? extractNotesByMidiChannel(parsed, channelOrTrackIndex, tempoMap, ppq)
            : extractNotesFromTrack(parsed, channelOrTrackIndex, tempoMap, ppq);

        const firstTempo = tempoMap[0].microsecondsPerQuarter;
        const bpm = Math.round(60000000 / firstTempo);

        const endOfTrackTick = getEndOfTrackTick(parsed);
        const response = {
            type: 'MIDI_NOTES',
            path: pathParam,
            channel: channelOrTrackIndex,
            byChannel: byChannel,
            bpm,
            ppq,
            tempoMap,
            timeSignatureMap,
            notes,
            endOfTrackTick: endOfTrackTick != null ? endOfTrackTick : undefined
        };

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(response));
    } catch (err) {
        console.error('❌ getMidiNotes:', err.message);
        res.writeHead(err.code === 'ENOENT' ? 404 : 500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ type: 'ERROR', message: err.message }));
    }
}

module.exports = { getMidiNotes, tickToMs, tickToBarBeat, ticksPerBar };
