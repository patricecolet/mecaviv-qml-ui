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

    function makeEmptySlots() {
        slotsModel.clear()
        for (var i = 0; i < 48; i++) {
            slotsModel.append({ slot: i, filename: "", pseudo: "", loop: false, chain: false })
        }
    }

    Component.onCompleted: makeEmptySlots()

    function loadFromMaster() {
        busy = true
        statusLabel.text = "Chargement de la playlist…"
        SshManager.downloadFile(targetMachine, maitrePlaylistFile, "load-playlist")
    }

    function saveToMaster() {
        busy = true
        statusLabel.text = "Sauvegarde…"
        var lines = []
        for (var i = 0; i < 48; i++) {
            var s = slotsModel.get(i)
            lines.push("{[n=" + s.slot + "]\t\t[s=" + s.filename + "]\t\t\t[a=" +
                       s.pseudo + "]\t\t[B=" + (s.loop ? 1 : 0) + "]\t[E=" +
                       (s.chain ? 1 : 0) + "]}")
        }
        var content = lines.join("\n") + "\n"
        SshManager.uploadFile(targetMachine, maitrePlaylistFile, content, "save-playlist")
    }

    function loadMidiFiles() {
        busy = true
        midiFilesStatus.text = "Chargement…"
        SshManager.executeCommand(targetMachine, "ls -1 " + maitreMidiDir + " | grep -iE '\\.mid$'", "ls-midi")
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
                    chain:    match[5] === "1"
                })
            }
        }
    }

    Connections {
        target: SshManager

        function onDownloadFinished(requestId, success, content, error) {
            busy = false
            if (requestId === "load-playlist") {
                if (success) {
                    parsePlaylist(content)
                    statusLabel.text = "Playlist chargée."
                } else {
                    statusLabel.text = "Erreur: " + error
                }
            }
        }
        function onUploadFinished(requestId, success, error) {
            busy = false
            if (requestId === "save-playlist") {
                statusLabel.text = success ? "Sauvegardé." : ("Erreur: " + error)
            }
        }
        function onCommandFinished(requestId, success, output, error) {
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
                Button { text: "Sauvegarder"; Layout.preferredHeight: 32; onClicked: saveToMaster() }
                Button { text: "Vider";       Layout.preferredHeight: 32; onClicked: makeEmptySlots() }
                Button { text: "Lister MIDI"; Layout.preferredHeight: 32; onClicked: loadMidiFiles() }

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

        // ==================== MIDI FILES + STATUS ====================
        Label {
            id: midiFilesStatus
            text: "MIDI files: cliquer 'Lister MIDI' pour charger les fichiers disponibles"
            color: "#666"
            font.pixelSize: 11
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
                    width: ListView.view.width
                    height: 32
                    color: index % 2 === 0 ? "#2a2a2a" : "#252525"
                    radius: 3

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
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            model: midiFilesModel
                            textRole: "name"
                            editable: true
                            editText: filename
                            onAccepted: slotsModel.setProperty(index, "filename", editText)
                            onActivated: function(idx) {
                                var name = midiFilesModel.get(idx).name
                                if (name === "(vide)") name = ""
                                slotsModel.setProperty(index, "filename", name)
                            }
                        }

                        TextField {
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 24
                            text: pseudo
                            placeholderText: "(pseudo)"
                            onEditingFinished: slotsModel.setProperty(index, "pseudo", text)
                        }

                        CheckBox {
                            Layout.preferredWidth: 60
                            Layout.alignment: Qt.AlignHCenter
                            checked: loop
                            onToggled: slotsModel.setProperty(index, "loop", checked)
                        }

                        CheckBox {
                            Layout.preferredWidth: 70
                            Layout.alignment: Qt.AlignHCenter
                            checked: chain
                            onToggled: slotsModel.setProperty(index, "chain", checked)
                        }
                    }
                }
            }
        }
    }
}
