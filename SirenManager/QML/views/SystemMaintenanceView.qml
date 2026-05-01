import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SirenManager

Rectangle {
    id: root
    color: "#1e1e1e"

    // MachineType enum values mirrored in QML (see src/Config/MachineType.h)
    readonly property var machines: [
        { name: "Linux Maître",   id: 0,  midiPath: "/mnt/disk/home/guest/WorkSpaceSirenes/Midi/", playlistPath: "/mnt/disk/home/guest/WorkSpaceSirenes/liste_de_lecture/" },
        { name: "Raspberry Clic", id: 1,  midiPath: "/home/pi/mecaviv/compositions/",              playlistPath: "/home/pi/mecaviv/compositions/" },
        { name: "Sirène S1",      id: 2,  midiPath: "",                                            playlistPath: "" },
        { name: "Sirène S2",      id: 3,  midiPath: "",                                            playlistPath: "" },
        { name: "Sirène S3",      id: 4,  midiPath: "",                                            playlistPath: "" },
        { name: "Sirène S4",      id: 5,  midiPath: "",                                            playlistPath: "" },
        { name: "Sirène S5",      id: 6,  midiPath: "",                                            playlistPath: "" },
        { name: "Sirène S6",      id: 7,  midiPath: "",                                            playlistPath: "" },
        { name: "Sirène S7",      id: 8,  midiPath: "",                                            playlistPath: "" },
        { name: "Voiture A",      id: 9,  midiPath: "",                                            playlistPath: "" },
        { name: "Voiture B",      id: 10, midiPath: "",                                            playlistPath: "" },
        { name: "Pavillon 1",     id: 11, midiPath: "",                                            playlistPath: "" },
        { name: "Pavillon 2",     id: 12, midiPath: "",                                            playlistPath: "" }
    ]

    property int selectedMachineIdx: 0
    property bool busy: false

    function currentMachine() { return machines[selectedMachineIdx] }

    Connections {
        target: SshManager

        function onCommandFinished(requestId, success, output, error) {
            busy = false
            if (requestId === "system-info") {
                ramLabel.text = success ? parseFreeOutput(output) : ("Erreur: " + error)
                diskLabel.text = success ? parseDfOutput(output) : ""
            } else if (requestId === "dmesg") {
                dmesgArea.text = success ? output : ("Erreur: " + error)
            } else if (requestId === "ls-playlists") {
                if (success) {
                    var lines = output.split("\n").filter(function(l) { return l.trim().length > 0 })
                    playlistsModel.clear()
                    for (var i = 0; i < lines.length; i++) {
                        playlistsModel.append({ name: lines[i] })
                    }
                    playlistStatus.text = lines.length + " playlist(s) trouvée(s)"
                } else {
                    playlistStatus.text = "Erreur: " + error
                }
            } else if (requestId === "reboot") {
                rebootStatus.text = success ? "Reboot envoyé." : ("Erreur: " + error)
            }
        }
    }

    function parseFreeOutput(output) {
        // Look for "Mem:" line. Format depends on `free` version (Mb on busybox).
        var m = output.match(/Mem:\s+(\d+)\s+(\d+)\s+(\d+)/)
        if (!m) return "RAM: (parsing failed)"
        var total = parseInt(m[1])
        var used = parseInt(m[2])
        var free = parseInt(m[3])
        return "RAM: " + used + " / " + total + " (libre: " + free + ")"
    }
    function parseDfOutput(output) {
        // BusyBox `df` (no -h, since old versions reject it) reports in 1k
        // blocks: "Filesystem  1024-blocks  Used  Available  Use%  Mounted on"
        var lines = output.split("\n")
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].match(/\s\/\s*$/)) {
                var fields = lines[i].split(/\s+/).filter(function(f) { return f.length > 0 })
                if (fields.length >= 5) {
                    var totalK = parseInt(fields[1])
                    var usedK = parseInt(fields[2])
                    var pct = fields[4]
                    if (!isNaN(totalK)) {
                        return "Disque /: " + humanKB(usedK) + " utilisé sur " + humanKB(totalK) + " (" + pct + ")"
                    }
                    // Already human-readable (modern df -h)
                    return "Disque /: " + fields[2] + " utilisé sur " + fields[1] + " (" + pct + ")"
                }
            }
        }
        return "Disque: (parsing failed)"
    }

    function humanKB(kb) {
        if (kb >= 1024 * 1024) return (kb / 1024 / 1024).toFixed(1) + " GB"
        if (kb >= 1024) return (kb / 1024).toFixed(1) + " MB"
        return kb + " KB"
    }

    function refreshSystemInfo() {
        busy = true
        ramLabel.text = "..."
        diskLabel.text = ""
        // `df` without -h for compat with the BusyBox 1.00 on the Artila sirens
        // (v2009 — `-h` is unknown there). humanKB() converts the 1k-blocks
        // output to human-readable on the QML side.
        SshManager.executeCommand(currentMachine().id,
            "free | grep Mem && df /", "system-info")
    }

    function refreshDmesg(filterErr) {
        busy = true
        dmesgArea.text = "Chargement..."
        var cmd = filterErr ? "dmesg -l err" : "dmesg | tail -200"
        SshManager.executeCommand(currentMachine().id, cmd, "dmesg")
    }

    function listPlaylists() {
        var p = currentMachine().playlistPath
        if (!p || p.length === 0) {
            playlistStatus.text = "Pas de chemin playlist pour cette machine"
            playlistsModel.clear()
            return
        }
        busy = true
        playlistStatus.text = "Chargement..."
        SshManager.executeCommand(currentMachine().id, "ls -1 " + p, "ls-playlists")
    }

    ListModel { id: playlistsModel }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // ==================== MACHINE SELECTOR ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#2a2a2a"; border.color: "#444"; radius: 6

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16

                Label { text: "Machine:"; color: "#aaa"; font.pixelSize: 12 }
                ComboBox {
                    id: machineCombo
                    model: machines.map(function(m) { return m.name })
                    Layout.preferredWidth: 200
                    onCurrentIndexChanged: {
                        root.selectedMachineIdx = currentIndex
                        ramLabel.text = "—"
                        diskLabel.text = ""
                        dmesgArea.text = ""
                        playlistsModel.clear()
                        playlistStatus.text = ""
                    }
                }

                BusyIndicator {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    running: busy
                    visible: busy
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "Reboot"
                    Layout.preferredHeight: 32
                    onClicked: rebootDialog.open()
                }
            }
        }

        // ==================== SYSTEM INFO ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            color: "#2a2a2a"; border.color: "#444"; radius: 6

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                RowLayout {
                    Label { text: "ÉTAT SYSTÈME"; color: "#888"; font.pixelSize: 11; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Button {
                        text: "Rafraîchir"
                        Layout.preferredHeight: 26
                        onClicked: refreshSystemInfo()
                    }
                }
                TextEdit { id: ramLabel;  text: "—"; color: "white"; font.pixelSize: 14; font.family: "Menlo"; readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap; Layout.fillWidth: true }
                TextEdit { id: diskLabel; text: "";  color: "white"; font.pixelSize: 14; font.family: "Menlo"; readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap; Layout.fillWidth: true }
            }
        }

        // ==================== DMESG ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#2a2a2a"; border.color: "#444"; radius: 6

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                RowLayout {
                    Label { text: "DMESG"; color: "#888"; font.pixelSize: 11; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Button { text: "Tout";    Layout.preferredHeight: 26; onClicked: refreshDmesg(false) }
                    Button { text: "Erreurs"; Layout.preferredHeight: 26; onClicked: refreshDmesg(true)  }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    TextArea {
                        id: dmesgArea
                        readOnly: true
                        text: ""
                        color: "#ccc"
                        font.family: "Menlo"
                        font.pixelSize: 11
                        wrapMode: TextEdit.NoWrap
                        background: Rectangle { color: "#111" }
                    }
                }
            }
        }

        // ==================== PLAYLISTS ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            color: "#2a2a2a"; border.color: "#444"; radius: 6

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                RowLayout {
                    Label { text: "PLAYLISTS DISTANTES"; color: "#888"; font.pixelSize: 11; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Label { id: playlistStatus; text: ""; color: "#777"; font.pixelSize: 10 }
                    Button { text: "Lister"; Layout.preferredHeight: 26; onClicked: listPlaylists() }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ListView {
                        model: playlistsModel
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 22
                            color: "transparent"
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                text: name
                                color: "#ccc"
                                font.family: "Menlo"
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }

    // ==================== REBOOT CONFIRMATION ====================
    Dialog {
        id: rebootDialog
        title: "Confirmer le reboot"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok | Dialog.Cancel
        contentItem: ColumnLayout {
            spacing: 8
            Label {
                text: "Redémarrer " + currentMachine().name + " ?"
                color: "white"
            }
            Label {
                id: rebootStatus
                text: ""
                color: "#888"
                font.pixelSize: 11
            }
        }
        onAccepted: {
            rebootStatus.text = "Envoi en cours..."
            SshManager.executeCommand(currentMachine().id, "reboot", "reboot")
        }
    }
}
