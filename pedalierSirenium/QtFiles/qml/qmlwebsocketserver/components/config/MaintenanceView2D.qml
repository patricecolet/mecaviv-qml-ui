import QtQuick
import QtQuick.Layouts

// Page de maintenance : ce qui touche à la machine plutôt qu'à la musique.
// La sortie des sirènes d'abord — c'est le seul réglage qui change ce qu'on
// entend sans rien changer au morceau.
Item {
    id: root

    property string outputDevice: "v1"   // v1 | v2 | dsp
    property bool connected: false
    signal outputRequested(string dev)
    signal reconnectRequested()

    // Clic audible : l'interrupteur est dans le bandeau, le niveau se règle ici
    // — on l'ajuste une fois, ce n'est pas un geste de jeu.
    property bool clicEnabled: false
    property int clicVolume: 100
    signal clicVolumeRequested(int volume)

    // Paliers en dB, parce que c'est ce que le musicien lit. La valeur envoyée
    // reste l'échelle PureData, où 100 vaut 0 dB.
    readonly property var _clicLevels: [
        { label: "-24", value: 76 },
        { label: "-12", value: 88 },
        { label: "-6",  value: 94 },
        { label: "-3",  value: 97 },
        { label: "0",   value: 100 }
    ]

    readonly property var _outputs: [
        { id: "v1",  label: "V1",  sub: "UDP" },
        { id: "v2",  label: "V2",  sub: "MIDI" },
        { id: "dsp", label: "DSP", sub: "interne" }
    ]

    // Santé de la machine : servie par le serveur node qui sert aussi la page,
    // donc URL relative — pas d'adresse en dur, ça suit la machine.
    property real cpuTemp: -1
    property real memPercent: -1
    property real cpuPercent: -1
    property int uptimeSec: -1

    function _uptimeText() {
        if (uptimeSec < 0) return "—";
        var h = Math.floor(uptimeSec / 3600);
        var m = Math.floor((uptimeSec % 3600) / 60);
        return h > 0 ? h + " h " + m + " min" : m + " min";
    }

    // Lien RTP-MIDI : ce que rtpmidid dit de ses pairs.
    property var rtpPeers: []
    property bool rtpAvailable: false

    function _get(url, onOk) {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE || x.status !== 200) return;
            try { onOk(JSON.parse(x.responseText)); }
            catch (e) { /* serveur absent : les champs restent à — */ }
        };
        x.open("GET", url);
        x.send();
    }

    function _poll() {
        _get("/api/system-info", function(d) {
            root.cpuTemp = d.temperature !== undefined ? d.temperature : -1;
            root.memPercent = d.memory !== undefined ? d.memory : -1;
            root.cpuPercent = d.cpu !== undefined ? d.cpu : -1;
            root.uptimeSec = d.uptime !== undefined ? d.uptime : -1;
        });
        _get("/api/rtp", function(d) {
            root.rtpAvailable = d.available === true;
            root.rtpPeers = d.peers || [];
        });
    }

    Timer {
        interval: 5000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root._poll()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 24

        Text {
            text: "MAINTENANCE"
            color: "#3B4855"; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 2
        }

        // --- Sortie des sirènes ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "Sortie des sirènes"
                color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 14
            }

            RowLayout {
                spacing: 10
                Repeater {
                    model: root._outputs
                    delegate: Rectangle {
                        id: cell
                        required property var modelData
                        readonly property bool active: modelData.id === root.outputDevice
                        width: 132; height: 62; radius: 5
                        color: active ? "#1D2732" : "#111820"
                        border.color: active ? "#66E4F2" : "#212B36"
                        border.width: 1
                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cell.modelData.label
                                color: cell.active ? "#66E4F2" : "#64737F"
                                font.family: "monospace"; font.pixelSize: 18; font.bold: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cell.modelData.sub
                                color: "#3B4855"; font.family: "monospace"; font.pixelSize: 10
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.outputRequested(cell.modelData.id)
                        }
                    }
                }
            }

            Text {
                // Le changement de sortie remet les sirènes à zéro côté PD : le
                // dire, sinon le silence qui suit passe pour une panne.
                text: "Changer de sortie remet les sirènes à zéro."
                color: "#3B4855"; font.family: "monospace"; font.pixelSize: 10
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#171F28" }

        // Casque Bluetooth — la ligne n'apparaît que s'il est connecté, sinon
        // c'est un tiret de plus à lire pour rien.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: bt.connected

            Text {
                text: "Casque"
                color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 14
            }
            Text {
                text: bt.deviceName
                color: "#64737F"; font.family: "monospace"; font.pixelSize: 13
            }
            Text {
                text: bt.battery >= 0 ? bt.battery + " %" : "charge inconnue"
                color: bt.battery < 0 ? "#3B4855"
                     : bt.battery <= 20 ? "#E4665A"
                     : bt.battery <= 50 ? "#E4C15A" : "#7ED08A"
                font.family: "monospace"; font.pixelSize: 14; font.bold: true
            }
        }

        BluetoothReader { id: bt }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "Niveau du clic"
                color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 14
            }

            RowLayout {
                spacing: 10
                Repeater {
                    model: root._clicLevels
                    delegate: Rectangle {
                        id: vcell
                        required property var modelData
                        readonly property bool active: modelData.value === root.clicVolume
                        width: 84; height: 52; radius: 5
                        color: vcell.active ? "#1D2732" : "#111820"
                        border.color: vcell.active ? "#66E4F2" : "#212B36"
                        border.width: 1
                        opacity: root.clicEnabled ? 1.0 : 0.45
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: vcell.modelData.label
                                color: vcell.active ? "#66E4F2" : "#64737F"
                                font.family: "monospace"; font.pixelSize: 18; font.bold: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "dB"
                                color: "#3B4855"; font.family: "monospace"; font.pixelSize: 9
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.clicVolumeRequested(vcell.modelData.value)
                        }
                    }
                }
            }

            Text {
                // L'interrupteur reste dans le bandeau : le dire, sinon on cherche
                // ici de quoi couper le clic.
                text: root.clicEnabled ? "Le clic s'allume et s'éteint depuis le bandeau (♪)."
                                       : "Clic éteint — l'interrupteur est dans le bandeau (♪)."
                color: "#3B4855"; font.family: "monospace"; font.pixelSize: 10
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#171F28" }

        // --- État de la machine ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Machine"
                color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 14
            }

            GridLayout {
                columns: 2
                columnSpacing: 24
                rowSpacing: 6

                Text { text: "PureData"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 11 }
                RowLayout {
                    spacing: 10
                    Text {
                        text: root.connected ? "connecté" : "absent"
                        color: root.connected ? "#7FD98B" : "#D97F7F"
                        font.family: "monospace"; font.pixelSize: 11
                    }
                    // Toujours proposable : la socket peut être ouverte côté Qt
                    // alors que PD a été relancé derrière.
                    Rectangle {
                        width: 96; height: 22; radius: 3
                        color: "#111820"; border.color: "#212B36"; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "reconnecter"
                            color: "#64737F"; font.family: "monospace"; font.pixelSize: 10
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.reconnectRequested() }
                    }
                }

                Text { text: "Température"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 11 }
                Text {
                    text: root.cpuTemp > 0 ? root.cpuTemp.toFixed(1) + " °C" : "—"
                    color: root.cpuTemp >= 70 ? "#D97F7F" : "#C7D2DC"
                    font.family: "monospace"; font.pixelSize: 11
                }

                Text { text: "Processeur"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 11 }
                Text {
                    text: root.cpuPercent >= 0 ? root.cpuPercent.toFixed(0) + " %" : "—"
                    color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 11
                }

                Text { text: "Mémoire"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 11 }
                Text {
                    text: root.memPercent > 0 ? root.memPercent.toFixed(0) + " %" : "—"
                    color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 11
                }

                Text { text: "En route depuis"; color: "#3B4855"; font.family: "monospace"; font.pixelSize: 11 }
                Text { text: root._uptimeText(); color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 11 }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#171F28" }

        // --- Lien RTP-MIDI ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                spacing: 12
                Text {
                    text: "Lien RTP-MIDI"
                    color: "#C7D2DC"; font.family: "monospace"; font.pixelSize: 14
                }
                Text {
                    text: root.rtpAvailable ? "" : "rtpmidid injoignable"
                    color: "#D97F7F"; font.family: "monospace"; font.pixelSize: 10
                }
            }

            Repeater {
                model: root.rtpPeers
                delegate: RowLayout {
                    id: peer
                    required property var modelData
                    spacing: 10
                    readonly property bool live: modelData.status === "CONNECTED"

                    Rectangle {
                        width: 7; height: 7; radius: 4
                        color: peer.live ? "#7FD98B" : "#3B4855"
                    }
                    Text {
                        text: peer.modelData.name
                        color: peer.live ? "#C7D2DC" : "#64737F"
                        font.family: "monospace"; font.pixelSize: 11
                    }
                    Text {
                        // Les compteurs disent si ça circule vraiment, pas
                        // seulement si la session est déclarée ouverte.
                        text: "↓" + peer.modelData.recv + "  ↑" + peer.modelData.sent
                        color: "#3B4855"; font.family: "monospace"; font.pixelSize: 10
                    }
                }
            }

            Text {
                visible: root.rtpAvailable && root.rtpPeers.length === 0
                text: "aucun pair annoncé"
                color: "#3B4855"; font.family: "monospace"; font.pixelSize: 10
            }
        }

        Item { Layout.fillHeight: true }
    }
}
