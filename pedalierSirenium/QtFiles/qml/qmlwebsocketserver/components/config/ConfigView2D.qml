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

    // les trois motifs de la sirène courante ; remplacés par ceux de la scène
    // quand la liaison WebSocket sera faite (voir PROCESSEUR_EFFET.md)
    property int sirene: 3
    property int motif: 1
    property int bpm: 108
    // les trois vitesses de la table voices, poussees en direct a la sirene root.sirene
    // (voir voices-vitesses.pd : tremolo = champ 8/CC 15, vibrato = champ 7/CC 9,
    // vibratoProgression = champ 12/CC 11). La valeur initiale, elle, vient encore de la
    // scene par defaut faute de liaison WebSocket entrante (voir PROCESSEUR_EFFET.md).
    property int tremoloSpeed: 0
    property int vibratoSpeed: 0
    property int vibratoProgression: 0
    signal vitesseEditee(string champ, int siren, int value)
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
                                        // un emplacement deja assigne se charge dans l'editeur ;
                                        // un emplacement vide recoit la sequence en cours d'edition
                                        var assignee = root.assignation[emplacement.modelData.n - 1];
                                        if (assignee > 0) {
                                            root.aEditer = assignee;
                                        } else if (root.aEditer > 0) {
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
                            text: "un emplacement assigné se charge dans l'éditeur ; un emplacement vide reçoit la séquence en cours"
                            color: "#2A3543"; font.family: "monospace"; font.pixelSize: 9
                        }
                    }

                    // vitesse du tremolo — au pied c'est l'amplitude, la vitesse vit dans la scène
                    ReglageCC {
                        Layout.fillWidth: true
                        label: "VITESSE TRÉMOLO · CC 15"
                        value: root.tremoloSpeed
                        accent: "#ff9966"
                        onEdited: function(v) {
                            root.tremoloSpeed = v;
                            root.vitesseEditee("tremolo", root.sirene, v);
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
                        Layout.preferredHeight: 220
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
                        value: root.vibratoSpeed
                        accent: "#6699FF"
                        onEdited: function(v) {
                            root.vibratoSpeed = v;
                            root.vitesseEditee("vibrato", root.sirene, v);
                        }
                    }
                    ReglageCC {
                        Layout.fillWidth: true
                        label: "ACCÉLÉRATION · CC 11"
                        value: root.vibratoProgression
                        accent: "#6699FF"
                        onEdited: function(v) {
                            root.vibratoProgression = v;
                            root.vitesseEditee("vibratoAccel", root.sirene, v);
                        }
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
