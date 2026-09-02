pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Éditeur de motif, façon boîte à rythmes : une rangée de pas qu'on allume ou
// qu'on éteint, et sous elle une réglette par pas dont le menu latéral choisit
// ce qu'elle montre — vélocité, note, gate, attack ou release.
// La tête de lecture tourne pendant l'édition : on voit ce qu'on entend.
Item {
    id: root

    // steps[i] = { tick, velocite, hauteur, gate, attack, release }
    property var steps: []
    property int lengthTicks: 1920
    property int seqIndex: 0
    property bool actif: false

    // lecture
    property real phase: -1
    property int bpm: 120
    property bool enJeu: false

    // édition
    property int mesure: 0                    // la mesure affichée
    property string parametre: "velocite"

    // le motif appartient au parent : l'éditeur propose, il ne s'écrit pas
    // lui-même — une assignation locale casserait la liaison sur steps.
    signal motifModifie(var pas)

    readonly property int _ticksParMesure: 1920
    readonly property int _pasParMesure: 16
    readonly property int _ticksParPas: _ticksParMesure / _pasParMesure   // 120
    readonly property int _nbMesures: Math.max(1, Math.round(lengthTicks / _ticksParMesure))
    readonly property bool _lit: enJeu && phase >= 0

    readonly property var _params: [
        { cle: "velocite", nom: "VÉL",  min: 1,   max: 127 },
        { cle: "hauteur",  nom: "NOTE", min: -12, max: 12 },
        { cle: "gate",     nom: "GATE", min: 10,  max: 480 },
        { cle: "attack",   nom: "ATK",  min: 0,   max: 127 },
        { cle: "release",  nom: "REL",  min: 0,   max: 127 }
    ]
    function _def(cle) {
        for (var i = 0; i < _params.length; i++) if (_params[i].cle === cle) return _params[i];
        return _params[0];
    }
    function _tick(n) { return (mesure * _ticksParMesure) + n * _ticksParPas; }

    function _pas(n) {
        var t = _tick(n);
        for (var i = 0; i < steps.length; i++) if (steps[i].tick === t) return steps[i];
        return null;
    }
    function _bascule(n) {
        var t = _tick(n);
        var copie = steps.slice();
        for (var i = 0; i < copie.length; i++) {
            if (copie[i].tick === t) { copie.splice(i, 1); motifModifie(copie); return; }
        }
        copie.push({ tick: t, velocite: 100, hauteur: 0, gate: 120, attack: 20, release: 30 });
        copie.sort(function (a, b) { return a.tick - b.tick; });
        motifModifie(copie);
    }
    function _regle(n, fraction) {
        var p = _def(parametre);
        var v = Math.round(p.min + Math.max(0, Math.min(1, fraction)) * (p.max - p.min));
        var t = _tick(n);
        var copie = steps.slice();
        for (var i = 0; i < copie.length; i++) {
            if (copie[i].tick === t) {
                var s = {};
                for (var k in copie[i]) s[k] = copie[i][k];
                s[parametre] = v;
                copie[i] = s;
                motifModifie(copie);
                return;
            }
        }
    }
    function _fraction(pas) {
        var p = _def(parametre);
        return (pas[parametre] - p.min) / (p.max - p.min);
    }

    NumberAnimation {
        target: root
        property: "phase"
        running: root.enJeu
        loops: Animation.Infinite
        from: 0
        to: root.lengthTicks
        duration: Math.max(200, (root.lengthTicks / 480) * (60000 / Math.max(1, root.bpm)))
    }

    RowLayout {
        anchors.fill: parent
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            // ---- en-tête : la séquence, sa longueur, la mesure affichée
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: root.seqIndex > 0 ? "séquence " + root.seqIndex : "vide"
                    color: root.actif ? "#FFFFFF" : "#64737F"
                    font.family: "monospace"; font.pixelSize: 13; font.bold: true
                }
                Text {
                    text: root._nbMesures + (root._nbMesures > 1 ? " mesures" : " mesure")
                    color: "#3B4855"; font.family: "monospace"; font.pixelSize: 10
                }
                Repeater {
                    model: root._nbMesures
                    delegate: Rectangle {
                        id: ongletMesure
                        required property int index
                        width: 20; height: 18; radius: 2
                        color: root.mesure === index ? "#6699FF" : "#1A2230"
                        border.color: "#243040"; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: ongletMesure.index + 1
                            color: root.mesure === ongletMesure.index ? "#0E141B" : "#64737F"
                            font.family: "monospace"; font.pixelSize: 9
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.mesure = ongletMesure.index }
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.steps.length + " pas"
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
                    model: root._pasParMesure
                    delegate: Rectangle {
                        id: casePas
                        required property int index
                        readonly property var pas: root._pas(index)
                        readonly property bool sonne: root._lit && pas !== null
                                                      && root.phase >= pas.tick
                                                      && root.phase < pas.tick + pas.gate
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 3
                        color: sonne ? "#FFD166" : (pas !== null ? "#6699FF" : "#161E29")
                        border.color: (index % 4 === 0) ? "#33465C" : "#212C3A"
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
                    model: root._pasParMesure
                    delegate: Rectangle {
                        id: caseVal
                        required property int index
                        readonly property var pas: root._pas(index)
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "#0E141B"
                        border.color: (index % 4 === 0) ? "#243040" : "#171F28"
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
