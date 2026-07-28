import QtQuick
import QtQuick.Layouts

// Ce que joue le sirenium, avant harmonisation : la note tenue et son bend.
// Se lit à côté du cartouche d'accord — à gauche la note source, à droite ce que
// l'harmoniseur en fait.
//
// Notes NEUTRES comme dans ChordCartouche2D : la couleur reste réservée à
// l'identité des sirènes. La présence d'une note passe par l'opacité.
Item {
    id: root

    property int note: 0            // hauteur MIDI
    property int velocity: 0        // 0 = rien de tenu
    property real bend: 4096        // brut, tel qu'il arrive sur $0.harmoniseur.in
    property int bendMax: 8192      // course complète : 0 en bas, 4096 au repos, 8192 en haut

    implicitHeight: 54
    implicitWidth: 132

    // Convention française, Do3 = MIDI 60 (comme le clavier de la vue config).
    readonly property var _names: ["Do", "Do♯", "Ré", "Ré♯", "Mi", "Fa", "Fa♯", "Sol", "Sol♯", "La", "La♯", "Si"]
    readonly property bool _sounding: velocity > 1   // vélocité 1 = note fantôme, moteur en rotation mais muet
    readonly property string _noteName: _names[((note % 12) + 12) % 12]
    readonly property int _octave: Math.floor(note / 12) - 2
    // Niveau sur la course complète, pas écart depuis un centre : la valeur
    // arrive brute, 4096 au repos tombe naturellement à mi-hauteur.
    readonly property real _bendFrac: Math.max(0, Math.min(1, bend / Math.max(1, bendMax)))

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

        // Jauge de bend : verticale, remplie depuis le bas sur toute la course.
        // Le trait à mi-hauteur marque le repos ; on lit d'un coup d'œil de quel
        // côté et de combien on s'en écarte.
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

            Rectangle {   // niveau, depuis le bas
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: 3
                radius: 1.5
                color: "#C7D2DC"
                opacity: root._sounding ? 1.0 : 0.35
                height: root._bendFrac * gauge.height
                Behavior on height { NumberAnimation { duration: 60 } }
            }

            Rectangle {   // repère du repos, à mi-course
                anchors.horizontalCenter: parent.horizontalCenter
                y: gauge.height / 2 - 0.5
                width: 9; height: 1
                color: "#3B4855"
            }
        }
    }
}
