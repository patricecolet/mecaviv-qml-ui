import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SirenManager

// Edit the 48-slot playlist on the Linux Maître. Loads `derniere_liste`,
// parses the {[n=X][s=…][a=…][B=…][E=…]} format, exposes per-slot editing
// and saves back via SSH upload. Also lists available MIDI files so you
// can assign one to a slot via the dropdown.
Rectangle {
    id: root
    color: "#1e1e1e"

    readonly property int linuxMaitre: 0
    readonly property int raspberryClic: 1
    readonly property string maitreMidiDir:    "/mnt/disk/home/guest/WorkSpaceSirenes/Midi/"
    readonly property string maitrePlaylistFile: "/mnt/disk/home/guest/WorkSpaceSirenes/derniere_liste"

    property int targetMachine: linuxMaitre
    property bool busy: false

    ListModel { id: slotsModel }
    ListModel { id: midiFilesModel }

    // Tracks whether any slot has unsaved local changes. Reset to false on
    // load/save success; bumped to true whenever a slot field changes.
    property int dirtyCount: 0

    function makeEmptySlots() {
        slotsModel.clear()
        for (var i = 0; i < 48; i++) {
            slotsModel.append({ slot: i, filename: "", pseudo: "", loop: false, chain: false, dirty: false })
        }
        dirtyCount = 0
    }

    function markDirty(slotIdx) {
        if (slotsModel.get(slotIdx).dirty) return  // already dirty
        slotsModel.setProperty(slotIdx, "dirty", true)
        dirtyCount = dirtyCount + 1
    }

    function clearAllDirty() {
        for (var i = 0; i < 48; i++) {
            if (slotsModel.get(i).dirty) slotsModel.setProperty(i, "dirty", false)
        }
        dirtyCount = 0
    }

    Component.onCompleted: makeEmptySlots()

    // Path of the actual playlist file, resolved from `derniere_liste`. Empty
    // until loadFromMaster() succeeds (or set manually if user types one).
    property string activePlaylistPath: ""

    function loadFromMaster() {
        busy = true
        statusLabel.text = "Lecture du pointeur derniere_liste…"
        // Step 1: read the pointer file. Step 2 (in onDownloadFinished below)
        // extracts the wrapped path and downloads the actual playlist.
        SshManager.downloadFile(targetMachine, maitrePlaylistFile, "load-pointer")
    }

    function saveToMaster() {
        if (activePlaylistPath.length === 0) {
            statusLabel.text = "Charge d'abord une playlist (besoin du chemin actif)"
            return
        }
        busy = true
        statusLabel.text = "Sauvegarde vers " + activePlaylistPath + "…"
        var lines = []
        for (var i = 0; i < 48; i++) {
            var s = slotsModel.get(i)
            lines.push("{[n=" + s.slot + "]\t\t[s=" + s.filename + "]\t\t\t[a=" +
                       s.pseudo + "]\t\t[B=" + (s.loop ? 1 : 0) + "]\t[E=" +
                       (s.chain ? 1 : 0) + "]}")
        }
        var content = lines.join("\n") + "\n"
        SshManager.uploadFile(targetMachine, activePlaylistPath, content, "save-playlist")
    }

    function loadMidiFiles() {
        busy = true
        midiFilesStatus.text = "Chargement…"
        // Pattern matches both .mid and .midi (legacy ships both); the
        // `|| true` keeps `ls | grep` exit code 0 when grep finds nothing,
        // which would otherwise propagate ssh exit 1 = false-positive error.
        SshManager.executeCommand(targetMachine,
            "ls -1 " + maitreMidiDir + " | grep -iE '\\.midi?$' || true",
            "ls-midi")
    }

    // Pull a basename out of an URL or path. "file:///foo/bar/baz.mid" → "baz.mid"
    function basename(urlOrPath) {
        var s = urlOrPath.toString()
        if (s.indexOf("file://") === 0) s = s.substring(7)
        var idx = s.lastIndexOf("/")
        return idx >= 0 ? s.substring(idx + 1) : s
    }

    // Upload a local file to the master's MIDI dir. assignToSlot >=0 also
    // assigns the dropped basename to that slot once the upload succeeds.
    property int pendingAssignSlot: -1
    property string pendingFilename: ""

    function uploadLocalMidi(localUrl, assignToSlot) {
        var name = basename(localUrl)
        if (!name.match(/\.midi?$/i)) {
            statusLabel.text = "Ignoré (pas un .mid): " + name
            return
        }
        pendingAssignSlot = assignToSlot !== undefined ? assignToSlot : -1
        pendingFilename = name
        busy = true
        statusLabel.text = "Upload de " + name + "…"
        SshManager.uploadLocalFile(targetMachine, localUrl,
                                   maitreMidiDir + name, "upload-midi")
    }

    function parsePlaylist(content) {
        // Match {[n=X]...[s=...]...[a=...]...[B=X]...[E=X]} for each entry.
        // The legacy uses tabs as separators; we just look for the bracketed fields.
        makeEmptySlots()
        var rx = /\{[^}]*\[n=(\d+)\][^}]*\[s=([^\]]*)\][^}]*\[a=([^\]]*)\][^}]*\[B=(\d)\][^}]*\[E=(\d)\][^}]*\}/g
        var match
        while ((match = rx.exec(content)) !== null) {
            var idx = parseInt(match[1])
            if (idx >= 0 && idx < 48) {
                slotsModel.set(idx, {
                    slot: idx,
                    filename: match[2],
                    pseudo:   match[3],
                    loop:     match[4] === "1",
                    chain:    match[5] === "1",
                    dirty:    false
                })
            }
        }
        dirtyCount = 0
    }

    // Sync targets. Each entry knows its remote path because sirens (artila)
    // and the raspberry-clic don't share the same MIDI dir layout. The
    // `liveness` field tells us how to pre-check the entry:
    //   "trampresence:N"  → check based on sirenOnline[N-1] (artila S1-S7 + Trompe)
    //   "always"          → pre-check by default (raspberry-clic, voitures, pavillons —
    //                       no live ping for them, user unchecks if not needed)
    readonly property string raspberryMidiDir: "/home/pi/mecaviv/compositions/"
    readonly property var syncTargets: [
        { machineType: 2,  remotePath: maitreMidiDir,    name: "S1",         liveness: "trampresence:1" },
        { machineType: 3,  remotePath: maitreMidiDir,    name: "S2",         liveness: "trampresence:2" },
        { machineType: 4,  remotePath: maitreMidiDir,    name: "S3",         liveness: "trampresence:3" },
        { machineType: 5,  remotePath: maitreMidiDir,    name: "S4",         liveness: "trampresence:4" },
        { machineType: 6,  remotePath: maitreMidiDir,    name: "S5",         liveness: "trampresence:5" },
        { machineType: 7,  remotePath: maitreMidiDir,    name: "S6",         liveness: "trampresence:6" },
        { machineType: 8,  remotePath: maitreMidiDir,    name: "S7",         liveness: "trampresence:7" },
        { machineType: 1,  remotePath: raspberryMidiDir, name: "Raspberry",  liveness: "always" },
        { machineType: 9,  remotePath: maitreMidiDir,    name: "Voiture A",  liveness: "always" },
        { machineType: 10, remotePath: maitreMidiDir,    name: "Voiture B",  liveness: "always" },
        { machineType: 11, remotePath: maitreMidiDir,    name: "Pavillon 1", liveness: "always" },
        { machineType: 12, remotePath: maitreMidiDir,    name: "Pavillon 2", liveness: "always" }
    ]

    // Live siren-online state, driven by TRAMPRESENCE 0x21 from the master
    // (same data MaintenanceView's KEB dots use). Only S1-S7 are tracked
    // there — for other machines we ssh-ping them when the sync dialog opens.
    property var sirenOnline: [false, false, false, false, false, false, false]

    // Per-target ping state for "always" liveness machines (raspberry/voitures/
    // pavillons). Index = syncTargets index. Values: "online"|"offline"|"unknown".
    // Empty entry = not yet probed (still "unknown"). Updated as ssh-ping
    // results arrive without blocking dialog interaction.
    property var pingState: []

    function setPingState(idx, state) {
        var copy = pingState.slice()
        copy[idx] = state
        pingState = copy
    }

    // "online" | "offline" | "unknown"
    function targetStatus(idx) {
        var t = syncTargets[idx]
        if (t.liveness === "always") {
            return pingState[idx] || "unknown"
        }
        if (t.liveness.indexOf("trampresence:") === 0) {
            var n = parseInt(t.liveness.split(":")[1])
            return sirenOnline[n - 1] ? "online" : "offline"
        }
        return "unknown"
    }

    function statusColor(s) {
        if (s === "online") return "#33CC33"
        if (s === "offline") return "#AA3333"
        return "#FFC107"   // unknown — yellow
    }
    function statusLabel(s) {
        if (s === "online") return "en ligne"
        if (s === "offline") return "hors ligne"
        return "?"
    }

    // Fire `ssh <target> "true"` in parallel for every "always"-liveness target
    // and let the responses update pingState as they arrive.
    function pingAlwaysTargets() {
        // Reset all "always" entries to unknown.
        var copy = []
        for (var i = 0; i < syncTargets.length; i++) {
            copy[i] = (syncTargets[i].liveness === "always") ? "unknown" : ""
        }
        pingState = copy
        // Send the pings.
        for (var j = 0; j < syncTargets.length; j++) {
            if (syncTargets[j].liveness === "always") {
                SshManager.executeCommand(syncTargets[j].machineType, "true", "ping-" + j)
            }
        }
    }

    Connections {
        target: UdpManager
        function onKebPresenceReceived(sirenIdx, present) {
            if (sirenIdx < 1 || sirenIdx > 7) return
            var copy = sirenOnline.slice()
            copy[sirenIdx - 1] = present
            sirenOnline = copy
        }
    }

    function startSync(selectedIndices) {
        var picked = []
        for (var i = 0; i < syncTargets.length; i++) {
            if (selectedIndices.indexOf(i) >= 0) picked.push(syncTargets[i])
        }
        if (picked.length === 0) {
            statusLabel.text = "Aucune cible sélectionnée pour la sync."
            return
        }
        busy = true
        statusLabel.text = "Synchronisation vers " + picked.length + " cible(s)…"
        SshManager.syncDir(linuxMaitre, maitreMidiDir,
                           JSON.stringify(picked), "sync-midi")
    }

    Connections {
        target: SshManager

        function onSyncDirFinished(requestId, success, tarSize, resultsJson, error) {
            busy = false
            if (requestId !== "sync-midi") return
            if (!success) {
                statusLabel.text = "Sync échouée: " + error
                syncResultDialog.summary = "Échec global: " + error
                syncResultDialog.open()
                return
            }
            var results = JSON.parse(resultsJson)
            var ok = 0, fail = 0
            var lines = []
            for (var i = 0; i < results.length; i++) {
                var r = results[i]
                if (r.success) {
                    ok++
                    lines.push("✓ " + r.machine)
                } else {
                    fail++
                    lines.push("✗ " + r.machine + ": " + (r.error || ""))
                }
            }
            statusLabel.text = "Sync: " + ok + " OK / " + fail + " échec(s) (" + tarSize + " B)"
            syncResultDialog.summary = lines.join("\n")
            syncResultDialog.open()
        }

        function onDownloadFinished(requestId, success, content, error) {
            if (requestId === "load-pointer") {
                if (!success) {
                    busy = false
                    statusLabel.text = "Erreur (pointeur): " + error
                    return
                }
                // The pointer file content looks like:
                //   <string>/mnt/disk/.../liste_de_lecture/2024.ListLecture</string>
                // Pull the path out and chain into the real download.
                var m = content.match(/<string>([^<]+)<\/string>/)
                if (!m) {
                    busy = false
                    statusLabel.text = "Format de derniere_liste inattendu: " + content.substring(0, 80)
                    return
                }
                activePlaylistPath = m[1].trim()
                statusLabel.text = "Chargement de " + activePlaylistPath + "…"
                SshManager.downloadFile(targetMachine, activePlaylistPath, "load-playlist")
                return
            }
            if (requestId === "load-playlist") {
                busy = false
                if (success) {
                    parsePlaylist(content)
                    statusLabel.text = "Playlist chargée: " + activePlaylistPath
                } else {
                    statusLabel.text = "Erreur (playlist): " + error
                }
                return
            }
        }
        function onUploadFinished(requestId, success, error) {
            busy = false
            if (requestId === "save-playlist") {
                if (success) {
                    statusLabel.text = "Sauvegardé."
                    clearAllDirty()
                } else {
                    statusLabel.text = "Erreur: " + error
                }
                return
            }
            if (requestId === "upload-midi") {
                if (success) {
                    statusLabel.text = "Uploadé: " + pendingFilename
                    if (pendingAssignSlot >= 0 && pendingAssignSlot < 48) {
                        slotsModel.setProperty(pendingAssignSlot, "filename", pendingFilename)
                        markDirty(pendingAssignSlot)
                    }
                    // Refresh the MIDI list so the new file shows up in combos.
                    loadMidiFiles()
                } else {
                    statusLabel.text = "Erreur upload " + pendingFilename + ": " + error
                }
                pendingFilename = ""
                pendingAssignSlot = -1
                return
            }
        }
        function onCommandFinished(requestId, success, output, error) {
            // Sync-dialog ssh pings — keep `busy` untouched (these run silently
            // alongside whatever the user is doing).
            if (requestId.indexOf("ping-") === 0) {
                var idx = parseInt(requestId.substring(5))
                setPingState(idx, success ? "online" : "offline")
                return
            }
            busy = false
            if (requestId === "ls-midi") {
                midiFilesModel.clear()
                midiFilesModel.append({ name: "(vide)" })
                if (success) {
                    var lines = output.split("\n").filter(function(l) { return l.trim().length > 0 })
                    for (var i = 0; i < lines.length; i++) {
                        midiFilesModel.append({ name: lines[i].trim() })
                    }
                    midiFilesStatus.text = lines.length + " fichier(s) MIDI"
                } else {
                    midiFilesStatus.text = "Erreur: " + error
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // ==================== TOP CONTROLS ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#2a2a2a"; border.color: "#444"; radius: 6

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Label { text: "Cible:"; color: "#aaa"; font.pixelSize: 12 }
                ComboBox {
                    model: ["Linux Maître", "Raspberry Clic"]
                    currentIndex: 0
                    Layout.preferredWidth: 160
                    onCurrentIndexChanged: targetMachine = currentIndex === 0 ? linuxMaitre : raspberryClic
                }

                Button { text: "Charger";    Layout.preferredHeight: 32; onClicked: loadFromMaster() }
                Button {
                    id: saveButton
                    text: dirtyCount > 0 ? ("Sauvegarder (" + dirtyCount + " modif)") : "Sauvegarder"
                    Layout.preferredHeight: 32
                    background: Rectangle {
                        color: dirtyCount > 0 ? "#FFA500" : "#444"
                        border.color: "#666"; border.width: 1; radius: 4
                    }
                    contentItem: Text {
                        text: parent.text
                        color: dirtyCount > 0 ? "black" : "white"
                        font.bold: dirtyCount > 0
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: saveToMaster()
                }
                Button { text: "Vider";       Layout.preferredHeight: 32; onClicked: makeEmptySlots() }
                Button { text: "Lister MIDI"; Layout.preferredHeight: 32; onClicked: loadMidiFiles() }
                Button {
                    text: "Sync vers sirènes"
                    Layout.preferredHeight: 32
                    onClicked: syncDialog.open()
                }

                BusyIndicator {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    running: busy
                    visible: busy
                }

                Item { Layout.fillWidth: true }

                Label { id: statusLabel; text: ""; color: "#888"; font.pixelSize: 11 }
            }
        }

        // ==================== ACTIVE PATH + MIDI FILES STATUS ====================
        Label {
            text: activePlaylistPath.length > 0
                  ? "Playlist active: " + activePlaylistPath
                  : "Aucune playlist chargée — clique 'Charger' pour récupérer derniere_liste"
            color: "#aaa"
            font.pixelSize: 11
            font.family: "Menlo"
            elide: Text.ElideMiddle
            Layout.fillWidth: true
        }
        // Drop zone for new MIDI files: drag from Finder onto this band to
        // upload to the master's MIDI dir. Multi-file drops are supported.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: globalDrop.containsDrag ? "#3a3a1a" : "#1a1a1a"
            border.color: globalDrop.containsDrag ? "#FFD700" : "#444"
            border.width: globalDrop.containsDrag ? 2 : 1
            radius: 4

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Label {
                    text: "📥"
                    color: "#888"
                    font.pixelSize: 18
                }
                Label {
                    id: midiFilesStatus
                    text: "Glisser des .mid ici pour les uploader sur la cible — ou clique 'Lister MIDI'"
                    color: "#888"
                    font.pixelSize: 11
                    Layout.fillWidth: true
                }
            }

            DropArea {
                id: globalDrop
                anchors.fill: parent
                onDropped: function(drop) {
                    if (!drop.hasUrls) return
                    for (var i = 0; i < drop.urls.length; i++) {
                        uploadLocalMidi(drop.urls[i], -1)
                    }
                    drop.accept()
                }
            }
        }

        // ==================== HEADER ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: "#222"
            radius: 4

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6
                Label { text: "#";       color: "#888"; font.pixelSize: 11; Layout.preferredWidth: 28 }
                Label { text: "Fichier"; color: "#888"; font.pixelSize: 11; Layout.fillWidth: true }
                Label { text: "Pseudo";  color: "#888"; font.pixelSize: 11; Layout.preferredWidth: 200 }
                Label { text: "Boucle";  color: "#888"; font.pixelSize: 11; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignHCenter }
                Label { text: "Enchaîné"; color: "#888"; font.pixelSize: 11; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignHCenter }
            }
        }

        // ==================== 48 SLOTS ====================
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                model: slotsModel
                spacing: 2
                delegate: Rectangle {
                    id: slotRow
                    width: ListView.view.width
                    height: 32
                    color: slotDrop.containsDrag
                           ? "#3a3a1a"
                           : (index % 2 === 0 ? "#2a2a2a" : "#252525")
                    border.color: slotDrop.containsDrag
                                  ? "#FFD700"
                                  : (dirty ? "#FFA500" : "transparent")
                    border.width: (slotDrop.containsDrag || dirty) ? 2 : 0
                    radius: 3

                    DropArea {
                        id: slotDrop
                        anchors.fill: parent
                        onDropped: function(drop) {
                            if (!drop.hasUrls) return
                            // Drop on a slot = upload + auto-assign basename to that slot.
                            // If the user drops several files, only the first is assigned;
                            // the rest just upload to the MIDI dir.
                            uploadLocalMidi(drop.urls[0], index)
                            for (var i = 1; i < drop.urls.length; i++) {
                                uploadLocalMidi(drop.urls[i], -1)
                            }
                            drop.accept()
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 6

                        Label {
                            text: (index + 1).toString()
                            color: "#888"
                            font.pixelSize: 11
                            Layout.preferredWidth: 28
                            horizontalAlignment: Text.AlignRight
                        }

                        ComboBox {
                            id: filenameCombo
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            model: midiFilesModel
                            textRole: "name"
                            editable: true
                            editText: filename
                            onAccepted: {
                                if (editText !== filename) {
                                    slotsModel.setProperty(index, "filename", editText)
                                    markDirty(index)
                                }
                            }
                            onActivated: function(idx) {
                                var name = midiFilesModel.get(idx).name
                                if (name === "(vide)") name = ""
                                if (name !== filename) {
                                    slotsModel.setProperty(index, "filename", name)
                                    markDirty(index)
                                }
                            }
                            // Commit edits as soon as the inline TextField
                            // emits textEdited, same reasoning as the pseudo
                            // field above.
                            Connections {
                                target: filenameCombo.contentItem
                                ignoreUnknownSignals: true
                                function onTextEdited() {
                                    if (filenameCombo.editText !== filename) {
                                        slotsModel.setProperty(index, "filename", filenameCombo.editText)
                                        markDirty(index)
                                    }
                                }
                            }
                        }

                        TextField {
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 24
                            text: pseudo
                            placeholderText: "(pseudo)"
                            // onTextEdited fires on every user keystroke (not on
                            // programmatic text changes, so no feedback loop with
                            // the model). Using onEditingFinished alone could
                            // miss the commit if the user clicks Save while
                            // still focused — the click order vs focus-loss
                            // event isn't guaranteed.
                            onTextEdited: {
                                slotsModel.setProperty(index, "pseudo", text)
                                markDirty(index)
                            }
                        }

                        CheckBox {
                            Layout.preferredWidth: 60
                            Layout.alignment: Qt.AlignHCenter
                            checked: loop
                            onToggled: {
                                slotsModel.setProperty(index, "loop", checked)
                                markDirty(index)
                            }
                        }

                        CheckBox {
                            Layout.preferredWidth: 70
                            Layout.alignment: Qt.AlignHCenter
                            checked: chain
                            onToggled: {
                                slotsModel.setProperty(index, "chain", checked)
                                markDirty(index)
                            }
                        }
                    }
                }
            }
        }
    }

    // ==================== SYNC CONFIRMATION ====================
    Dialog {
        id: syncDialog
        title: "Synchroniser les MIDI vers les machines"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok | Dialog.Cancel

        // Per-target picked state, keyed by syncTargets index. On open, we
        // pre-check based on each target's liveness rule (TRAMPRESENCE for
        // sirens, optimistically true for the others until ping returns).
        property var picked: []
        onOpened: {
            var copy = []
            for (var i = 0; i < syncTargets.length; i++) {
                var t = syncTargets[i]
                if (t.liveness.indexOf("trampresence:") === 0) {
                    var n = parseInt(t.liveness.split(":")[1])
                    copy.push(sirenOnline[n - 1] === true)
                } else {
                    copy.push(true)   // optimistic until ping says otherwise
                }
            }
            picked = copy
            pingAlwaysTargets()
        }

        contentItem: ColumnLayout {
            spacing: 6
            Label {
                text: "Source : " + maitreMidiDir + " (Linux Maître). Le contenu est copié vers chaque cible cochée."
                color: "white"
                wrapMode: Text.Wrap
                Layout.preferredWidth: 460
            }
            Label {
                text: "Pastilles : ● vert = en ligne, ● rouge = hors ligne, ● jaune = ping en cours."
                color: "#888"
                font.pixelSize: 10
                wrapMode: Text.Wrap
                Layout.preferredWidth: 460
            }

            Repeater {
                model: syncTargets
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        Layout.preferredWidth: 10
                        Layout.preferredHeight: 10
                        radius: 5
                        color: statusColor(targetStatus(index))
                    }
                    CheckBox {
                        text: modelData.name
                        checked: syncDialog.picked[index] === true
                        onToggled: {
                            var c = syncDialog.picked.slice()
                            c[index] = checked
                            syncDialog.picked = c
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: modelData.remotePath
                        color: "#666"
                        font.pixelSize: 9
                        font.family: "Menlo"
                    }
                    Label {
                        text: statusLabel(targetStatus(index))
                        color: statusColor(targetStatus(index))
                        font.pixelSize: 10
                        Layout.preferredWidth: 80
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            Label {
                text: "Les fichiers existants sur les cibles cochées seront écrasés."
                color: "#FFA500"
                font.pixelSize: 11
            }
        }
        onAccepted: {
            var indices = []
            for (var i = 0; i < syncTargets.length; i++) if (picked[i]) indices.push(i)
            startSync(indices)
        }
    }

    // ==================== SYNC RESULT ====================
    Dialog {
        id: syncResultDialog
        title: "Résultat de la synchronisation"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok
        property string summary: ""
        contentItem: ColumnLayout {
            spacing: 6
            TextEdit {
                text: syncResultDialog.summary
                readOnly: true
                selectByMouse: true
                color: "white"
                font.family: "Menlo"
                font.pixelSize: 12
                Layout.preferredWidth: 360
                Layout.preferredHeight: 200
                wrapMode: TextEdit.NoWrap
            }
        }
    }
}
