import QtQuick

// Bande d'horloge : tempo, signature, temps groupés, position et mesure.
// Le premier temps de la mesure est visuellement plus large — seul repère du
// départ de mesure, actif ou non.
// Le bouton de bascule jeu/config fait partie du bandeau — pas un overlay flottant,
// sinon il chevauche les métriques de droite.
//
// Exception délibérée au principe « écran en lecture seule pendant le jeu » :
// tempo et signature sont éditables ici, dans les deux modes. Présentation pure —
// le composant émet, le parent possède l'état et l'envoi vers PD.
Rectangle {
    id: root

    property int bpm: 120
    property int minBpm: 40
    property int maxBpm: 440
    // `beat` reste un index d'unité BRUTE (croche/double/noire selon
    // signatureDen), 0..beatsPerBar-1 — pas un numéro de temps musical.
    property int beatsPerBar: 4
    property int beat: 0
    property int bar: 1
    // Les vrais temps, groupés (ex. [2,2,3] pour 7/8) — voir SimulationHarness.
    // PD les fournira à terme ; par défaut un temps par unité (mesures simples).
    property var beatGroups: [1, 1, 1, 1]
    // Signature à deux réglages indépendants : le dénominateur donne la valeur
    // (4=noire, 8=croche, 16=double), le numérateur compte combien de CES
    // unités remplissent la mesure — jusqu'à 21. Ce n'est pas le nombre de
    // temps (voir beatGroups).
    property int signatureNum: 4
    property int minSignatureNum: 1
    property int maxSignatureNum: 21
    property int signatureDen: 4
    property bool configMode: false
    property bool maintenanceMode: false

    // Index du groupe (temps) qui contient l'unité brute courante.
    readonly property int _activeGroupIndex: {
        var acc = 0;
        for (var i = 0; i < beatGroups.length; i++) {
            acc += beatGroups[i];
            if (root.beat < acc) return i;
        }
        return Math.max(beatGroups.length - 1, 0);
    }

    signal toggleConfig()
    signal toggleMaintenance()
    signal bpmStep(int delta)
    signal signatureNumStep(int delta)
    signal signatureDenCycle()

    color: "#0C1116"
    implicitHeight: 56

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 28
        anchors.verticalCenter: parent.verticalCenter
        spacing: 26

        // ---- tempo, éditable ----
        Column {
            spacing: 3
            Text { text: "TEMPO"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.5 }
            Row {
                spacing: 6
                Text {
                    text: root.bpm + " BPM"
                    color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 20; font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    spacing: 1
                    anchors.verticalCenter: parent.verticalCenter
                    StepChevron { direction: 1;  onStep: root.bpmStep(1) }
                    StepChevron { direction: -1; onStep: root.bpmStep(-1) }
                }
            }
        }

        // ---- signature : numérateur à pas (jusqu'à 21), dénominateur cyclé au tap ----
        Column {
            spacing: 3
            Text { text: "SIGNATURE"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.5 }
            Row {
                spacing: 5

                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: root.signatureNum.toString()
                        color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 20; font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        spacing: 1
                        anchors.verticalCenter: parent.verticalCenter
                        StepChevron { direction: 1;  onStep: root.signatureNumStep(1) }
                        StepChevron { direction: -1; onStep: root.signatureNumStep(-1) }
                    }
                }

                Text {
                    text: "/"
                    color: "#3B4855"; font.family: "monospace"; font.pixelSize: 20
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: denText.implicitWidth + 12
                    height: denText.implicitHeight + 6
                    radius: 3
                    color: denArea.pressed ? "#1D2732" : "transparent"
                    border.color: denArea.containsMouse || denArea.pressed ? "#212B36" : "transparent"
                    border.width: 1
                    Text {
                        id: denText
                        anchors.centerIn: parent
                        text: root.signatureDen.toString()
                        color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 20; font.bold: true
                    }
                    MouseArea {
                        id: denArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.signatureDenCycle()
                    }
                }
            }
        }
    }

    // Témoins de TEMPS (groupés), centrés. Un pavé par temps, large en
    // proportion de son nombre d'unités — un temps de 3 croches (compound/
    // irrégulier) est visiblement plus large qu'un temps d'1 croche. Le
    // premier temps de la mesure reste repérable même inactif (bonus de
    // largeur), comme l'ancien témoin "down" — mais porte sur le groupe,
    // pas sur l'unité brute.
    Row {
        anchors.centerIn: parent
        spacing: 6
        Repeater {
            model: root.beatGroups
            delegate: Rectangle {
                id: groupCell
                required property int index
                required property var modelData   // taille du groupe, en unités
                readonly property bool isFirst: index === 0
                readonly property bool isActive: index === root._activeGroupIndex
                width: 12 + (modelData - 1) * 9 + (isFirst ? 6 : 0)
                height: 14
                radius: 2
                color: isActive ? (isFirst ? "#FFFFFF" : "#64737F") : "#212B36"

                // sous-graduations : une par unité au-delà de la première,
                // pour voir la composition du temps sans le nommer.
                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    visible: groupCell.modelData > 1
                    Repeater {
                        model: groupCell.modelData - 1
                        delegate: Rectangle { width: 1; height: 8; color: "#0C1116"; opacity: 0.5 }
                    }
                }
            }
        }
    }

    Row {
        id: rightMetrics
        // s'arrête avant le premier bouton, jamais sous lui
        anchors.right: sysBtn.left
        anchors.rightMargin: 26
        anchors.verticalCenter: parent.verticalCenter
        spacing: 26

        Column {
            spacing: 3
            Text { text: "TEMPS"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.5 }
            Text { text: (root.beat + 1).toString(); color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 20; font.bold: true }
        }
        Column {
            spacing: 3
            Text { text: "MESURE"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9; font.letterSpacing: 1.5 }
            Text { text: root.bar.toString(); color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 20; font.bold: true }
        }
    }

    // Accès maintenance : à côté de CFG, jamais en overlay non plus. Séparé de
    // la config parce qu'on n'y va pas pour les mêmes raisons — l'une règle
    // l'instrument, l'autre la machine.
    Rectangle {
        id: sysBtn
        anchors.right: toggleBtn.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 44; height: 30; radius: 4
        color: root.maintenanceMode ? "#1D2732" : "#151D26"
        border.color: "#212B36"; border.width: 1
        Text {
            anchors.centerIn: parent
            text: "SYS"
            color: root.maintenanceMode ? "#66E4F2" : "#64737F"
            font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 1
        }
        MouseArea { anchors.fill: parent; onClicked: root.toggleMaintenance() }
    }

    // bouton de bascule jeu/config — dans le bandeau, jamais en overlay
    Rectangle {
        id: toggleBtn
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 44; height: 30; radius: 4
        color: root.configMode ? "#1D2732" : "#151D26"
        border.color: "#212B36"; border.width: 1
        Text {
            anchors.centerIn: parent
            text: root.configMode ? "JEU" : "CFG"
            color: "#64737F"; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 1
        }
        MouseArea { anchors.fill: parent; onClicked: root.toggleConfig() }
    }

    // Petit chevron ▲/▼ tactile, avec répétition en appui maintenu (~120ms) —
    // cible généreuse pour un écran tactile, utilisable même en jeu.
    // Partagé par le tempo et le numérateur de signature.
    component StepChevron: Item {
        id: chevron
        property int direction: 1   // 1 = haut/+1, -1 = bas/-1
        signal step()
        width: 20; height: 11

        Rectangle {
            anchors.fill: parent
            radius: 2
            color: area.pressed ? "#1D2732" : "transparent"
        }
        Text {
            anchors.centerIn: parent
            text: chevron.direction > 0 ? "▲" : "▼"
            color: area.pressed ? "#C7D2DC" : "#3B4855"
            font.pixelSize: 9
        }
        MouseArea {
            id: area
            anchors.fill: parent
            anchors.margins: -4     // agrandit la cible tactile sans agrandir le visuel
            onPressed: { chevron.step(); repeatTimer.start(); }
            onReleased: { repeatTimer.stop(); fastTimer.stop(); }
            onCanceled: { repeatTimer.stop(); fastTimer.stop(); }
        }
        Timer {
            id: repeatTimer
            interval: 400; repeat: false
            onTriggered: fastTimer.start()
        }
        Timer {
            id: fastTimer
            interval: 110; repeat: true; running: false
            onTriggered: chevron.step()
        }
    }
}
