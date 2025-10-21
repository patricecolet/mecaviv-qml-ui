import QtQuick
import QtQuick.Shapes

Item {
    id: root

    // "treble" ou "bass"
    property string clefType: "treble"
    property color clefColor: "#DADADA"
    property real lineSpacing: 20
    property real clefOffsetX: 12
    property real clefOffsetY: 0

    // Taille globale liée à la portée (~5 lignes)
    property real clefHeight: lineSpacing * 5.2
    property real clefWidth: clefHeight * 0.5

    width: clefWidth
    height: clefHeight

    x: clefOffsetX
    y: (clefType === "treble" ? -lineSpacing : lineSpacing) + clefOffsetY - height/2

    Shape {
        anchors.fill: parent
        antialiasing: true

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.clefColor

            Path {
                startX: root.width*0.5; startY: 0
                // Clé de sol stylisée (boucles simplifiées)
                // Tige
                PathLine { x: root.width*0.5; y: root.height*0.85 }
                // Boucle basse
                PathArc { x: root.width*0.7; y: root.height*0.70; radiusX: root.width*0.30; radiusY: root.height*0.18 }
                PathArc { x: root.width*0.40; y: root.height*0.55; radiusX: root.width*0.30; radiusY: root.height*0.18 }
                PathArc { x: root.width*0.65; y: root.height*0.40; radiusX: root.width*0.25; radiusY: root.height*0.16 }
                PathArc { x: root.width*0.35; y: root.height*0.25; radiusX: root.width*0.25; radiusY: root.height*0.16 }
                PathArc { x: root.width*0.52; y: root.height*0.12; radiusX: root.width*0.20; radiusY: root.height*0.12 }
                // Fermeture vers le haut
                PathLine { x: root.width*0.52; y: 0 }
            }
        }

        // Points de la clé de fa (si clefType=bass)
        ShapePath {
            visible: root.clefType === "bass"
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.clefColor

            PathEllipse { x: root.width*0.10; y: root.height*0.35; width: root.width*0.55; height: root.height*0.55 }
        }

        ShapePath {
            visible: root.clefType === "bass"
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.clefColor
            PathEllipse { x: root.width*0.78; y: root.height*0.28; width: root.width*0.15; height: root.width*0.15 }
        }
        ShapePath {
            visible: root.clefType === "bass"
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.clefColor
            PathEllipse { x: root.width*0.78; y: root.height*0.58; width: root.width*0.15; height: root.width*0.15 }
        }
    }
}


