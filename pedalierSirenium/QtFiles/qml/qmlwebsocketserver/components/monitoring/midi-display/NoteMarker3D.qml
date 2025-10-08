import QtQuick
import QtQuick3D

Node {
    id: noteMarker
    property int note: 60
    property real offsetSemitone: 0
    property color color: "#FFFFFF"
    property real size: 2.5

    // Visuel minimal: une sphère
    Model {
        source: "#Sphere"
        scale: Qt.vector3d(noteMarker.size, noteMarker.size, noteMarker.size)
        materials: DefaultMaterial { diffuseColor: noteMarker.color }
    }
}


