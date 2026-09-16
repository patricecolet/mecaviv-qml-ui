pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Écran de configuration : on touche un contrôle sur le portrait, le panneau du
// bas dit ce qu'il fait. Depuis la refonte des pédales, chacune a une affectation
// fixe — il n'y a plus de matrice de modulation à éditer, mais trois motifs par
// sirène pour la pédale A.
Item {
    id: root

    // Une piste horizontale 0-127 : le pied donne l'amplitude (voir PROCESSEUR_EFFET.md
    // §1), la vitesse se règle ici, dans la scène.
    component ReglageCC: RowLayout {
        id: reglage
        property string label: ""
        property int value: 0
        property color accent: "#6699FF"
        signal edited(int v)
        spacing: 10
        Text {
            text: reglage.label
            color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.2
            Layout.preferredWidth: 190
        }
        Rectangle {
            id: piste
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            radius: 3
            color: "#131A24"
            border.color: "#1E2833"; border.width: 1
            Rectangle {
                width: piste.width * (reglage.value / 127)
                height: parent.height
                radius: 3
                color: reglage.accent
            }
            MouseArea {
                anchors.fill: parent
                function pose(mx) { reglage.edited(Math.max(0, Math.min(127, Math.round(mx / piste.width * 127)))); }
                onPressed: function(mouse) { pose(mouse.x); }
                onPositionChanged: function(mouse) { if (pressed) pose(mouse.x); }
            }
        }
        Text {
            text: reglage.value
            color: "#64737F"; font.family: "monospace"; font.pixelSize: 10
            Layout.preferredWidth: 26
        }
    }

    property string selKind: "expr"
    property int selIndex: 0

    // Tout ce que cet écran affiche vient de PD par main.qml (window.state) :
    // la sirène en mono, la ligne de sa voix dans la table voices, l'interrupteur
    // en jeu, le tempo, la bibliothèque de séquences. Rien n'est gardé ici --
    // un réglage part vers PD et c'est son écho qui met l'écran à jour.
    property int sirene: 0                 // VOICE_SELECT.siren, 0 = aucune
    property var voiceState: ({ seq1: 0, seq2: 0, seq3: 0,
                                tremoloSpeed: 0, vibratoSpeed: 0, vibratoProgression: 0 })
    property int motif: 0                  // 0 trémolo, 1..3 l'emplacement joué (43/44)
    property real bpm: 120
    property var sequences: []             // la bibliothèque telle que PD la sert
    readonly property var assignation: [voiceState.seq1, voiceState.seq2, voiceState.seq3]

    signal vitesseEditee(string champ, int siren, int value)
    signal sequenceEditee(int emplacement, int siren, int index)
    signal sequenceModifiee(int index, var seq)
    signal nouvelleSequenceDemandee()

    // le seul état propre à l'écran : quelle séquence est ouverte dans l'éditeur.
    // 0 = aucune (l'éditeur est muet) ; dès que la bibliothèque arrive, la
    // première. Une séquence ne s'édite ni ne s'écrit sous l'index 0, qui veut
    // dire « pas de séquence » dans la table voices.
    property int aEditer: 0
    onSequencesChanged: {
        if (sequences.length === 0) { aEditer = 0; return; }
        for (var k = 0; k < sequences.length; k++) if (sequences[k].index === aEditer) return;
        aEditer = sequences[0].index;
    }
    function _sequence(i) {
        for (var k = 0; k < sequences.length; k++) if (sequences[k].index === i) return sequences[k];
        return { index: 0, division: 4, vitesse: 1, blocs: 1, pas: [] };
    }

    readonly property var _nomPedale: ["A", "B", "C"]

    function _titre() {
        if (selKind === "push") return "Poussoir " + (selIndex + 1);
        if (selKind === "sw")   return "Interrupteur — pédale " + _nomPedale[Math.floor(selIndex / 10)];
        if (selKind === "expr") return "";
        return "Touche du clavier";
    }
    function _sousTitre() {
        if (selKind === "push") return "interrupteur · assignable";
        if (selKind === "sw")   return selIndex < 10 ? "choix du motif" : "portée : toutes ou la sélectionnée";
        if (selKind === "expr") return "";
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
            visible: root.selKind !== "expr"
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

        // Une rangée = une pédale : nom, rôle et réglages toujours visibles, pour comparer
        // les trois d'un coup d'œil plutôt que de naviguer entre elles.
        component RangeePedale: ColumnLayout {
            id: rangee
            property string nom: ""
            property string role: ""
            property color accent: "#6699FF"
            Layout.fillWidth: true
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle { Layout.preferredWidth: 4; Layout.preferredHeight: 20; radius: 2; color: rangee.accent }
                Text {
                    text: rangee.nom
                    color: "#FFFFFF"; font.family: "monospace"; font.pixelSize: 15; font.bold: true
                }
                Text {
                    text: rangee.role
                    color: "#3B4855"; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 1.2
                }
            }
        }

        Flickable {
            visible: root.selKind === "expr"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: rangees.implicitHeight
            ColumnLayout {
                id: rangees
                width: parent.width
                spacing: 18

                // ---- pédale A : la bibliothèque, les trois emplacements, l'éditeur
                RangeePedale {
                    nom: "PÉDALE A"; role: "motif et trémolo · CC 47"; accent: "#ff9966"

                    // les trois emplacements, dans l'ordre des combinaisons de boutons
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: root.sirene > 0 ? "SIRÈNE " + root.sirene : "AUCUNE SIRÈNE — pédale key"
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
                                        // 0 dans voices = la sequence par defaut de l'emplacement (1, 2, 3),
                                        // affichee en retrait pour dire qu'elle n'a pas ete choisie
                                        text: "séq " + (root.assignation[emplacement.modelData.n - 1] > 0
                                              ? root.assignation[emplacement.modelData.n - 1] : emplacement.modelData.n)
                                        opacity: root.assignation[emplacement.modelData.n - 1] > 0 ? 1 : 0.55
                                        color: root.motif === emplacement.modelData.n ? "#FFFFFF" : "#4A5A6B"
                                        font.family: "monospace"; font.pixelSize: 11; font.bold: true
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    // cliquer un emplacement y pose la sequence ouverte dans
                                    // l'editeur -- toujours, qu'il soit vide ou deja pris
                                    onClicked: {
                                        if (root.aEditer > 0 && root.sirene > 0)
                                            root.sequenceEditee(emplacement.modelData.n, root.sirene, root.aEditer);
                                    }
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "cliquer un emplacement y pose la séquence ouverte dans l'éditeur"
                            color: "#2A3543"; font.family: "monospace"; font.pixelSize: 9
                        }
                    }

                    // vitesse du tremolo — au pied c'est l'amplitude, la vitesse vit dans la scène
                    ReglageCC {
                        Layout.fillWidth: true
                        label: "VITESSE TRÉMOLO · CC 15"
                        value: root.voiceState.tremoloSpeed
                        accent: "#ff9966"
                        onEdited: function(v) { root.vitesseEditee("tremolo", root.sirene, v); }
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
                            model: root.sequences
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
                            MouseArea { anchors.fill: parent; onClicked: root.nouvelleSequenceDemandee() }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: root.sequences.length === 0
                            text: "aucune séquence — PD n'en a pas servi"
                            color: "#2A3543"; font.family: "monospace"; font.pixelSize: 9
                        }
                    }

                    // l'éditeur de la séquence choisie
                    SequenceEditor2D {
                        id: editeur
                        Layout.fillWidth: true
                        Layout.preferredHeight: 220
                        pas: root._sequence(root.aEditer).pas
                        division: root._sequence(root.aEditer).division
                        vitesse: root._sequence(root.aEditer).vitesse
                        blocs: root._sequence(root.aEditer).blocs
                        seqIndex: root.aEditer
                        actif: root.aEditer > 0
                        bpm: root.bpm
                        enJeu: root.motif > 0 && root.assignation[root.motif - 1] === root.aEditer
                        onSequenceModifiee: function (seq) { if (root.aEditer > 0) root.sequenceModifiee(root.aEditer, seq); }
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#171F28" }

                // ---- pédale B : description + les deux vitesses de la scène
                RangeePedale {
                    nom: "PÉDALE B"; role: "vibrato · CC 48"; accent: "#6699FF"
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "Profondeur du vibrato au pied — CC 1 des sirènes. Les deux vitesses ci-dessous viennent de la scène, champs vibratoSpeed et vibratoProgression de chaque voix. L'interrupteur 45 décide si la pédale agit sur toutes les sirènes ou sur la seule sélectionnée."
                        color: "#64737F"; font.family: "monospace"; font.pixelSize: 12; lineHeight: 1.4
                    }
                    ReglageCC {
                        Layout.fillWidth: true
                        label: "VITESSE VIBRATO · CC 9"
                        value: root.voiceState.vibratoSpeed
                        accent: "#6699FF"
                        onEdited: function(v) { root.vitesseEditee("vibrato", root.sirene, v); }
                    }
                    ReglageCC {
                        Layout.fillWidth: true
                        label: "ACCÉLÉRATION · CC 11"
                        value: root.voiceState.vibratoProgression
                        accent: "#6699FF"
                        onEdited: function(v) { root.vitesseEditee("vibratoAccel", root.sirene, v); }
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#171F28" }

                // ---- pédale C : une ligne de description, le réglage vit dans la scène
                RangeePedale {
                    nom: "PÉDALE C"; role: "degré dans la gamme · CC 49"; accent: "#99cc66"
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "Transposition dans la gamme — la position choisit un degré, et la course s'adapte au mode : elle vaut une octave, quel que soit le nombre de degrés. Une hystérésis empêche l'harmonie de clignoter à la frontière entre deux degrés. L'interrupteur 46 décide de la portée."
                        color: "#64737F"; font.family: "monospace"; font.pixelSize: 12; lineHeight: 1.4
                    }
                }
            }
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
