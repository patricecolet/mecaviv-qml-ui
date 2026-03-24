import QtQuick

QtObject {
    id: root

    readonly property int modeDirected: 0
    /** Séquencé (JSON chef + transport) — unique mode séquencé. */
    readonly property int modeSequencedStrict: 1

    readonly property int phasePartial: 0
    readonly property int phaseTempered: 1
    readonly property int phaseFullBend: 2

    readonly property int glissInstant: 0
    readonly property int glissVeryFast: 1
    readonly property int glissFast: 2
    readonly property int glissSlow: 3
    readonly property int glissVerySlow: 4
}
