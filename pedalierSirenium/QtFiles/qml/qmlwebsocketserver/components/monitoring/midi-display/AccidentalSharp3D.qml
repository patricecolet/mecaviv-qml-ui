import QtQuick
import QtQuick3D

Node {
    id: sharp
    // Taille globale du dièse
    property real size: 0.6
    property color color: "#FFFFFF"
    // Épaisseur des traits
    property real stroke: Math.max(0.05, size * 0.14)
    // Écart horizontal entre les deux traits verticaux (nettement séparés)
    property real gap: size * 10

    // Deux traits verticaux
    Model {
        source: "#Cube"
        scale: Qt.vector3d(stroke, size, stroke)
        position: Qt.vector3d(-gap * 2, 0, 0.01)
        materials: DefaultMaterial { diffuseColor: sharp.color }
    }
    Model {
        source: "#Cube"
        scale: Qt.vector3d(stroke, size, stroke)
        position: Qt.vector3d(gap * 2, 0, 0.02)
        materials: DefaultMaterial { diffuseColor: sharp.color }
    }

    // Deux traits horizontaux (sans inclinaison)
    Model {
        source: "#Cube"
        scale: Qt.vector3d(size * 0.95, stroke, stroke)
        position: Qt.vector3d(0, size * 15, 0.03)
        materials: DefaultMaterial { diffuseColor: sharp.color }
    }
    Model {
        source: "#Cube"
        scale: Qt.vector3d(size * 0.95, stroke, stroke)
        position: Qt.vector3d(0, -size * 15, 0.04)
        materials: DefaultMaterial { diffuseColor: sharp.color }
    }
}


