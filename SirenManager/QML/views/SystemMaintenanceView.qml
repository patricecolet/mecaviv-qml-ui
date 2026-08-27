import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SirenManager
import "../controllers/MachinePaths.js" as MachinePaths

Rectangle {
    id: root
    color: "#1e1e1e"

    // MachineType enum values mirrored in QML (see src/Config/MachineType.h).
    // Paths come from MachinePaths so they stay in sync with PlaylistComposerView.
    readonly property var machines: [
        { name: "Linux Maître",   id: 0  },
        { name: "Raspberry Clic", id: 1  },
        { name: "Sirène S1",      id: 2  },
        { name: "Sirène S2",      id: 3  },
        { name: "Sirène S3",      id: 4  },
        { name: "Sirène S4",      id: 5  },
        { name: "Sirène S5",      id: 6  },
        { name: "Sirène S6",      id: 7  },
        { name: "Sirène S7",      id: 8  },
        { name: "Voiture A",      id: 9  },
        { name: "Voiture B",      id: 10 },
        { name: "Pavillon 1",     id: 11 },
        { name: "Pavillon 2",     id: 12 }
    ]

    property int selectedMachineIdx: 0
    property bool busy: false

    function currentMachine() { return machines[selectedMachineIdx] }

    Connections {
        target: SshManager

        function onKeysArchiveExportFinished(requestId, success, archivePath, aliasesFound, error) {
            if (requestId !== "export-keys") return
            exportKeysDialog.exportRunning = false
            if (success) {
                exportKeysDialog.exportPath = archivePath
                exportKeysDialog.exportAliases = aliasesFound
                exportKeysDialog.exportError = ""
            } else {
                exportKeysDialog.exportPath = ""
                exportKeysDialog.exportError = error || "Erreur inconnue"
            }
        }

        function onCommandFinished(requestId, success, output, error) {
            // Reboot-all results: don't toggle the global busy flag here; the
            // dialog tracks its own in-flight count and we want partial
            // results to keep streaming until the last one lands.
            if (requestId.indexOf("reboot-all-") === 0) {
                var mid = parseInt(requestId.substring("reboot-all-".length))
                rebootAllDialog.recordResult(mid, success, error)
                return
            }
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
            } else if (requestId.indexOf("ls-midi-") === 0) {
                var mid = parseInt(requestId.substring("ls-midi-".length))
                recordMidi(mid, success, output)
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
        // `df` (no path arg, no -h) for compat with BusyBox 1.00 on Artila:
        // `df /` there prints only the header — the actual rootfs row only
        // shows up when df is called without an argument. parseDfOutput
        // filters to the line mounted on "/", which is unambiguous on every
        // sample we have (Artila, Pi5, modern Linux). humanKB() turns the
        // 1k-blocks into a readable size.
        SshManager.executeCommand(currentMachine().id,
            "free | grep Mem && df", "system-info")
    }

    function refreshDmesg(filterErr) {
        busy = true
        dmesgArea.text = "Chargement..."
        var cmd = filterErr ? "dmesg -l err" : "dmesg | tail -200"
        SshManager.executeCommand(currentMachine().id, cmd, "dmesg")
    }

    function listPlaylists() {
        var p = MachinePaths.playlistPath(currentMachine().id)
        busy = true
        playlistStatus.text = "Chargement..."
        SshManager.executeCommand(currentMachine().id, "ls -1 " + p, "ls-playlists")
    }

    ListModel { id: playlistsModel }

    // MIDI cross-machine listing. Fires `ls -l Midi/` on every machine in
    // parallel, collects size + filename, then renders the Maître as
    // reference and tags the rest with ✓ (size match) / ⚠ (size differs) /
    // ✗ (missing) / + (extra not on Maître). Lets the user spot a stale
    // .mid sitting on one siren but not the others.
    property var midiByMachine: ({})
    property int midiInflight: 0
    function listAllMidi() {
        midiByMachine = {}
        midiInflight = machines.length
        midiStatus.text = "Listing " + machines.length + " machines…"
        midiArea.text = ""
        for (var i = 0; i < machines.length; i++) {
            var m = machines[i]
            var p = MachinePaths.midiPath(m.id)
            // `ls -l` (not `-la`) skips . and ..; the cd makes the absolute
            // path explicit in errors when Midi/ is missing on a siren.
            SshManager.executeCommand(m.id,
                "cd " + p + " && ls -l", "ls-midi-" + m.id)
        }
    }
    function recordMidi(machineId, success, output) {
        var entries = []
        if (success) {
            var lines = output.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                if (!line || line.charAt(0) !== '-') continue
                var f = line.split(/\s+/)
                if (f.length < 9) continue
                // BusyBox ls -l: <perms> <links> <user> <group> <size>
                //                <month> <day> <time> <name…>
                entries.push({ name: f.slice(8).join(' '), size: parseInt(f[4]) })
            }
        }
        var copy = {}
        for (var k in midiByMachine) copy[k] = midiByMachine[k]
        copy[machineId] = entries
        midiByMachine = copy
        midiInflight = Math.max(0, midiInflight - 1)
        if (midiInflight === 0) renderMidi()
    }
    function renderMidi() {
        // Maître is id=0; treat its file set as canonical and annotate
        // others against it. Files only on a non-Maître show up tagged "+".
        var ref = midiByMachine[0] || []
        var refMap = {}
        for (var i = 0; i < ref.length; i++) refMap[ref[i].name] = ref[i].size

        var out = ""
        for (var i = 0; i < machines.length; i++) {
            var m = machines[i]
            var entries = midiByMachine[m.id] || []
            var label = (m.id === 0 ? " (référence)" : "")
            out += "=== " + m.name + label + " — " + entries.length + " fichier(s) ===\n"
            // Sort entries by name for consistent display.
            entries.sort(function(a, b) { return a.name < b.name ? -1 : a.name > b.name ? 1 : 0 })
            for (var j = 0; j < entries.length; j++) {
                var e = entries[j]
                var sizeStr = ("         " + e.size).slice(-9)
                var tag = ""
                if (m.id === 0) {
                    tag = ""
                } else if (refMap.hasOwnProperty(e.name)) {
                    tag = (refMap[e.name] === e.size)
                            ? "  ✓"
                            : "  ⚠ (Maître: " + refMap[e.name] + ")"
                } else {
                    tag = "  + (absent du Maître)"
                }
                out += sizeStr + "  " + e.name + tag + "\n"
            }
            // For non-Maître machines, list files present on Maître but missing here.
            if (m.id !== 0 && ref.length > 0) {
                var present = {}
                for (var j = 0; j < entries.length; j++) present[entries[j].name] = true
                var missing = []
                for (var rname in refMap) if (!present[rname]) missing.push(rname)
                missing.sort()
                for (var k = 0; k < missing.length; k++) {
                    out += "         (absent)  " + missing[k] + "  ✗\n"
                }
            }
            out += "\n"
        }
        midiArea.text = out
        midiStatus.text = "Listing terminé"
    }

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
                    text: "Exporter clés SSH"
                    Layout.preferredHeight: 32
                    onClicked: exportKeysDialog.open()
                }
                Button {
                    text: "Reboot"
                    Layout.preferredHeight: 32
                    onClicked: rebootDialog.open()
                }
                Button {
                    text: "Reboot all"
                    Layout.preferredHeight: 32
                    onClicked: rebootAllDialog.open()
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

        // ========= DMESG / PLAYLISTS / MIDI (redimensionnables) =========
        // SplitView vertical : l'utilisateur répartit la hauteur entre les
        // trois panneaux à contenu long. dmesg (lignes noyau longues, NoWrap)
        // prend la part par défaut ; les poignées permettent de l'agrandir
        // quand la fenêtre est trop courte pour tout afficher.
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Vertical

        // ==================== DMESG ====================
        Rectangle {
            SplitView.fillHeight: true
            SplitView.minimumHeight: 120
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
            SplitView.preferredHeight: 180
            SplitView.minimumHeight: 70
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

        // ==================== MIDI DISTANTS ====================
        Rectangle {
            SplitView.preferredHeight: 240
            SplitView.minimumHeight: 70
            color: "#2a2a2a"; border.color: "#444"; radius: 6

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                RowLayout {
                    Label { text: "MIDI DISTANTS"; color: "#888"; font.pixelSize: 11; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Label { id: midiStatus; text: ""; color: "#777"; font.pixelSize: 10 }
                    Button {
                        text: "Lister tout"
                        Layout.preferredHeight: 26
                        onClicked: listAllMidi()
                    }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    TextArea {
                        id: midiArea
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
        } // SplitView (DMESG / PLAYLISTS / MIDI)
    }

    // ==================== EXPORT KEYS ARCHIVE ====================
    // Bundles ~/.ssh/id_rsa_sirenes(.pub) + Host blocks for the 13 siren
    // aliases + INSTALL.sh + README.txt into a tar.gz dropped in ~/Downloads/
    // on the BACKEND host. Lets the user clone SSH access onto a 2nd control
    // machine (the receiving machine runs the bundled INSTALL.sh, interactive,
    // POSIX sh, macOS 10.15+ / Linux compatible).
    Dialog {
        id: exportKeysDialog
        title: "Exporter les clés SSH"
        modal: true
        anchors.centerIn: parent
        closePolicy: Popup.NoAutoClose

        property bool exportStarted: false
        property bool exportRunning: false
        property string exportPath: ""
        property int exportAliases: 0
        property string exportError: ""

        onOpened: {
            exportStarted = false
            exportRunning = false
            exportPath = ""
            exportAliases = 0
            exportError = ""
        }

        contentItem: ColumnLayout {
            spacing: 8
            Layout.preferredWidth: 480

            Label {
                visible: !exportKeysDialog.exportStarted
                text: "Crée une archive tar.gz dans ~/Downloads/ contenant la clé privée " +
                      "id_rsa_sirenes, les Host alias des 13 sirènes, et un script INSTALL.sh " +
                      "interactif pour installer le tout sur une autre machine de contrôle."
                color: "white"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Label {
                visible: !exportKeysDialog.exportStarted
                text: "⚠ La clé privée donne un accès root à toutes les sirènes. Transférer via canal sûr (USB, scp, AirDrop), pas par email/Slack."
                color: "#FFA500"
                font.pixelSize: 11
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            BusyIndicator {
                visible: exportKeysDialog.exportRunning
                running: exportKeysDialog.exportRunning
                Layout.alignment: Qt.AlignHCenter
            }

            Label {
                visible: exportKeysDialog.exportStarted && !exportKeysDialog.exportRunning && exportKeysDialog.exportPath.length > 0
                text: "✓ Archive créée\n\n" +
                      exportKeysDialog.exportPath +
                      "\n\n" + exportKeysDialog.exportAliases + " alias Host extraits."
                color: "white"
                font.family: "Menlo"
                font.pixelSize: 11
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Label {
                visible: exportKeysDialog.exportStarted && !exportKeysDialog.exportRunning && exportKeysDialog.exportError.length > 0
                text: "✗ Erreur: " + exportKeysDialog.exportError
                color: "#FF6666"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }

        footer: DialogButtonBox {
            Button {
                text: "Annuler"
                visible: !exportKeysDialog.exportStarted
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            }
            Button {
                text: "Exporter"
                visible: !exportKeysDialog.exportStarted
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }
            Button {
                text: "Révéler dans le Finder"
                visible: exportKeysDialog.exportStarted && exportKeysDialog.exportPath.length > 0
                onClicked: {
                    // Open the parent dir in the system file browser. macOS
                    // Finder + Linux file managers both honor file:// URLs
                    // pointing at a directory.
                    var parent = exportKeysDialog.exportPath.replace(/\/[^/]+$/, "")
                    Qt.openUrlExternally("file://" + parent)
                }
                DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
            }
            Button {
                text: "Fermer"
                visible: exportKeysDialog.exportStarted && !exportKeysDialog.exportRunning
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }
        }

        onAccepted: {
            if (!exportStarted) {
                exportStarted = true
                exportRunning = true
                SshManager.exportKeysArchive("export-keys")
            } else {
                close()
            }
        }
        onRejected: close()
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

    // ==================== REBOOT ALL ====================
    // Fires `reboot` over SSH on every machine in parallel. Results stream
    // in via onCommandFinished — we treat "success=false, error=ssh closed"
    // as a reboot-actually-happened: the connection drops mid-command
    // because sshd dies during the reboot. So both true and false outcomes
    // are reported to the user but neither is a hard error here.
    Dialog {
        id: rebootAllDialog
        title: "Reboot de TOUTES les machines"
        modal: true
        anchors.centerIn: parent
        // Disable auto-close on Ok so the dialog stays up to show streaming
        // results. We swap the footer manually based on `rebootAllStarted`.
        closePolicy: Popup.NoAutoClose

        property int rebootAllInFlight: 0
        property bool rebootAllStarted: false
        // Per-machine result: id → { success: bool, error: string }
        property var rebootAllResults: ({})

        function recordResult(mid, success, error) {
            var copy = {}
            for (var k in rebootAllResults) copy[k] = rebootAllResults[k]
            copy[mid] = { success: success, error: error }
            rebootAllResults = copy
            rebootAllInFlight = Math.max(0, rebootAllInFlight - 1)
        }

        onOpened: {
            rebootAllStarted = false
            rebootAllInFlight = 0
            rebootAllResults = ({})
        }

        contentItem: ColumnLayout {
            spacing: 8
            Layout.preferredWidth: 460

            Label {
                text: rebootAllDialog.rebootAllStarted
                      ? (rebootAllDialog.rebootAllInFlight > 0
                         ? ("Reboot en cours… " + rebootAllDialog.rebootAllInFlight + " machine(s) en attente")
                         : "Reboot envoyé sur toutes les machines.")
                      : "Redémarrer les " + machines.length + " machines en parallèle ?"
                color: "white"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Label {
                visible: !rebootAllDialog.rebootAllStarted
                text: "Le SSH se ferme dès qu'une machine reboot — un échec de connexion = reboot quand même parti."
                color: "#FFA500"
                font.pixelSize: 11
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Repeater {
                model: rebootAllDialog.rebootAllStarted ? machines : []
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Label {
                        text: modelData.name
                        color: "#ccc"
                        Layout.preferredWidth: 140
                    }
                    Label {
                        property var res: rebootAllDialog.rebootAllResults[modelData.id]
                        text: res === undefined ? "…"
                              : (res.success ? "✓ envoyé"
                                             : "↺ reboot parti (ssh fermé : " + (res.error || "?") + ")")
                        color: res === undefined ? "#888" : (res.success ? "#33CC33" : "#FFA500")
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }
                }
            }
        }

        footer: DialogButtonBox {
            Button {
                text: "Annuler"
                visible: !rebootAllDialog.rebootAllStarted
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            }
            Button {
                text: "Reboot all"
                visible: !rebootAllDialog.rebootAllStarted
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }
            Button {
                text: rebootAllDialog.rebootAllInFlight > 0 ? "Patienter…" : "Fermer"
                enabled: rebootAllDialog.rebootAllInFlight === 0
                visible: rebootAllDialog.rebootAllStarted
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }
        }

        onAccepted: {
            if (!rebootAllStarted) {
                rebootAllStarted = true
                rebootAllInFlight = machines.length
                for (var i = 0; i < machines.length; i++) {
                    SshManager.executeCommand(machines[i].id, "reboot", "reboot-all-" + machines[i].id)
                }
            } else {
                close()
            }
        }
        onRejected: close()
    }
}
