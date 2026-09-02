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
    property int bpm: 108
    property int aEditer: 1
    property var assignation: [1, 2, 0]     // seq assignee a bouton1, bouton2, 1+2
    function nouvelleSequence() {
        var b = bibliotheque.slice();
        var n = 1;
        for (var i = 0; i < b.length; i++) n = Math.max(n, b[i].index + 1);
        b.push({ index: n, division: 4, vitesse: 1, blocs: 1, pas: [] });
        bibliotheque = b;
        aEditer = n;
    }
    function _sequence(i) {
        for (var k = 0; k < bibliotheque.length; k++) if (bibliotheque[k].index === i) return bibliotheque[k];
        return { index: 0, division: 4, vitesse: 1, blocs: 1, pas: [] };
    }
    function _enregistre(i, seq) {
        var b = bibliotheque.slice();
        for (var k = 0; k < b.length; k++) {
            if (b[k].index === i)
                b[k] = { index: i, division: seq.division, vitesse: seq.vitesse,
                         blocs: seq.blocs, pas: seq.pas };
        }
        bibliotheque = b;
    }

    property var bibliotheque: [
        { index: 1, division: 4, vitesse: 1, blocs: 1, pas: [
            { n: 0,  velocite: 127, hauteur: 0,  gate: 4, attack: 0, release: 0 },
            { n: 4,  velocite: 100, hauteur: 2,  gate: 2, attack: 0, release: 0 },
            { n: 8,  velocite: 90,  hauteur: 0,  gate: 4, attack: 0, release: 0 },
            { n: 12, velocite: 70,  hauteur: -3, gate: 3, attack: 0, release: 0 }
        ] },
        { index: 2, division: 3, vitesse: 1, blocs: 1, pas: [
            { n: 0, velocite: 110, hauteur: 0,  gate: 3, attack: 0, release: 0 },
            { n: 2, velocite: 70,  hauteur: -3, gate: 1, attack: 0, release: 0 },
            { n: 6, velocite: 110, hauteur: 0,  gate: 3, attack: 0, release: 0 },
            { n: 9, velocite: 70,  hauteur: 5,  gate: 0, attack: 0, release: 0 }
        ] },
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
        anchors.margins: 20
        spacing: 12

        PedalboardPortrait2D {
            id: portrait
            Layout.fillWidth: true
            Layout.preferredHeight: 150
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

        // ---- pédale A : la bibliothèque, les trois emplacements, l'éditeur
        ColumnLayout {
            visible: root.selKind === "expr" && root.selIndex === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // les trois emplacements, dans l'ordre des combinaisons de boutons
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: "SIRÈNE " + root.sirene
                    color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.5
                }
                Repeater {
                    model: [{ n: 1, lib: "bouton 1" }, { n: 2, lib: "bouton 2" }, { n: 3, lib: "1 + 2" }]
                    delegate: Rectangle {
                        id: emplacement
                        required property var modelData
                        Layout.preferredWidth: 118
                        Layout.preferredHeight: 30
                        radius: 3
                        color: root.motif === modelData.n ? "#243040" : "#131A24"
                        border.color: root.motif === modelData.n ? "#6699FF" : "#1E2833"
                        border.width: 1
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: emplacement.modelData.lib
                                color: "#64737F"; font.family: "monospace"; font.pixelSize: 9
                            }
                            Text {
                                text: root.assignation[emplacement.modelData.n - 1] > 0
                                      ? "séq " + root.assignation[emplacement.modelData.n - 1] : "—"
                                color: root.motif === emplacement.modelData.n ? "#FFFFFF" : "#4A5A6B"
                                font.family: "monospace"; font.pixelSize: 11; font.bold: true
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root.aEditer > 0) {
                                    var a = root.assignation.slice();
                                    a[emplacement.modelData.n - 1] = root.aEditer;
                                    root.assignation = a;
                                }
                                root.motif = emplacement.modelData.n;
                            }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "toucher un emplacement lui assigne la séquence choisie"
                    color: "#2A3543"; font.family: "monospace"; font.pixelSize: 9
                }
            }

            // la bibliothèque
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: "BIBLIOTHÈQUE"
                    color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.5
                }
                Repeater {
                    model: root.bibliotheque
                    delegate: Rectangle {
                        id: vignette
                        required property var modelData
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 30
                        radius: 3
                        color: root.aEditer === modelData.index ? "#6699FF" : "#131A24"
                        border.color: root.aEditer === modelData.index ? "#8FB4FF" : "#1E2833"
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: vignette.modelData.index
                            color: root.aEditer === vignette.modelData.index ? "#0E141B" : "#64737F"
                            font.family: "monospace"; font.pixelSize: 12; font.bold: true
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.aEditer = vignette.modelData.index }
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 30
                    radius: 3
                    color: "#131A24"
                    border.color: "#243040"; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "+"; color: "#64737F"; font.family: "monospace"; font.pixelSize: 15
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.nouvelleSequence() }
                }
                Item { Layout.fillWidth: true }
            }

            // l'éditeur de la séquence choisie
            SequenceEditor2D {
                id: editeur
                Layout.fillWidth: true
                Layout.fillHeight: true
                pas: root._sequence(root.aEditer).pas
                division: root._sequence(root.aEditer).division
                vitesse: root._sequence(root.aEditer).vitesse
                blocs: root._sequence(root.aEditer).blocs
                seqIndex: root.aEditer
                actif: true
                bpm: root.bpm
                enJeu: root.assignation[root.motif - 1] === root.aEditer
                onSequenceModifiee: function (seq) { root._enregistre(root.aEditer, seq); }
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
