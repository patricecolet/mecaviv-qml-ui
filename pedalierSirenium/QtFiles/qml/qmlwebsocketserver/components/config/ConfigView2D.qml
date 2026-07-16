import QtQuick
import QtQuick.Layouts
import "../../config.js" as Config

// Écran de configuration : on touche un contrôle sur le portrait, le panneau du bas
// dit ce qu'il fait. Pour une pédale d'expression, c'est la matrice de modulation 7×8.
Item {
    id: root

    property string selKind: "expr"
    property int selIndex: 0

    // matrice d'exemple par pédale virtuelle (remplacée par les vraies valeurs plus tard)
    function _mockMatrix(pedal) {
        var m = {};
        for (var s = 0; s < 7; s++) {
            m[s] = {};
            for (var c = 0; c < Config.controllers.order.length; c++) {
                var name = Config.controllers.order[c];
                var v = 0;
                if (pedal === 0) {            // A : vibrato sur les graves
                    if (name === "vibratoDepth") v = s < 4 ? 70 - s * 8 : 0;
                    else if (name === "vibratoSpeed") v = s < 4 ? 45 : 0;
                    else if (name === "volume") v = s >= 4 ? -35 : 0;
                } else if (pedal === 1) {     // B : enveloppe globale
                    if (name === "attack") v = 60;
                    else if (name === "release") v = 80;
                } else {                       // C : transpose + tremolo aigus
                    if (name === "voice") v = s >= 4 ? 12 : 5;
                    else if (name === "tremoloDepth") v = s >= 4 ? 55 : 20;
                    else if (name === "tremoloSpeed") v = s >= 4 ? 40 : 0;
                }
                m[s][name] = v;
            }
        }
        return m;
    }

    property var _matrix: _mockMatrix(0)

    function _describe() {
        if (selKind === "expr") return { what: "Pédale d'expression " + ["A","B","C"][selIndex], kind: "continue · 0 → butée" };
        if (selKind === "push") return { what: "Poussoir " + (selIndex + 1), kind: "interrupteur · assignable" };
        if (selKind === "sw")   return { what: "Interrupteur — pédale " + ["A","B","C"][Math.floor(selIndex / 10)], kind: "monté sur la pédale" };
        return { what: "Touche du clavier", kind: "sensible à la vélocité" };
    }
    property var _desc: _describe()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 24

        PedalboardPortrait2D {
            id: portrait
            Layout.fillWidth: true
            Layout.preferredHeight: 320
            selKind: root.selKind
            selIndex: root.selIndex
            onSelected: function(kind, index) {
                root.selKind = kind;
                root.selIndex = index;
                root._desc = root._describe();
                if (kind === "expr") root._matrix = root._mockMatrix(index);
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#171F28" }

        // panneau d'assignation
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            RowLayout {
                spacing: 14
                Text { text: root._desc.what; color: "#FFFFFF"; font.family: "monospace"; font.pixelSize: 22; font.bold: true }
                Text { text: root._desc.kind; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 1.4; Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 3 }
            }

            // matrice (pédales d'expression) ou descriptif
            ModulationMatrix2D {
                visible: root.selKind === "expr"
                Layout.fillWidth: true
                Layout.fillHeight: true
                matrix: root._matrix
            }
            Text {
                visible: root.selKind !== "expr"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.selKind === "push"
                      ? "Appelle un état complet : la scène et l'affectation d'expression qui va avec. Fonction assignable."
                      : root.selKind === "key"
                        ? "Une des 13 touches. Elle sélectionne une sirène, sert à poser les accords de l'harmoniseur, ou joue une note."
                        : "Monté sur la pédale d'expression, actionnable sans quitter le pied. Bascule la pédale vers une autre affectation."
                color: "#64737F"; font.family: "monospace"; font.pixelSize: 13; lineHeight: 1.5
            }
        }
    }
}
