import QtQuick
import QtQuick.Shapes

// Anneau 2D : piste + arc de progression, départ à midi, sens horaire.
// Équivalent QML des anneaux SVG des maquettes.
// La couleur porte l'identité de la sirène ; l'état passe par la progression,
// la luminance (halo) et l'opacité — jamais par la couleur.
Item {
    id: root

    property color ringColor: "#66E4F2"
    property color trackColor: "#212B36"
    property real progress: 0.0        // 0..1
    property real lineWidth: 5
    property bool showHalo: false       // pulsation blanche (enregistrement)
    property real haloOpacity: 0.0

    readonly property real _r: (Math.min(width, height) - lineWidth) / 2
    readonly property real _cx: width / 2
    readonly property real _cy: height / 2

    // Piste (cercle complet, sourd)
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            PathAngleArc {
                centerX: root._cx; centerY: root._cy
                radiusX: root._r; radiusY: root._r
                startAngle: 0; sweepAngle: 360
            }
        }
    }

    // Halo blanc (luminance) — pulsation d'enregistrement
    Shape {
        anchors.fill: parent
        visible: root.showHalo && root.haloOpacity > 0
        opacity: root.haloOpacity
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "#FFFFFF"
            strokeWidth: root.lineWidth + 6
            fillColor: "transparent"
            PathAngleArc {
                centerX: root._cx; centerY: root._cy
                radiusX: root._r; radiusY: root._r
                startAngle: 0; sweepAngle: 360
            }
        }
    }

    // Arc de progression — depuis midi (-90°), sens horaire
    Shape {
        anchors.fill: parent
        visible: root.progress > 0.0001
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.ringColor
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: root._cx; centerY: root._cy
                radiusX: root._r; radiusY: root._r
                startAngle: -90
                sweepAngle: 360 * Math.max(0, Math.min(1, root.progress))
            }
        }
    }
}
