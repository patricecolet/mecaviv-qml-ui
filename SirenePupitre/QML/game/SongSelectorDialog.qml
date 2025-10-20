import QtQuick
import QtQuick.Controls

Dialog {
    id: songSelectorDialog
    modal: true
    focus: true
    width: Math.min(parent ? parent.width * 0.8 : 1000, 1000)
    height: Math.min(parent ? parent.height * 0.8 : 640, 640)
    title: "Choisir un morceau"
    
    // API publique
    property var categoriesModel: []        // [{ name, files:[{ title, path }] }]
    property string selectedCategory: ""
    signal songChosen(var file)
    
    // Conteneur principal
    Item {
        anchors.fill: parent
        anchors.margins: 16
        
        // Liste catégories (gauche)
        ListView {
            id: catList
            width: 240
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            model: songSelectorDialog.categoriesModel
            clip: true
            spacing: 4
            
            delegate: Rectangle {
                width: parent ? parent.width : 240
                height: 40
                radius: 6
                color: (songSelectorDialog.selectedCategory === modelData.name) ? "#3a3a3a" : "#2a2a2a"
                border.color: "#555"
                border.width: 1
                
                Text {
                    anchors.centerIn: parent
                    text: modelData.name
                    color: "#ccc"
                    font.pixelSize: 14
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        songSelectorDialog.selectedCategory = modelData.name
                    }
                }
            }
        }
        
        // Liste fichiers (droite)
        ListView {
            id: fileList
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: catList.right
            anchors.right: parent.right
            anchors.leftMargin: 12
            clip: true
            spacing: 6
            
            model: {
                var cats = songSelectorDialog.categoriesModel || [];
                for (var i = 0; i < cats.length; i++) {
                    if (cats[i].name === songSelectorDialog.selectedCategory) {
                        return cats[i].files || [];
                    }
                }
                return [];
            }
            
            delegate: Rectangle {
                width: parent ? parent.width : 400
                height: 44
                radius: 6
                color: "#2a2a2a"
                border.color: "#555"
                border.width: 1
                
                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    
                    Text {
                        text: modelData.title || modelData.path
                        color: "#eee"
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        songSelectorDialog.songChosen(modelData);
                        songSelectorDialog.close();
                    }
                }
            }
            
            // Message si pas de catégorie sélectionnée
            Text {
                visible: songSelectorDialog.selectedCategory === "" || fileList.count === 0
                anchors.centerIn: parent
                text: songSelectorDialog.selectedCategory === "" ? "← Sélectionnez une catégorie" : "Aucun fichier"
                color: "#666666"
                font.pixelSize: 16
            }
        }
    }
}


