import QtQuick
import QtQuick.Controls
import "."

/**
 * Panel transport + sélection morceau.
 * Si sequencer est fourni : affichage et chargement via sequencer (indépendant du jeu).
 * Sinon : comportement legacy (état propre + mise à jour gameMode).
 */
Item {
    id: root
    property var configController: null
    property var rootWindow: null
    property var gameMode: null
    property var sequencer: null  // Contrôleur séquenceur partagé (plusieurs jeux possibles)

    property bool playAccompaniment: true
    property bool debugPlayback: false

    // Clic Stop : reset séquenceur et état jeu
    property bool uiPlaying: root.rootWindow ? root.rootWindow.isGamePlaying : false
    onUiPlayingChanged: {
        if (!uiPlaying) {
            if (root.sequencer) root.sequencer.reset()
            if (root.gameMode) root.gameMode.resetGame()
        }
    }

    function loadMidiFilesList() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText)
                    if (response.type === "MIDI_FILES_LIST" && response.categories) {
                        songSelectorDialog.categoriesModel = response.categories
                        if (response.categories.length > 0)
                            songSelectorDialog.selectedCategory = response.categories[0].name
                    }
                } catch (e) {}
            }
        }
        var apiUrl = Qt.resolvedUrl("/api/midi/files").toString()
        if (apiUrl.startsWith("file://") || apiUrl.startsWith("qrc:"))
            apiUrl = "http://" + (typeof window !== "undefined" ? window.location.host : "localhost:8000") + "/api/midi/files"
        xhr.open("GET", apiUrl)
        xhr.send()
    }

    Row {
        id: transportRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.margins: 20
        spacing: 16

        Rectangle {
            id: openOptionsBtn
            width: Math.max(100, optionsBtnText.contentWidth + 20)
            height: 44
            radius: 8
            color: "#2a2a2a"
            border.color: "#6bb6ff"
            border.width: 1
            visible: root.rootWindow ? root.rootWindow.uiControlsEnabled : true

            Text {
                id: optionsBtnText
                anchors.centerIn: parent
                anchors.margins: 10
                text: "Options"
                color: "#fff"
                font.pixelSize: 14
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: gameOptionsDialog.open()
            }
        }

        Rectangle {
            id: openSongDialogBtn
            width: Math.max(140, songTitleText.contentWidth + 20)
            height: 44
            radius: 8
            color: "#2a2a2a"
            border.color: "#6bb6ff"
            border.width: 1
            visible: root.rootWindow ? root.rootWindow.uiControlsEnabled : true

            Text {
                id: songTitleText
                anchors.centerIn: parent
                anchors.margins: 10
                text: root.sequencer ? (root.sequencer.currentSongTitle || "Morceaux") : "Morceaux"
                color: "#fff"
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.loadMidiFilesList()
                    songSelectorDialog.open()
                }
            }
        }
    }

    SongSelectorDialog {
        id: songSelectorDialog
        onSongChosen: function(file) {
            if (root.configController && root.configController.webSocketController) {
                if (root.sequencer) {
                    root.sequencer.loadSong(file.path, file.title)
                }
                root.configController.webSocketController.sendBinaryMessage({
                    type: "MIDI_FILE_LOAD",
                    path: file.path,
                    source: "pupitre"
                })
            }
        }
    }

    GameOptionsDialog {
        id: gameOptionsDialog
        configController: root.configController
        playAccompaniment: root.playAccompaniment
        pupitreId: "P1"
        onAccompanimentChanged: function(enabled) {
            root.playAccompaniment = enabled
        }
    }
}
