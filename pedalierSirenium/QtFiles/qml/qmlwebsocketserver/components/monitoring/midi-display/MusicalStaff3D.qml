import QtQuick
import QtQuick3D

Node {
    id: staff
    property string clef: "treble"
    property var ambitus: ({ min: 48, max: 84 })
    // Dimensions internes pour rester dans le panneau
    property real width: 9.2
    // Si > 0, force la hauteur et dérive l'espacement; sinon, on utilise lineSpacing
    property real height: 1.0
    property real marginX: 0.3
    property real marginY: 0.3
    // Espacement de base si height n'est pas imposé (peut être 0 pour forcer calcul via height)
    property real lineSpacing: 0
    // Dérivés: espacement et hauteur effective
    readonly property real spacing: (lineSpacing > 0 ? lineSpacing : (height > 0 ? (height - 2 * marginY) / 4 : 1.0))
    readonly property real effectiveHeight: (height > 0 ? Math.max(height, 4 * spacing + 2 * marginY) : (4 * spacing + 2 * marginY))
    readonly property real thickness: Math.max(0.01, Math.min(0.04, spacing * 0.09))
    property color lineColor: "#FFFFFF"

    // 5 lignes de base via Repeater3D (écriture compacte et lisible)
    Repeater3D {
        model: 5
        delegate: Model {
            source: "#Cube"
            // Largeur limitée au panneau, épaisseur liée à l'espacement
            scale: Qt.vector3d(staff.width - 2 * staff.marginX, staff.thickness, 0.08)
            // Positionner les 5 lignes du bas vers le haut
            position: Qt.vector3d(
                0,
                (-staff.effectiveHeight / 2 + staff.marginY) + (modelData * staff.spacing),
                0.02 + (modelData * 0.001)
            )
            materials: DefaultMaterial { diffuseColor: staff.lineColor }
        }
    }
}


