import QtQuick

// Marque de mode d'une sirène dans une scène. Couleur = identité de la sirène ;
// forme = mode de lecture. Ce qui boucle est rond, ce qui passe une fois est droit.
//   play    : rond plein
//   stop    : rond creux (matériel présent, ne tourne pas)
//   mute    : rond plein éteint
//   solo    : rond plein cerclé
//   oneshot : un trait (ne revient pas)
//   empty   : contour mort
Item {
    id: root
    property color markColor: "#FFFFFF"
    property string mode: "empty"

    implicitWidth: 11
    implicitHeight: 11

    // cercle extérieur du solo
    Rectangle {
        visible: root.mode === "solo"
        anchors.centerIn: parent
        width: 15; height: 15; radius: 7.5
        color: "transparent"
        border.width: 1.5
        border.color: root.markColor
    }

    Rectangle {
        id: dot
        anchors.centerIn: parent
        width: 11
        height: root.mode === "oneshot" ? 3 : 11
        radius: root.mode === "oneshot" ? 1 : width / 2
        color: (root.mode === "play" || root.mode === "mute" || root.mode === "solo")
               ? root.markColor : "transparent"
        opacity: root.mode === "mute" ? 0.28 : 1
        border.width: root.mode === "stop" ? 1.5 : (root.mode === "empty" ? 1 : 0)
        border.color: root.mode === "stop" ? root.markColor : "#212B36"
    }
}
