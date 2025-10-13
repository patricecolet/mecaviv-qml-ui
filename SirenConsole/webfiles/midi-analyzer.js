const fs = require('fs');
const midiFile = require('midi-file');
const path = require('path');

/**
 * Analyser un fichier MIDI et extraire les métadonnées
 * @param {string} filePath - Chemin absolu du fichier MIDI
 * @returns {Object} Métadonnées : { duration, totalBeats, tempo, timeSignature }
 */
function analyzeMidiFile(filePath) {
    try {
        // Lire et parser le fichier MIDI
        const buffer = fs.readFileSync(filePath);
        const midi = midiFile.parseMidi(buffer);
        
        // Infos de base
        const ppq = midi.header.ticksPerBeat || 480; // Ticks per quarter note (pulses per quarter)
        
        // Variables pour extraction
        let totalTicks = 0;
        let tempo = 500000; // Défaut 120 BPM (500000 microseconds per beat)
        let timeSignature = { numerator: 4, denominator: 4 }; // Défaut 4/4
        
        // Parser tous les tracks pour trouver le dernier événement et les meta-events
        midi.tracks.forEach(track => {
            let currentTick = 0;
            
            track.forEach(event => {
                currentTick += event.deltaTime;
                
                // Meta-event: Set Tempo (0x51)
                if (event.type === 'setTempo') {
                    tempo = event.microsecondsPerBeat;
                    console.log('📊 Tempo trouvé:', Math.floor(60000000 / tempo), 'BPM');
                }
                
                // Meta-event: Time Signature (0x58)
                if (event.type === 'timeSignature') {
                    timeSignature.numerator = event.numerator;
                    timeSignature.denominator = event.denominator;
                    console.log('📊 Signature trouvée:', timeSignature.numerator + '/' + timeSignature.denominator);
                }
            });
            
            // Garder le plus long track
            if (currentTick > totalTicks) {
                totalTicks = currentTick;
            }
        });
        
        // Calculs finaux
        const bpm = Math.floor(60000000 / tempo);
        const totalBeats = Math.floor(totalTicks / ppq);
        const durationMs = Math.floor((totalTicks / ppq / bpm) * 60000);
        
        const result = {
            duration: durationMs,
            totalBeats: totalBeats,
            tempo: bpm,
            timeSignature: timeSignature,
            ppq: ppq,
            totalTicks: totalTicks
        };
        
        console.log('📁 Analyse MIDI:', path.basename(filePath));
        console.log('   - Durée:', durationMs, 'ms');
        console.log('   - Total beats:', totalBeats);
        console.log('   - Tempo:', bpm, 'BPM');
        console.log('   - Signature:', timeSignature.numerator + '/' + timeSignature.denominator);
        console.log('   - PPQ:', ppq);
        console.log('   - Total ticks:', totalTicks);
        
        return result;
        
    } catch (error) {
        console.error('❌ Erreur analyse MIDI:', error.message);
        
        // Retourner valeurs par défaut en cas d'erreur
        return {
            duration: 0,
            totalBeats: 0,
            tempo: 120,
            timeSignature: { numerator: 4, denominator: 4 },
            ppq: 480,
            totalTicks: 0,
            error: error.message
        };
    }
}

/**
 * Créer un buffer binaire FILE_INFO (type 0x02)
 * @param {number} duration - Durée en ms
 * @param {number} totalBeats - Nombre total de beats
 * @returns {Buffer} Buffer de 10 bytes
 */
function createFileInfoBuffer(duration, totalBeats) {
    const buffer = Buffer.allocUnsafe(10);
    buffer.writeUInt8(0x02, 0);              // messageType
    buffer.writeUInt8(0x00, 1);              // reserved
    buffer.writeUInt32LE(duration, 2);       // duration (ms)
    buffer.writeUInt32LE(totalBeats, 6);     // totalBeats
    return buffer;
}

/**
 * Créer un buffer binaire TEMPO (type 0x03)
 * @param {number} tempo - Tempo en BPM
 * @returns {Buffer} Buffer de 3 bytes
 */
function createTempoBuffer(tempo) {
    const buffer = Buffer.allocUnsafe(3);
    buffer.writeUInt8(0x03, 0);              // messageType
    buffer.writeUInt16LE(tempo, 1);          // tempo (BPM)
    return buffer;
}

/**
 * Créer un buffer binaire TIMESIG (type 0x04)
 * @param {number} numerator - Numérateur (ex: 4)
 * @param {number} denominator - Dénominateur (ex: 4)
 * @returns {Buffer} Buffer de 3 bytes
 */
function createTimeSigBuffer(numerator, denominator) {
    const buffer = Buffer.allocUnsafe(3);
    buffer.writeUInt8(0x04, 0);              // messageType
    buffer.writeUInt8(numerator, 1);         // numerator
    buffer.writeUInt8(denominator, 2);       // denominator
    return buffer;
}

module.exports = {
    analyzeMidiFile,
    createFileInfoBuffer,
    createTempoBuffer,
    createTimeSigBuffer
};

