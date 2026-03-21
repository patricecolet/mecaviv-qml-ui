import QtQuick
import "."

/**
 * Conteneur mode microtonal : même surface d’API que GameMode.qml.
 * viewModel peut être injecté (Test2D) ; sinon instance interne par défaut.
 */
Item {
    id: root
    anchors.fill: parent

    property var configController: null
    property var sirenInfo: null
    property real currentNoteMidi: 60.0
    property bool isPlaying: false

    property var midiEvents: []
    property real gameStartTime: 0
    property bool gameActive: false
    property bool isGameModeActive: true

    property bool showAnticipationLine: false
    property bool showMeasureBars: false

    property real lineSpacing: 20
    property real staffWidth: 1600
    property real staffPosX: 0

    property real vibratoAmount: 0.0
    property real vibratoRate: 5.0
    property real tremoloAmount: 0.0
    property real tremoloRate: 4.0
    property real attackTime: 0
    property real releaseTime: 0

    MicrotonalViewModel {
        id: internalViewModel
    }

    /** Si non défini par le parent, utilise internalViewModel */
    property var viewModel: internalViewModel

    readonly property int subMode: viewModel ? viewModel.subMode : 0

    signal midiEventReceived(var event)

    onMidiEventReceived: function(event) {
        addMidiEvent(event)
    }

    function addMidiEvent(event) {
        var elapsed = (root.gameStartTime > 0) ? (Date.now() - root.gameStartTime) : 0
        var newEvents = midiEvents.slice()
        newEvents.push({
            timestamp: elapsed,
            note: event.note !== undefined ? event.note : (event.midiNote !== undefined ? event.midiNote : 60),
            velocity: event.velocity !== undefined ? event.velocity : 100,
            duration: event.duration !== undefined ? event.duration : 500,
            controllers: event.controllers !== undefined ? event.controllers : {}
        })
        newEvents.sort(function(a, b) {
            return a.timestamp - b.timestamp
        })
        midiEvents = newEvents
    }

    function startGame() {
        root.gameStartTime = Date.now()
        root.gameActive = true
        root.viewModel.applyMockTimeline()
        root.viewModel.sessionTimeMs = 0
        root.viewModel.startDemoClock()
    }

    function resetGame() {
        midiEvents = []
        root.viewModel.reset()
        root.viewModel.applyMockTimeline()
        root.viewModel.stopDemoClock()
        root.gameActive = false
        root.gameStartTime = 0
    }

    function stopGame() {
        root.gameActive = false
        root.viewModel.stopDemoClock()
    }

    function handleControlChange(ccNumber, ccValue) {
        var clampedValue = Math.max(0, Math.min(127, ccValue))
        var normalized = clampedValue / 127.0
        switch (ccNumber) {
        case 1:
            vibratoAmount = normalized * 4.0
            break
        case 9:
            vibratoRate = 1.0 + normalized * 19.0
            break
        case 92:
            tremoloAmount = normalized * 0.6
            break
        case 15:
            tremoloRate = 1.0 + normalized * 19.0
            break
        case 73:
            attackTime = (ccValue === 0) ? 0 : 38100 / (128 - ccValue)
            break
        case 72:
            releaseTime = (ccValue === 0) ? 0 : 38100 / (128 - ccValue)
            break
        default:
            break
        }
    }

    MicrotonalDisplay {
        anchors.fill: parent
        viewModel: root.viewModel
        layoutPreset: "game"
    }
}
