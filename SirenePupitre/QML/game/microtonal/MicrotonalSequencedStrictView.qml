import QtQuick
import "."

Column {
    id: root
    spacing: 10
    width: parent ? parent.width : implicitWidth

    property var viewModel: null

    Text {
        text: "Séquencé — quantifié"
        color: "#6bb6ff"
        font.pixelSize: 18
        font.bold: true
    }

    MicrotonalTimelineRail {
        width: parent.width
        quantized: true
        sessionTimeMs: root.viewModel.sessionTimeMs
        lookaheadMs: 4000
        beatPeriodMs: root.viewModel.beatPeriodMs
        subdivisionsPerBeat: 2
        events: root.viewModel.sequencedEvents
    }

    Text {
        text: "À venir"
        color: "#888"
        font.pixelSize: 11
    }

    ListView {
        width: parent.width
        height: Math.min(220, root.upcomingCount * 44)
        clip: true
        model: root.upcomingCount
        delegate: Rectangle {
            width: ListView.view.width
            height: 40
            color: index % 2 === 0 ? "#2a2a2a" : "#323232"
            border.color: "#444"
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.margins: 8
                text: root.formatRow(root.upcomingAt(index))
                color: "#eee"
                font.pixelSize: 12
            }
        }
    }

    readonly property int upcomingCount: {
        var ev = root.viewModel.sequencedEvents
        if (!ev || !ev.length)
            return 0
        var n = 0
        var t0 = root.viewModel.sessionTimeMs
        for (var i = 0; i < ev.length; i++) {
            if (ev[i].tMs >= t0 - 50)
                n++
        }
        return Math.min(n, 12)
    }

    function upcomingAt(row) {
        var ev = root.viewModel.sequencedEvents
        var t0 = root.viewModel.sessionTimeMs
        var j = 0
        for (var i = 0; i < ev.length; i++) {
            if (ev[i].tMs >= t0 - 50) {
                if (j === row)
                    return ev[i]
                j++
            }
        }
        return null
    }

    function formatRow(e) {
        if (!e)
            return ""
        var beat = e.beatSlot !== undefined ? "T" + e.beatSlot : "—"
        return beat + "  ·  " + e.label + "  ·  Δ " + e.targetCents.toFixed(0) + " ct"
    }
}
