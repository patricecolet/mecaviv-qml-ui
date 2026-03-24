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
    property var test2DPage: null  // Test2D : source de vérité pour options autonomes (persiste en vue normale)

    property bool playAccompaniment: false
    property bool autonomyVolant: false
    property bool autonomyVolet: false
    property bool autonomyVibrato: false
    property bool autonomyTremolo: false
    property bool debugPlayback: false

    // Exposer les dialogs pour NavigationManager
    property alias songSelectorDialog: songSelectorDialog
    /** Référence fournie par Test2D (dialog défini au niveau page) */
    property var gameOptionsDialog: null
    
    // Focus encodeur pour les boutons (reçu depuis Test2D via NavigationManager)
    property int gameModeFocusIndex: -1
    property color gameModeFocusColor: "#00BFFF"

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

    // En microtonal, Options/Morceaux sont rendus dans Test2D (à la place des anciens toggles).
    // En mode jeu normal : empilés verticalement entre Play et Mode Normal, légèrement à droite du centre.
    Column {
        id: transportRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: 130
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        spacing: 8
        visible: !(root.test2DPage && root.test2DPage.useMicrotonalDisplay)

        Rectangle {
            id: openOptionsBtn
            width: Math.max(120, optionsBtnText.contentWidth + 20)
            height: 38
            radius: 8
            property bool isFocused: root.gameModeFocusIndex === 0
            color: "#2a2a2a"
            border.color: isFocused ? root.gameModeFocusColor : "#6bb6ff"
            border.width: isFocused ? 2 : 1
            visible: root.rootWindow ? root.rootWindow.uiControlsEnabled : true

            Text {
                id: optionsBtnText
                anchors.centerIn: parent
                text: "Options"
                color: openOptionsBtn.isFocused ? root.gameModeFocusColor : "#fff"
                font.pixelSize: 13
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.gameOptionsDialog)
                        root.gameOptionsDialog.open()
                }
            }
        }

        Rectangle {
            id: openSongDialogBtn
            width: Math.max(120, songTitleText.contentWidth + 20)
            height: 38
            radius: 8
            property bool isFocused: root.gameModeFocusIndex === 2
            color: "#2a2a2a"
            border.color: isFocused ? root.gameModeFocusColor : "#6bb6ff"
            border.width: isFocused ? 2 : 1
            visible: root.rootWindow ? root.rootWindow.uiControlsEnabled : true

            Text {
                id: songTitleText
                anchors.centerIn: parent
                text: root.sequencer ? (root.sequencer.currentSongTitle || "Morceaux") : "Morceaux"
                color: openSongDialogBtn.isFocused ? root.gameModeFocusColor : "#fff"
                font.pixelSize: 13
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
            if (root.test2DPage) {
                // Défini côté API : présence d'un JSON livret (conductor-cues) à côté du .mid
                root.test2DPage.useMicrotonalDisplay = (file.microtonal === true)
            }
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

}
