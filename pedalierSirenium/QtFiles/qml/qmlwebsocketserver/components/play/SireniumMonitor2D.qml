import QtQuick
import QtQuick.Layouts

// Ce que joue le sirenium, avant harmonisation : la note tenue, sa place sur
// l'ambitus, et l'ouverture du volet obturateur. Se lit à côté du cartouche
// d'accord — à gauche la note source, à droite ce que l'harmoniseur en fait.
//
// Notes NEUTRES comme dans ChordCartouche2D : la couleur reste réservée à
// l'identité des sirènes. La présence d'une note passe par l'opacité.
Item {
    id: root

    property int note: 0            // hauteur MIDI — c'est elle qui place le curseur
    property int velocity: 0        // 0 = rien de tenu ; pilote le volet obturateur

    // Ambitus du sirenium : 3 octaves à partir de Do2.
    property int ambitusLow: 48
    property int ambitusRange: 36

    implicitHeight: 54
    implicitWidth: 156

    // Convention française, Do3 = MIDI 60 (comme le clavier de la vue config).
    readonly property var _names: ["Do", "Do♯", "Ré", "Ré♯", "Mi", "Fa", "Fa♯", "Sol", "Sol♯", "La", "La♯", "Si"]
    readonly property bool _sounding: velocity > 1   // vélocité 1 = note fantôme, moteur en rotation mais muet
    readonly property string _noteName: _names[((note % 12) + 12) % 12]
    readonly property int _octave: Math.floor(note / 12) - 2
    // Le curseur suit la note, pas un signal continu : une note hors ambitus
    // vient buter contre l'extrémité plutôt que de disparaître.
    readonly property real _cursorFrac: Math.max(0, Math.min(1, (note - ambitusLow) / ambitusRange))
    readonly property real _shutterFrac: Math.max(0, Math.min(1, velocity / 127))

    // Do2 en bas, Do5 en haut : l'axe est inversé par rapport aux coordonnées.
    function _yForNote(n, h) { return h * (1 - (n - ambitusLow) / ambitusRange); }

    RowLayout {
        anchors.fill: parent
        spacing: 10

        ColumnLayout {
            spacing: 1
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: "SIRENIUM"
                color: "#3B4855"
                font.family: "monospace"; font.pixelSize: 8; font.letterSpacing: 1.2
            }
            RowLayout {
                spacing: 2
                // La note occupe une largeur fixe : elle ne doit pas faire danser
                // la mise en page à chaque changement de nom.
                Text {
                    text: root.velocity > 0 ? root._noteName : "—"
                    color: "#FFFFFF"
                    opacity: root._sounding ? 1.0 : 0.45
                    font.family: "monospace"; font.pixelSize: 17; font.bold: true
                    Layout.minimumWidth: 42
                }
                Text {
                    text: root.velocity > 0 ? String(root._octave) : ""
                    color: "#C7D2DC"
                    opacity: root._sounding ? 1.0 : 0.45
                    font.family: "monospace"; font.pixelSize: 11
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 2
                }
            }
        }

        // Le curseur sur l'ambitus : piste verticale couvrant les 3 octaves, Do2
        // en bas, Do5 en haut. Un marqueur ponctuel, pas un remplissage — on lit
        // une hauteur, pas un niveau. Les traits marquent les Do intermédiaires.
        Item {
            id: gauge
            Layout.preferredWidth: 12
            Layout.fillHeight: true
            Layout.topMargin: 6
            Layout.bottomMargin: 6

            Rectangle {   // piste
                anchors.horizontalCenter: parent.horizontalCenter
                width: 3
                height: parent.height
                radius: 1.5
                color: "#212B36"
            }

            Rectangle {   // repère Do3
                anchors.horizontalCenter: parent.horizontalCenter
                y: root._yForNote(60, gauge.height) - 0.5
                width: 9; height: 1
                color: "#3B4855"
            }

            Rectangle {   // repère Do4
                anchors.horizontalCenter: parent.horizontalCenter
                y: root._yForNote(72, gauge.height) - 0.5
                width: 9; height: 1
                color: "#3B4855"
            }

            Rectangle {   // le curseur
                anchors.horizontalCenter: parent.horizontalCenter
                // Centré sur la position, mais jamais débordant de la piste :
                // aux deux extrémités de l'ambitus il vient affleurer le bout.
                y: Math.max(0, Math.min(gauge.height - height,
                                        gauge.height * (1 - root._cursorFrac) - height / 2))
                // Franchement plus épais que la piste : c'est l'information qu'on
                // vient chercher du regard, elle ne doit pas se confondre avec elle.
                width: 15; height: 4
                radius: 2
                color: "#FFFFFF"
                opacity: root._sounding ? 1.0 : 0.7
                visible: root.velocity > 0   // sans note tenue, aucune hauteur à montrer
                Behavior on y { NumberAnimation { duration: 60 } }
            }
        }

        // Le volet obturateur : une fente qui s'ouvre depuis le centre à mesure
        // que la vélocité monte. Fermée = rien ne sort, grande ouverte = 127.
        Item {
            id: shutter
            Layout.preferredWidth: 14
            Layout.fillHeight: true
            Layout.topMargin: 6
            Layout.bottomMargin: 6

            Rectangle {   // le boîtier
                anchors.fill: parent
                color: "transparent"
                border.color: "#212B36"
                border.width: 1
                radius: 2
            }

            Rectangle {   // la lumière qui passe
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 4
                height: root._shutterFrac * (parent.height - 4)
                y: (parent.height - height) / 2
                radius: 1
                color: "#C7D2DC"
                opacity: root._sounding ? 1.0 : 0.35
                Behavior on height { NumberAnimation { duration: 60 } }
            }
        }
    }
}
