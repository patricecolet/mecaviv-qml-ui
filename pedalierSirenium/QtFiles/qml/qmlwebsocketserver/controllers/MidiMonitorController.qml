import QtQuick

Item {
    id: midiMonitorController

    // Logger optionnel
    property var logger: null

    // Propriétés publiques pour le monitoring
    property int note: 0
    property int velocity: 0
    property int bend: 8192
    property int channel: 0

    // Agrégation des événements pour logs périodiques
    property int midiEventCount: 0
    property string lastEventHex: ""

    // Détection du mode
    readonly property bool isWasm: Qt.platform.os === "wasm"

    // Signal pour notifier les changements
    signal midiDataChanged(int note, int velocity, int bend, int channel)

    // ===== Intégration PD via WebSocket (binaire) =====
    function applyExternalMidiBytes(bytes) {
        if (!bytes || bytes.length === 0) return;
        const len = bytes.length;
        // Compter l'événement et mémoriser la dernière trame (hex)
        midiEventCount++;
        try {
            lastEventHex = Array.prototype.map.call(bytes, function(b){ return (b & 0xFF).toString(16).padStart(2, "0"); }).join(" ");
        } catch (e) {
            // Fallback si bytes n'est pas itérable classique
            lastEventHex = "len=" + len;
        }
        if (len === 1) {
            const s = bytes[0];
            // 0xF8 clock, 0xFA start, 0xFB continue, 0xFC stop
            // Géré côté BeatController si nécessaire
            return;
        } else if (len === 3) {
            applyExternalMidiFromStatus(bytes[0], bytes[1], bytes[2]);
        }
    }

    function applyExternalMidiFromStatus(status, data1, data2) {
        const type = status & 0xF0;
        const ch = status & 0x0F;
        if (logger) logger.trace("MIDI", "evt:", type.toString(16), "ch:", ch, "d1:", data1, "d2:", data2);
        if (type === 0x90) { // Note On
            if (data2 > 0) {
                note = data1; velocity = data2; channel = ch;
                midiDataChanged(note, velocity, bend, channel);
            } else {
                velocity = 0;
                midiDataChanged(data1, 0, bend, ch);
            }
        } else if (type === 0x80) { // Note Off
            velocity = 0;
            midiDataChanged(data1, 0, bend, ch);
        } else if (type === 0xE0) { // Pitch Bend
            const bendValue = (data2 << 7) | data1;
            bend = bendValue; channel = ch;
            midiDataChanged(note, velocity, bend, channel);
        }
    }

    function resetData() {
        note = 0;
        velocity = 0;
        bend = 8192;
        channel = 0;
        if (logger) logger.info("MIDI", "🔄 Données MIDI réinitialisées");
    }

    // Résumé toutes les 1000 ms
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (!logger) return;
            if (midiEventCount > 0) {
                logger.info("MIDI", "résumé 1000ms:", midiEventCount, "dernière:", lastEventHex);
                midiEventCount = 0;
                lastEventHex = "";
            }
        }
    }
}


