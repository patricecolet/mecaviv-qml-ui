import QtQuick
import QtQuick3D

Node {
    id: root

    property real segmentWidth: 5
    property real segmentLength: 30
    property real segmentDepth: 3
    property color segmentColor: "#ff0000"

    Model {
        source: "#Cube"
        scale: Qt.vector3d(root.segmentWidth / 100, root.segmentLength / 100, root.segmentDepth / 100)
        materials: [
            DefaultMaterial {
                diffuseColor: root.segmentColor
                specularAmount: 0.8       // Augmenter la spécularité pour un effet brillant
                specularRoughness: 0.1    // Surface lisse pour plus de brillance
                opacity: 1.0
            }
        ]
    }
}
