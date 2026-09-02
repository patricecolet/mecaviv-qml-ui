pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Écran de configuration : on touche un contrôle sur le portrait, le panneau du
// bas dit ce qu'il fait. Depuis la refonte des pédales, chacune a une affectation
// fixe — il n'y a plus de matrice de modulation à éditer, mais trois motifs par
// sirène pour la pédale A.
Item {
    id: root

    property string selKind: "expr"
    property int selIndex: 0

    // les trois motifs de la sirène courante ; remplacés par ceux de la scène
    // quand la liaison WebSocket sera faite (voir PROCESSEUR_EFFET.md)
    property int sirene: 3
    property int motif: 1
    property var sequences: [
        { index: 1, longueur: 1920, pas: [
            { tick: 0,    velocite: 127, hauteur: 0,  gate: 240, attack: 20, release: 30 },
            { tick: 480,  velocite: 100, hauteur: 2,  gate: 120, attack: 10, release: 40 },
            { tick: 960,  velocite: 90,  hauteur: 0,  gate: 240, attack: 20, release: 30 },
            { tick: 1440, velocite: 70,  hauteur: -3, gate: 180, attack: 15, release: 25 }
        ] },
        { index: 2, longueur: 960, pas: [
            { tick: 0,   velocite: 110, hauteur: 0,  gate: 200, attack: 15, release: 25 },
            { tick: 240, velocite: 70,  hauteur: -3, gate: 100, attack: 25, release: 35 },
            { tick: 480, velocite: 110, hauteur: 0,  gate: 200, attack: 15, release: 25 },
            { tick: 720, velocite: 70,  hauteur: 5,  gate: 100, attack: 25, release: 35 }
        ] },
        { index: 0, longueur: 1920, pas: [] }
    ]

    readonly property var _nomPedale: ["A", "B", "C"]

    function _titre() {
        if (selKind === "expr") return "Pédale d'expression " + _nomPedale[selIndex];
        if (selKind === "push") return "Poussoir " + (selIndex + 1);
        if (selKind === "sw")   return "Interrupteur — pédale " + _nomPedale[Math.floor(selIndex / 10)];
        return "Touche du clavier";
    }
    function _sousTitre() {
        if (selKind === "expr") return ["motif et trémolo · CC 47", "vibrato · CC 48", "degré dans la gamme · CC 49"][selIndex];
        if (selKind === "push") return "interrupteur · assignable";
        if (selKind === "sw")   return selIndex < 10 ? "choix du motif" : "portée : toutes ou la sélectionnée";
        return "sensible à la vélocité";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 20

        PedalboardPortrait2D {
            id: portrait
            Layout.fillWidth: true
            Layout.preferredHeight: 300
            selKind: root.selKind
            selIndex: root.selIndex
            onSelected: function(kind, index) {
                root.selKind = kind;
                root.selIndex = index;
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#171F28" }

        RowLayout {
            spacing: 14
            Text {
                text: root._titre()
                color: "#FFFFFF"; font.family: "monospace"; font.pixelSize: 20; font.bold: true
            }
            Text {
                text: root._sousTitre()
                color: "#3B4855"; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 1.4
                Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 3
            }
        }

        // ---- pédale A : les trois motifs de la sirène, plus le trémolo
        ColumnLayout {
            visible: root.selKind === "expr" && root.selIndex === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Text {
                text: "sirène " + root.sirene + " — les interrupteurs choisissent : "
                      + (root.motif === 0 ? "trémolo" : "motif " + root.motif)
                color: "#64737F"; font.family: "monospace"; font.pixelSize: 11
            }

            Repeater {
                model: root.sequences
                delegate: SequenceEditor2D {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    steps: modelData.pas
                    lengthTicks: modelData.longueur
                    seqIndex: modelData.index
                    actif: root.motif === index + 1
                }
            }
        }

        // ---- pédales B et C : une ligne de description, le réglage vit dans la scène
        Text {
            visible: root.selKind === "expr" && root.selIndex > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignTop
            text: root.selIndex === 1
                  ? "Profondeur du vibrato au pied — CC 1 des sirènes. La vitesse vient de la scène, champ vibratoSpeed de chaque voix, et part en CC 9 au chargement.\n\nL'interrupteur 45 décide si la pédale agit sur toutes les sirènes ou sur la seule sélectionnée."
                  : "Transposition dans la gamme — la position choisit un degré, et la course s'adapte au mode : elle vaut une octave, quel que soit le nombre de degrés.\n\nUne hystérésis empêche l'harmonie de clignoter à la frontière entre deux degrés. L'interrupteur 46 décide de la portée."
            color: "#64737F"; font.family: "monospace"; font.pixelSize: 13; lineHeight: 1.5
        }

        // ---- le reste
        Text {
            visible: root.selKind !== "expr"
            Layout.fillWidth: true
            Layout.fillHeight: true
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignTop
            text: root.selKind === "push"
                  ? "Transport de la sirène : appui court pour lancer ou arrêter, appui long pour effacer le clip."
                  : root.selKind === "key"
                    ? "Les sept touches blanches sélectionnent une sirène. Les noires et le do aigu restent libres."
                    : root.selIndex < 10
                      ? "Les deux interrupteurs de la pédale A composent le motif : aucun enfoncé donne le trémolo, les trois autres combinaisons appellent les motifs 1 à 3 de chaque sirène."
                      : "Monté sur la pédale, actionnable sans lever le pied. Il élargit l'effet à toutes les sirènes au lieu de la seule sélectionnée."
            color: "#64737F"; font.family: "monospace"; font.pixelSize: 13; lineHeight: 1.5
        }
    }
}
