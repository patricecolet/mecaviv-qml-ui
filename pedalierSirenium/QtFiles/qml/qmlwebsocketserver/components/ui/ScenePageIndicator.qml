import QtQuick

Item {
    id: root
    property int currentPage: 1
    property int pageCount: 8
    property var hasScene   // ← c'est bien "var" ici !
    property int activeSceneId: 0
    property var sceneManager  // ← Ajouter cette propriété

    width: 100
    height: 60

    // Forcer la mise à jour quand les scènes changent
    property int updateTrigger: 0
    
    // Connexion pour écouter les changements de scènes
    Connections {
        target: root.sceneManager
        function onScenesUpdated() {
            root.updateTrigger++
        }
    }

    Column {
        spacing: 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        // Ligne 0 : Numéro de page
        Text {
            text: root.currentPage + "/" + root.pageCount
            color: "white"
            font.pixelSize: 12
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Container pour les flèches et les carrés
        Item {
            width: 100
            height: 42
            
            // Flèche précédente (positionnée absolument)
            Rectangle {
                id: prevButton
                width: 24
                height: 42
                x: 0
                y: 0
                color: prevPageMouseArea.pressed ? "#505050" : "#404040"
                border.color: "#808080"
                border.width: 1
                radius: 3
                enabled: root.currentPage > 1
                opacity: enabled ? 1.0 : 0.5

                Text {
                    text: "◀"
                    color: "white"
                    font.pixelSize: 12
                    anchors.centerIn: parent
                }
                MouseArea {
                    id: prevPageMouseArea
                    anchors.fill: parent
                    enabled: parent.enabled
                    onClicked: {
                        if (root.currentPage > 1) root.currentPage--
                    }
                }
            }
            
            // Flèche suivante (positionnée absolument)
            Rectangle {
                id: nextButton
                width: 24
                height: 42
                x: 98
                y: 0
                color: nextPageMouseArea.pressed ? "#505050" : "#404040"
                border.color: "#808080"
                border.width: 1
                radius: 3
                enabled: root.currentPage < root.pageCount
                opacity: enabled ? 1.0 : 0.5

                Text {
                    text: "▶"
                    font.family: window.globalEmojiFont
                    color: "white"
                    font.pixelSize: 12
                    anchors.centerIn: parent
                }
                MouseArea {
                    id: nextPageMouseArea
                    anchors.fill: parent
                    enabled: parent.enabled
                    onClicked: {
                        if (root.currentPage < root.pageCount) root.currentPage++
                    }
                }
            }

            // Ligne 1 : Scènes 5-8
            Row {
                x: 26
                y: 0
                spacing: 2
            
                Repeater {
                    model: 4
                    Rectangle {
                        width: 16
                        height: 20
                        color: {
                            let sceneIndex = index + 5;
                            let globalSceneId = (root.currentPage - 1) * 8 + sceneIndex;
                            // Forcer la mise à jour en utilisant updateTrigger
                            root.updateTrigger;
                            if (!root.hasScene || !root.hasScene(globalSceneId)) {
                                return "#404040";
                            }
                            if (globalSceneId === root.activeSceneId) {
                                return "#4CAF50";
                            }
                            return "#D4AF37";  // Jaune foncé
                        }
                        border.color: "#808080"
                        border.width: 1
                        radius: 2
                    }
                }
            }
            
            // Ligne 2 : Scènes 1-4
            Row {
                x: 26
                y: 22
                spacing: 2
            
                Repeater {
                    model: 4
                    Rectangle {
                        width: 16
                        height: 20
                        color: {
                            let sceneIndex = index + 1;
                            let globalSceneId = (root.currentPage - 1) * 8 + sceneIndex;
                            // Forcer la mise à jour en utilisant updateTrigger
                            root.updateTrigger;
                            if (!root.hasScene || !root.hasScene(globalSceneId)) {
                                return "#404040";
                            }
                            if (globalSceneId === root.activeSceneId) {
                                return "#4CAF50";
                            }
                            return "#D4AF37";  // Jaune foncé
                        }
                        border.color: "#808080"
                        border.width: 1
                        radius: 2
                    }
                }
            }
        }
    }
}