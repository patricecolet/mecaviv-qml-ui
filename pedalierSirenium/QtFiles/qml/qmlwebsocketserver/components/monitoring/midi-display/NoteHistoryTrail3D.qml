import QtQuick
import QtQuick3D

Node {
    id: trail
    property var values: [] // [{note, offsetSemitone, age}]
    property int maxLen: 64
    property color color: "#FFFFFF"
}


