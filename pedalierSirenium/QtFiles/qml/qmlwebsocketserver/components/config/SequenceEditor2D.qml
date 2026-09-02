pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Éditeur de motif, façon boîte à rythmes : une rangée de pas qu'on allume ou
// qu'on éteint, et sous elle une réglette par pas dont le menu latéral choisit
// ce qu'elle montre — vélocité, note, gate, attack ou release.
// La tête de lecture tourne pendant l'édition : on voit ce qu'on entend.
Item {
    id: root

    // Un pas est repéré par son rang, pas par son tick : changer la division
    // garde le motif et change sa saveur, au lieu de le désaligner.
    // pas[i] = { n, velocite, hauteur, gate, attack, release }
    property var pas: []
    property int division: 4                  // pas par temps : 4 binaire, 3 ternaire
    property int vitesse: 1                   // ×1 ou ×2 par rapport au temps
    property int blocs: 1
    property int seqIndex: 0
    property bool actif: false

    // lecture
    property real phase: -1
    property int bpm: 120
    property bool enJeu: false

    // édition
    property int bloc: 0                       // le bloc affiché
    property string parametre: "velocite"

    // L'éditeur propose, il ne s'écrit pas lui-même : une assignation locale
    // casserait la liaison, et une séquence neuve garderait les pas de l'autre.
    signal sequenceModifiee(var seq)

    readonly property int _ticksParTemps: 480
    readonly property int _pasParBloc: 4 * division
    readonly property int _ticksParPas: _ticksParTemps / (division * vitesse)
    readonly property int lengthTicks: blocs * _pasParBloc * _ticksParPas
    readonly property bool _lit: enJeu && phase >= 0

    readonly property var _params: [
        { cle: "velocite", nom: "VÉL",  min: 1,   max: 127 },
        { cle: "hauteur",  nom: "NOTE", min: -12, max: 12 },
        { cle: "gate",     nom: "GATE", min: 0,   max: 16 },
        { cle: "attack",   nom: "ATK",  min: 0,   max: 127 },
        { cle: "release",  nom: "REL",  min: 0,   max: 127 }
    ]
    function _def(cle) {
        for (var i = 0; i < _params.length; i++) if (_params[i].cle === cle) return _params[i];
        return _params[0];
    }
    function _rang(n) { return (bloc * _pasParBloc) + n; }

    function _pasDe(n) {
        var r = _rang(n);
        for (var i = 0; i < pas.length; i++) if (pas[i].n === r) return pas[i];
        return null;
    }
    function _seq(nouveauxPas, div, vit, nbBlocs) {
        return { division: div, vitesse: vit, blocs: nbBlocs, pas: nouveauxPas };
    }
    function _rend(nouveauxPas) { sequenceModifiee(_seq(nouveauxPas, division, vitesse, blocs)); }

    function _bascule(n) {
        var r = _rang(n);
        var copie = pas.slice();
        for (var i = 0; i < copie.length; i++) {
            if (copie[i].n === r) { copie.splice(i, 1); _rend(copie); return; }
        }
        copie.push({ n: r, velocite: 100, hauteur: 0, gate: 4, attack: 0, release: 0 });
        copie.sort(function (a, b) { return a.n - b.n; });
        _rend(copie);
    }
    function _regle(n, fraction) {
        var p = _def(parametre);
        var v = Math.round(p.min + Math.max(0, Math.min(1, fraction)) * (p.max - p.min));
        var r = _rang(n);
        var copie = pas.slice();
        for (var i = 0; i < copie.length; i++) {
            if (copie[i].n === r) {
                var s = {};
                for (var k in copie[i]) s[k] = copie[i][k];
                s[parametre] = v;
                copie[i] = s;
                _rend(copie);
                return;
            }
        }
    }
    function _fraction(p) {
        var d = _def(parametre);
        return (p[parametre] - d.min) / (d.max - d.min);
    }
    // Changer la division garde les rangs ; ce qui dépasse le nouveau nombre de
    // blocs est coupé, sans quoi des pas resteraient joués mais invisibles.
    function _taille(div, vit, nbBlocs) {
        var max = nbBlocs * 4 * div;
        var copie = [];
        for (var i = 0; i < pas.length; i++) if (pas[i].n < max) copie.push(pas[i]);
        sequenceModifiee(_seq(copie, div, vit, nbBlocs));
    }

    NumberAnimation {
        target: root
        property: "phase"
        running: root.enJeu
        loops: Animation.Infinite
        from: 0
        to: root.lengthTicks
        duration: Math.max(200, (root.lengthTicks / root._ticksParTemps) * (60000 / Math.max(1, root.bpm)))
    }

    component Bascule: Rectangle {
        id: bascule
        property bool choisi: false
        property string libelle: ""
        signal touche()
        Layout.preferredWidth: 30
        Layout.preferredHeight: 20
        radius: 2
        color: choisi ? "#243040" : "#131A24"
        border.color: choisi ? "#6699FF" : "#1E2833"
        border.width: 1
        Text {
            anchors.centerIn: parent
            text: bascule.libelle
            color: bascule.choisi ? "#FFFFFF" : "#4A5A6B"
            font.family: "monospace"; font.pixelSize: 9; font.bold: true
        }
        MouseArea { anchors.fill: parent; onClicked: bascule.touche() }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            // ---- en-tête : la séquence, sa grille, le bloc affiché
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: root.seqIndex > 0 ? "séquence " + root.seqIndex : "vide"
                    color: root.actif ? "#FFFFFF" : "#64737F"
                    font.family: "monospace"; font.pixelSize: 13; font.bold: true
                }
                Repeater {
                    model: root.blocs
                    delegate: Rectangle {
                        id: ongletBloc
                        required property int index
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 18
                        radius: 2
                        color: root.bloc === index ? "#6699FF" : "#1A2230"
                        border.color: "#243040"; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: ongletBloc.index + 1
                            color: root.bloc === ongletBloc.index ? "#0E141B" : "#64737F"
                            font.family: "monospace"; font.pixelSize: 9
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.bloc = ongletBloc.index }
                    }
                }
                Bascule {
                    Layout.preferredWidth: 18
                    libelle: "+"
                    onTouche: root._taille(root.division, root.vitesse, root.blocs + 1)
                }
                Bascule {
                    Layout.preferredWidth: 18
                    libelle: "−"
                    onTouche: {
                        if (root.blocs > 1) {
                            if (root.bloc >= root.blocs - 1) root.bloc = root.blocs - 2;
                            root._taille(root.division, root.vitesse, root.blocs - 1);
                        }
                    }
                }

                Item { Layout.preferredWidth: 10 }
                Text {
                    text: "PAR TEMPS"
                    color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.2
                }
                Bascule {
                    choisi: root.division === 4; libelle: "4"
                    onTouche: root._taille(4, root.vitesse, root.blocs)
                }
                Bascule {
                    choisi: root.division === 3; libelle: "3"
                    onTouche: root._taille(3, root.vitesse, root.blocs)
                }
                Text {
                    text: "VITESSE"
                    color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.2
                }
                Bascule {
                    choisi: root.vitesse === 1; libelle: "×1"
                    onTouche: root._taille(root.division, 1, root.blocs)
                }
                Bascule {
                    choisi: root.vitesse === 2; libelle: "×2"
                    onTouche: root._taille(root.division, 2, root.blocs)
                }

                Item { Layout.fillWidth: true }
                Text {
                    text: root.pas.length + " pas"
                    color: "#3B4855"; font.family: "monospace"; font.pixelSize: 10
                }
            }

            // ---- la rangée de pas : on allume, on éteint
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                Layout.maximumHeight: 72
                spacing: 3
                Repeater {
                    model: root._pasParBloc
                    delegate: Rectangle {
                        id: casePas
                        required property int index
                        readonly property var pas: root._pasDe(index)
                        // gate 0 coupe aussitôt : on garde un éclat minimal, sinon
                        // la tête de lecture sauterait le pas sans qu'on la voie.
                        readonly property real duree: pas ? Math.max(root._ticksParPas / 4,
                                                                     pas.gate * root._ticksParPas / 4) : 0
                        readonly property bool sonne: root._lit && pas !== null
                                                      && root.phase >= pas.n * root._ticksParPas
                                                      && root.phase < pas.n * root._ticksParPas + duree
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 3
                        color: sonne ? "#FFD166" : (pas !== null ? "#6699FF" : "#161E29")
                        border.color: (index % root.division === 0) ? "#33465C" : "#212C3A"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 60 } }

                        Text {
                            visible: casePas.pas !== null && casePas.pas.hauteur !== 0
                            anchors.centerIn: parent
                            text: casePas.pas ? ((casePas.pas.hauteur > 0 ? "+" : "") + casePas.pas.hauteur) : ""
                            color: "#0E141B"; font.family: "monospace"; font.pixelSize: 10; font.bold: true
                        }
                        MouseArea { anchors.fill: parent; onClicked: root._bascule(casePas.index) }
                    }
                }
            }

            // ---- la réglette : une barre par pas, pour le paramètre choisi
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                Layout.maximumHeight: 150
                spacing: 3
                Repeater {
                    model: root._pasParBloc
                    delegate: Rectangle {
                        id: caseVal
                        required property int index
                        readonly property var pas: root._pasDe(index)
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "#0E141B"
                        border.color: (index % root.division === 0) ? "#243040" : "#171F28"
                        border.width: 1

                        Rectangle {
                            visible: caseVal.pas !== null
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 1
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 6
                            height: caseVal.pas ? Math.max(2, (caseVal.height - 2) * root._fraction(caseVal.pas)) : 0
                            color: "#39506E"
                        }
                        Text {
                            visible: caseVal.pas !== null && caseVal.width > 24
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 2
                            text: caseVal.pas ? caseVal.pas[root.parametre] : ""
                            color: "#64737F"; font.family: "monospace"; font.pixelSize: 8
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: caseVal.pas !== null
                            onPressed: function (m) { root._regle(caseVal.index, 1 - m.y / caseVal.height); }
                            onPositionChanged: function (m) { root._regle(caseVal.index, 1 - m.y / caseVal.height); }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true; Layout.fillHeight: true }
        }

        // ---- le menu latéral : ce que la réglette montre
        ColumnLayout {
            Layout.preferredWidth: 54
            Layout.fillHeight: true
            spacing: 3
            Item { Layout.preferredHeight: 20; Layout.maximumHeight: 20 }
            Repeater {
                model: root._params
                delegate: Rectangle {
                    id: bouton
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 3
                    color: root.parametre === modelData.cle ? "#243040" : "#131A24"
                    border.color: root.parametre === modelData.cle ? "#6699FF" : "#1E2833"
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: bouton.modelData.nom
                        color: root.parametre === bouton.modelData.cle ? "#FFFFFF" : "#4A5A6B"
                        font.family: "monospace"; font.pixelSize: 10; font.bold: true
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.parametre = bouton.modelData.cle }
                }
            }
            Item { Layout.fillWidth: true; Layout.fillHeight: true }
        }
    }
}
