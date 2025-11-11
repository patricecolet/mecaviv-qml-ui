import QtQuick
import QtQuick.Controls
import "."

Item {
    id: root
    property var configController: null
    property string currentSongTitle: ""  // Titre du morceau en cours
    property bool isPlaying: false  // État de la lecture
    
    // Propriétés pour détecter le stop
    property real previousBeat: -1
    property var gameMode: null  // Référence à GameMode (définie par le parent)
    
    // Connexion au signal de position de lecture pour suivre l'état
    Component.onCompleted: {
        if (root.configController && root.configController.webSocketController) {
            root.configController.webSocketController.playbackPositionReceived.connect(function(playing, bar, beatInBar, beat) {
                // Détecter un stop (passage à beat = 0)
                var wasPlaying = root.isPlaying
                var isStopped = (!playing && beat === 0.0 && bar === 1 && beatInBar === 1)
                
                // Si on détecte un stop, réinitialiser le mode jeu
                if (isStopped && (root.previousBeat > 0 || wasPlaying)) {
                    if (root.gameMode) {
                        root.gameMode.resetGame()
                    }
                }
                
                // Mettre à jour l'état
                root.isPlaying = playing
                root.previousBeat = beat
            });
        }
    }
    
    // Fonction pour charger la liste des morceaux depuis l'API HTTP
    function loadMidiFilesList() {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        if (response.type === "MIDI_FILES_LIST" && response.categories) {
                            songSelectorDialog.categoriesModel = response.categories;
                            if (response.categories.length > 0) {
                                songSelectorDialog.selectedCategory = response.categories[0].name;
                            }
                        }
                    } catch (e) {
                        // Error parsing response
                    }
                } else {
                    // Error loading MIDI files
                }
            }
        };
        // Construire l'URL complète (nécessaire pour Qt WebAssembly)
        var apiUrl = Qt.resolvedUrl("/api/midi/files").toString();
        // Si Qt.resolvedUrl ne fonctionne pas correctement, utiliser window.location
        if (apiUrl.startsWith("file://") || apiUrl.startsWith("qrc:")) {
            // Fallback: construire manuellement l'URL avec le protocole et l'hôte
            apiUrl = "http://" + (typeof window !== 'undefined' ? window.location.host : "localhost:8000") + "/api/midi/files";
        }
        xhr.open("GET", apiUrl);
        xhr.send();
    }
    
    // Contrôles transport et sélection de morceau (centrés en bas)
    Row {
        id: transportRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.margins: 20
        spacing: 10
        
        // Bouton d'ouverture du sélecteur (à gauche des boutons de transport)
        Rectangle {
            id: openSongDialogBtn
            width: Math.max(140, songTitleText.contentWidth + 20)
            height: 44
            radius: 8
            color: "#2a2a2a"
            border.color: "#6bb6ff"
            border.width: 1
            
            Text {
                id: songTitleText
                anchors.centerIn: parent
                anchors.margins: 10
                text: root.currentSongTitle || "Morceau…"
                color: "#fff"
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // Charger la liste des fichiers depuis l'API HTTP
                    root.loadMidiFilesList();
                    songSelectorDialog.open();
                }
            }
        }
    }
    
    // Modale de sélection
    SongSelectorDialog {
        id: songSelectorDialog
        
        onSongChosen: function(file) {
            if (root.configController && root.configController.webSocketController) {
                // Mettre à jour le titre affiché
                root.currentSongTitle = file.title;
                
                // Charger le fichier (sans lancer la lecture automatiquement)
                root.configController.webSocketController.sendBinaryMessage({
                    type: "MIDI_FILE_LOAD",
                    path: file.path,
                    source: "pupitre"
                });
            }
        }
    }
}


