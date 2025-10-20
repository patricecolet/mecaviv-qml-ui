import QtQuick
import QtQuick.Controls
import "."

Item {
    id: root
    property var configController: null
    property string currentSongTitle: ""  // Titre du morceau en cours
    property bool isPlaying: false  // État de la lecture
    
    // Connexion au signal de position de lecture pour suivre l'état
    Component.onCompleted: {
        if (root.configController && root.configController.webSocketController) {
            root.configController.webSocketController.playbackPositionReceived.connect(function(playing, bar, beatInBar, beat) {
                root.isPlaying = playing;
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
                            console.log("✅ Chargé", response.categories.length, "catégories de morceaux MIDI");
                        }
                    } catch (e) {
                        console.error("❌ Erreur parsing réponse MIDI files:", e);
                    }
                } else {
                    console.error("❌ Erreur chargement MIDI files:", xhr.status);
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
        console.log("🔍 Chargement MIDI files depuis:", apiUrl);
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
        
        // ▶ Play
        Rectangle {
            width: 44
            height: 44
            radius: 8
            color: root.isPlaying ? "#1a5a3a" : "#2a2a2a"  // Vert foncé quand en lecture
            border.color: root.isPlaying ? "#4ade80" : "#6bb6ff"  // Bordure verte quand en lecture
            border.width: root.isPlaying ? 2 : 1
            
            // Animation de pulsation quand en lecture
            SequentialAnimation on opacity {
                running: root.isPlaying
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.7; duration: 800 }
                NumberAnimation { from: 0.7; to: 1.0; duration: 800 }
            }
            
            Text {
                anchors.centerIn: parent
                text: "▶︎"
                color: root.isPlaying ? "#4ade80" : "#fff"  // Texte vert quand en lecture
                font.pixelSize: 18
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.configController && root.configController.webSocketController) {
                        root.configController.webSocketController.sendBinaryMessage({
                            type: "MIDI_TRANSPORT",
                            action: "play",
                            source: "pupitre"
                        });
                        // Mettre à jour l'état localement (sera confirmé par le signal)
                        root.isPlaying = true;
                    }
                }
            }
        }
        
        // ⏸ Pause
        Rectangle {
            width: 44
            height: 44
            radius: 8
            color: "#2a2a2a"
            border.color: "#6bb6ff"
            border.width: 1
            
            Text {
                anchors.centerIn: parent
                text: "⏸"
                color: "#fff"
                font.pixelSize: 18
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.configController && root.configController.webSocketController) {
                        root.configController.webSocketController.sendBinaryMessage({
                            type: "MIDI_TRANSPORT",
                            action: "pause",
                            source: "pupitre"
                        });
                        // Mettre à jour l'état localement
                        root.isPlaying = false;
                    }
                }
            }
        }
        
        // ⏹ Stop
        Rectangle {
            width: 44
            height: 44
            radius: 8
            color: "#2a2a2a"
            border.color: "#6bb6ff"
            border.width: 1
            
            Text {
                anchors.centerIn: parent
                text: "⏹"
                color: "#fff"
                font.pixelSize: 18
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.configController && root.configController.webSocketController) {
                        root.configController.webSocketController.sendBinaryMessage({
                            type: "MIDI_TRANSPORT",
                            action: "stop",
                            source: "pupitre"
                        });
                        // Mettre à jour l'état localement
                        root.isPlaying = false;
                    }
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
                console.log("✅ Morceau chargé:", file.title, "- Appuyez sur Play pour lancer");
            }
        }
    }
}


