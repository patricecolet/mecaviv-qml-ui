import QtQuick

/**
 * Rail temporel : fenêtre [sessionTimeMs, sessionTimeMs + lookaheadMs].
 * quantized=true : abscisse des marqueurs événements snappée sur subdivisions de temps.
 * quantized=false : positions réelles + lignes de subdivision plus fines.
 */
Item {
    id: root
    implicitHeight: 72
    implicitWidth: 400

    property bool quantized: false
    property real sessionTimeMs: 0
    property real lookaheadMs: 4000
    property real beatPeriodMs: 500
    property real subdivisionsPerBeat: 2
    property var events: []

    property color railColor: "#2a2a2a"
    property color beatColor: "#555"
    property color subBeatColor: "#3a3a3a"
    property color markerColor: "#FFD700"
    property color markerAltColor: "#6bb6ff"

    readonly property int _beatLineCount: Math.ceil(root.lookaheadMs / Math.max(1, root.beatPeriodMs)) + 2
    readonly property real _subStepMs: root.beatPeriodMs / Math.max(1, root.subdivisionsPerBeat)
    readonly property int _subLineCount: Math.ceil(root.lookaheadMs / Math.max(1, root._subStepMs)) + 2

    function snapTimeMs(tMs) {
        if (!root.quantized)
            return tMs
        var sub = root._subStepMs
        return Math.round(tMs / sub) * sub
    }

    function timeToX(tMs, w) {
        var ws = root.sessionTimeMs
        var span = Math.max(1, root.lookaheadMs)
        var t = root.snapTimeMs(tMs)
        if (t < ws || t > ws + span)
            return -1
        return (t - ws) / span * w
    }

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: root.railColor
        border.color: "#666"
        border.width: 1
    }

    Item {
        id: beatLayer
        anchors.fill: parent
        anchors.margins: 2

        Repeater {
            model: root._beatLineCount
            delegate: Rectangle {
                width: 1
                height: parent.height
                x: (index * root.beatPeriodMs) / Math.max(1, root.lookaheadMs) * parent.width
                visible: x >= 0 && x <= parent.width + 1
                color: root.beatColor
            }
        }

        Repeater {
            model: root.quantized ? 0 : root._subLineCount
            delegate: Rectangle {
                width: 1
                height: parent.height * 0.55
                anchors.bottom: parent.bottom
                x: (index * root._subStepMs) / Math.max(1, root.lookaheadMs) * parent.width
                visible: x >= 0 && x <= parent.width + 1
                color: root.subBeatColor
            }
        }
    }

    Item {
        id: markerLayer
        anchors.fill: parent
        anchors.margins: 2

        Repeater {
            model: root.events && root.events.length ? root.events.length : 0
            delegate: Item {
                id: mk
                width: 6
                height: parent.height - 8
                anchors.verticalCenter: parent.verticalCenter
                property var ev: root.events[index]
                x: {
                    if (!mk.ev || mk.ev.tMs === undefined)
                        return -100
                    var xx = root.timeToX(mk.ev.tMs, parent.width)
                    if (xx < 0)
                        return -100
                    return xx - width / 2
                }
                visible: x >= -50

                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    color: index % 2 === 0 ? root.markerColor : root.markerAltColor
                }
            }
        }
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 4
        text: root.quantized ? "quantifié" : "continu + repères"
        color: "#888"
        font.pixelSize: 9
    }
}
