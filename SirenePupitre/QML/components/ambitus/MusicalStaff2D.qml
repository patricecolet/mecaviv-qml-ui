import QtQuick
import "../../utils"
import "."

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
        return Qt.rgba(1, 1, 1)
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
    property var ambitusConfig: staffConfig.ambitus || {}
    property var progressConfig: staffConfig.progressBar || {}
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

    // Ambitus 2D (Phase 2.3) — cercles pour chaque note de l'ambitus (resserré avec marges)
    readonly property real _ambitusMarginX: lineSpacing * 2
    AmbitusDisplay2D {
        id: ambitusDisplay2D
        x: 0
        y: 0
        width: root.staffWidth
        height: root.height
        centerY: root._centerY
        visible: root.showAmbitus && (configController ? configController.getConfigValue("displayConfig.components.musicalStaff.ambitus.visible", true) : true)
        ambitusMin: Math.floor(root.ambitusMin)
        ambitusMax: Math.ceil(root.ambitusMax)
        ambitusStartX: root.staffPosX + root.ambitusOffset + root._ambitusMarginX
        ambitusWidth: (root.staffWidth - root.ambitusOffset) - root._ambitusMarginX * 2
        lineSpacing: root.lineSpacing
        lineThickness: root.lineThickness
        lineColor: root.lineColor
        clef: root.clef
        octaveOffset: root.octaveOffset
        showOnlyNaturals: (ambitusConfig.noteFilter === "natural" || ambitusConfig.noteFilter === undefined)
        noteScale: configController ? configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "ambitus", "noteSize"], 0.15) : 0.15
        noteColor: {
            if (ambitusConfig.noteColor) {
                var c = Qt.color(ambitusConfig.noteColor)
                return Qt.rgba(c.r, c.g, c.b, c.a)
            }
            return Qt.rgba(1, 1, 1, 0.9)
        }
        showDebugLabels: configController ? configController.getConfigValue("displayConfig.components.musicalStaff.noteName.visible", false) : false
    }

    // Curseur 2D (Phase 2.5) — barre verticale + pastille sur la note actuelle
    // N'afficher que quand la largeur est prête pour éviter un flash à gauche au chargement
    NoteCursor2D {
        debug: !root.configController
        visible: {
            if (root.staffWidth < 150) return false
            var aw = (root.staffWidth - root.ambitusOffset) - root._ambitusMarginX * 2
            if (aw <= 0) return false
            if (!configController) return root.showCursor
            var dummy = configController.updateCounter
            return root.showCursor && configController.getConfigValue("displayConfig.components.musicalStaff.cursor.visible", true)
        }
        currentNoteMidi: root.currentNoteMidi
        centerY: root._centerY
        ambitusStartX: root.staffPosX + root.ambitusOffset + root._ambitusMarginX
        ambitusWidth: (root.staffWidth - root.ambitusOffset) - root._ambitusMarginX * 2
        ambitusMin: Math.floor(root.ambitusMin)
        ambitusMax: Math.ceil(root.ambitusMax)
        lineSpacing: root.lineSpacing
        lineThickness: root.lineThickness
        clef: root.clef
        octaveOffset: root.octaveOffset
        cursorColor: {
            if (configController) {
                var dummy = configController.updateCounter
                var colorValue = configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "color"], "#FF3333")
                if (typeof colorValue === "string") {
                    var c = Qt.color(colorValue)
                    return Qt.rgba(c.r, c.g, c.b, c.a)
                }
                if (Array.isArray(colorValue))
                    return Qt.rgba(colorValue[0], colorValue[1], colorValue[2], colorValue[3])
            }
            return Qt.rgba(1, 0.2, 0.2, 0.8)
        }
        cursorWidth: configController ? configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "width"], 3) : 6
        cursorOffsetY: configController ? configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "offsetY"], 30) : 30
        showNoteHighlight: configController ? configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "showNoteHighlight"], true) : true
        highlightColor: {
            if (configController) {
                var dummy = configController.updateCounter
                var colorValue = configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "highlightColor"], "#FFFF00")
                if (typeof colorValue === "string") {
                    var c = Qt.color(colorValue)
                    return Qt.rgba(c.r, c.g, c.b, c.a)
                }
                if (Array.isArray(colorValue))
                    return Qt.rgba(colorValue[0], colorValue[1], colorValue[2], colorValue[3])
            }
            return Qt.rgba(1, 1, 0, 0.6)
        }
        highlightSize: configController ? configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "highlightSize"], 0.25) : 0.25
    }

    // Barre de progression 2D (Phase 2.6)
    NoteProgressBar2D {
        visible: {
            if (!configController) return root.showProgressBar
            var dummy = configController.updateCounter
            return root.showProgressBar && configController.getConfigValue("displayConfig.components.musicalStaff.progressBar.visible", true)
        }
        currentNoteMidi: root.currentNoteMidi
        ambitusMin: Math.floor(root.ambitusMin)
        ambitusMax: Math.ceil(root.ambitusMax)
        barStartX: root.staffPosX + root.ambitusOffset + root._ambitusMarginX
        barWidth: (root.staffWidth - root.ambitusOffset) - root._ambitusMarginX * 2
        centerY: root._centerY
        lineSpacing: root.lineSpacing
        clef: root.clef
        octaveOffset: root.octaveOffset
        barHeight: progressConfig.barHeight || 5
        barOffsetY: progressConfig.barOffsetY || 30
        backgroundColor: {
            if (progressConfig.colors && progressConfig.colors.background) {
                var color = Qt.color(progressConfig.colors.background)
                return Qt.rgba(color.r, color.g, color.b, color.a)
            }
            return Qt.rgba(0.2, 0.2, 0.2, 0.5)
        }
        progressColor: {
            if (progressConfig.colors && progressConfig.colors.progress) {
                var color = Qt.color(progressConfig.colors.progress)
                return Qt.rgba(color.r, color.g, color.b, color.a)
            }
            return Qt.rgba(0.2, 0.8, 0.2, 0.8)
        }
        cursorColor: {
            if (progressConfig.colors && progressConfig.colors.cursor) {
                var color = Qt.color(progressConfig.colors.cursor)
                return Qt.rgba(color.r, color.g, color.b, color.a)
            }
            return Qt.rgba(1, 1, 1, 0.9)
        }
        cursorSize: progressConfig.cursorSize || 10
        showPercentage: progressConfig.showPercentage !== false
    }
}
