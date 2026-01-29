import QtQuick
import "../../utils"

Item {
    id: root

    property var configController: null
    property var sirenInfo: null

    property real lineSpacing: 20
    property real lineThickness: 1
    property real staffWidth: 1800
    property real staffPosX: 0
    property string clef: sirenInfo ? sirenInfo.clef : "treble"
    property color lineColor: {
        if (configController && configController.updateCounter >= 0) {
            var hexColor = configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "lines", "color"])
            if (hexColor) {
                var color = Qt.color(hexColor)
                return Qt.rgba(color.r, color.g, color.b, color.a)
            }
        }
        return Qt.rgba(0.8, 0.8, 0.8, 1)
    }

    required property real currentNoteMidi
    property real ambitusMin: sirenInfo ? sirenInfo.ambitus.min : 48.0
    property real ambitusMax: sirenInfo ? (sirenInfo.mode === "restricted" && sirenInfo.restrictedMax !== undefined ? sirenInfo.restrictedMax : sirenInfo.ambitus.max) : 84.0
    property int octaveOffset: sirenInfo && sirenInfo.displayOctaveOffset !== undefined ? sirenInfo.displayOctaveOffset : 0

    property bool showCursor: true
    property bool showProgressBar: true
    property bool showAmbitus: true
    property bool showClef: true

    property var staffConfig: {
        if (!configController) return {}
        var d = configController.updateCounter
        return configController.getConfigValue("displayConfig.components.musicalStaff", {})
    }
    readonly property real _clefSizeScale: 0.7
    readonly property real _clefDisplayWidth: lineSpacing * 5.2 * 0.5 * _clefSizeScale
    property real clefWidth: showClef ? ((staffConfig.clef && staffConfig.clef.width) || _clefDisplayWidth) : 0
    property real ambitusOffset: clefWidth

    width: staffWidth
    height: 4 * lineSpacing + lineThickness * 2

    readonly property real _centerY: height / 2

    // Wrapper à _centerY : y=0 = ligne du milieu, y augmente vers le bas.
    // Référence lignes : 2e en partant du bas = +lineSpacing (sol), 2e en partant du haut = -lineSpacing (fa).
    Item {
        x: staffPosX
        y: _centerY
        visible: root.showClef
        width: _clefDisplayWidth * 2
        height: lineSpacing * 6

        Clef2D {
            clefType: root.clef
            lineSpacing: root.lineSpacing * root._clefSizeScale
            clefColor: root.lineColor
            clefOffsetX: 2
            useTargetLineY: true
            targetLineY: root.clef === "treble"
                ? root.lineSpacing
                : -root.lineSpacing
            // verticalOffsetTreble / verticalOffsetBass : réglés dans Clef2D.qml, pas écrasés ici
        }
    }

    // Les 5 lignes de la portée (Phase 2.1) — Rectangle explicites pour éviter crash Canvas/Repeater
    Rectangle {
        x: staffPosX
        y: _centerY + (0 - 2) * lineSpacing - lineThickness / 2
        width: staffWidth
        height: lineThickness
        color: root.lineColor
    }
    Rectangle {
        x: staffPosX
        y: _centerY + (1 - 2) * lineSpacing - lineThickness / 2
        width: staffWidth
        height: lineThickness
        color: root.lineColor
    }
    Rectangle {
        x: staffPosX
        y: _centerY + (2 - 2) * lineSpacing - lineThickness / 2
        width: staffWidth
        height: lineThickness
        color: root.lineColor
    }
    Rectangle {
        x: staffPosX
        y: _centerY + (3 - 2) * lineSpacing - lineThickness / 2
        width: staffWidth
        height: lineThickness
        color: root.lineColor
    }
    Rectangle {
        x: staffPosX
        y: _centerY + (4 - 2) * lineSpacing - lineThickness / 2
        width: staffWidth
        height: lineThickness
        color: root.lineColor
    }
}
