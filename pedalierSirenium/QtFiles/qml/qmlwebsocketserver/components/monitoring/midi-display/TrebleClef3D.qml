import QtQuick
import QtQuick3D
import QtQuick.Shapes

// Clé de sol rendue en 2D (Shape) puis texturée sur un quad 3D
Node {
    id: root
    // Hauteur (en unités scène) du quad 3D
    property real size: 3.0
    // Espacement des lignes de portée pour adapter l'épaisseur/échelle
    property real staffSpacing: 1.0
    property color color: "#FFFFFF"

    // Résolution de rendu de la texture (statique → coût négligeable)
    property int texWidth: 256
    property int texHeight: 512

    // Épaisseur du trait vectoriel (pixels) selon staffSpacing
    readonly property real strokePx: Math.max(2, staffSpacing * 6)

    // 2D vectoriel (offscreen)
    Item {
        id: canvas
        width: root.texWidth
        height: root.texHeight
        visible: false

        Shape {
            anchors.fill: parent
            antialiasing: true

            // Tige sinueuse (S) de la clé de sol
            ShapePath {
                strokeWidth: root.strokePx
                strokeColor: root.color
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: canvas.width * 0.52
                startY: canvas.height * 0.05

                // Descente en courbe vers le centre
                PathCubic {
                    x: canvas.width * 0.40; y: canvas.height * 0.35
                    control1X: canvas.width * 0.52; control1Y: canvas.height * 0.18
                    control2X: canvas.width * 0.45; control2Y: canvas.height * 0.30
                }
                // Croisement au centre
                PathCubic {
                    x: canvas.width * 0.62; y: canvas.height * 0.52
                    control1X: canvas.width * 0.35; control1Y: canvas.height * 0.40
                    control2X: canvas.width * 0.58; control2Y: canvas.height * 0.48
                }
                // Remontée haute
                PathCubic {
                    x: canvas.width * 0.50; y: canvas.height * 0.80
                    control1X: canvas.width * 0.70; control1Y: canvas.height * 0.58
                    control2X: canvas.width * 0.60; control2Y: canvas.height * 0.72
                }
                // Petite queue
                PathCubic {
                    x: canvas.width * 0.42; y: canvas.height * 0.94
                    control1X: canvas.width * 0.45; control1Y: canvas.height * 0.86
                    control2X: canvas.width * 0.44; control2Y: canvas.height * 0.92
                }
            }

            // Volute (spirale simplifiée) au centre
            ShapePath {
                strokeWidth: root.strokePx
                strokeColor: root.color
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: canvas.width * 0.60
                startY: canvas.height * 0.50
                PathCubic {
                    x: canvas.width * 0.48; y: canvas.height * 0.54
                    control1X: canvas.width * 0.58; control1Y: canvas.height * 0.56
                    control2X: canvas.width * 0.52; control2Y: canvas.height * 0.56
                }
                PathCubic {
                    x: canvas.width * 0.54; y: canvas.height * 0.62
                    control1X: canvas.width * 0.45; control1Y: canvas.height * 0.56
                    control2X: canvas.width * 0.48; control2Y: canvas.height * 0.62
                }
                PathCubic {
                    x: canvas.width * 0.62; y: canvas.height * 0.58
                    control1X: canvas.width * 0.60; control1Y: canvas.height * 0.62
                    control2X: canvas.width * 0.61; control2Y: canvas.height * 0.60
                }
            }
        }
    }

    Texture {
        id: tex
        sourceItem: canvas
    }

    // Quad 3D texturé (cube très fin) — pas d'opacité forcée
    Model {
        id: quad
        source: "#Cube"
        // Ratio selon la texture 2:1 → width = size * (w/h)
        scale: Qt.vector3d(root.size * canvas.width / canvas.height, root.size, 0.01)
        materials: DefaultMaterial {
            diffuseMap: tex
        }
        // Légère avance en Z pour éviter Z-fighting avec les lignes
        position: Qt.vector3d(0, 0, 0.9)
        receivesShadows: false
        castsShadows: false
    }
}


