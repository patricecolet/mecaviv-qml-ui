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
    
    // Navigation encodeur
    property int encoderFocusIndex: 0  // 0 = catégories, 1 = fichiers
    property int selectedCategoryIndex: 0
    property int selectedFileIndex: 0
    property color focusColor: "#00BFFF"
    
    readonly property int focusCount: 2  // catégories + fichiers
    
    function handleEncoderStep(delta) {
        var step = (delta > 0) ? 1 : -1
        if (encoderFocusIndex === 0) {
            // Navigation dans les catégories
            var newIdx = selectedCategoryIndex + step
            if (newIdx < 0) newIdx = 0
            if (newIdx >= categoriesModel.length) newIdx = categoriesModel.length - 1
            if (newIdx !== selectedCategoryIndex && categoriesModel.length > 0) {
                selectedCategoryIndex = newIdx
                selectedCategory = categoriesModel[selectedCategoryIndex].name
            }
        } else {
            // Navigation dans les fichiers
            var files = _getCurrentCategoryFiles()
            var newIdx = selectedFileIndex + step
            if (newIdx < 0) newIdx = 0
            if (newIdx >= files.length) newIdx = files.length - 1
            selectedFileIndex = newIdx
        }
    }
    
    function handleEncoderClick() {
        if (encoderFocusIndex === 0) {
            // Passer aux fichiers
            encoderFocusIndex = 1
            selectedFileIndex = 0
            // Scroll vers le premier fichier
            Qt.callLater(function() {
                fileList.positionViewAtIndex(0, ListView.Beginning)
            })
        } else {
            // Sélectionner le fichier
            var files = _getCurrentCategoryFiles()
            if (files.length > 0 && selectedFileIndex >= 0 && selectedFileIndex < files.length) {
                songChosen(files[selectedFileIndex])
                close()
            }
        }
    }
    
    function _getCurrentCategoryFiles() {
        for (var i = 0; i < categoriesModel.length; i++) {
            if (categoriesModel[i].name === selectedCategory) {
                return categoriesModel[i].files || []
            }
        }
        return []
    }
    
    onSelectedCategoryChanged: {
        selectedFileIndex = 0
        // Mettre à jour selectedCategoryIndex
        for (var i = 0; i < categoriesModel.length; i++) {
            if (categoriesModel[i].name === selectedCategory) {
                selectedCategoryIndex = i
                break
            }
        }
    }
    
    onSelectedCategoryIndexChanged: {
        // Scroll vers la catégorie sélectionnée
        if (encoderFocusIndex === 0 && selectedCategoryIndex >= 0) {
            Qt.callLater(function() {
                catList.positionViewAtIndex(selectedCategoryIndex, ListView.Center)
            })
        }
    }
    
    onSelectedFileIndexChanged: {
        // Scroll vers le fichier sélectionné
        if (encoderFocusIndex === 1) {
            Qt.callLater(function() {
                fileList.positionViewAtIndex(selectedFileIndex, ListView.Center)
            })
        }
    }
    
    onOpened: {
        encoderFocusIndex = 0
        selectedFileIndex = 0
        if (categoriesModel.length > 0 && selectedCategoryIndex >= categoriesModel.length) {
            selectedCategoryIndex = 0
            selectedCategory = categoriesModel[0].name
        }
    }
    
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
            
            // Scroll vers l'élément sélectionné
            onModelChanged: {
                if (songSelectorDialog.encoderFocusIndex === 0 && selectedCategoryIndex >= 0) {
                    Qt.callLater(function() {
                        catList.positionViewAtIndex(selectedCategoryIndex, ListView.Center)
                    })
                }
            }
            
            delegate: Rectangle {
                width: parent ? parent.width : 240
                height: 40
                radius: 6
                property bool isSelected: songSelectorDialog.selectedCategory === modelData.name
                property bool isFocused: songSelectorDialog.encoderFocusIndex === 0 && songSelectorDialog.selectedCategoryIndex === index
                color: isSelected ? "#3a3a3a" : "#2a2a2a"
                border.color: isFocused ? songSelectorDialog.focusColor : (isSelected ? "#555" : "#333")
                border.width: isFocused ? 2 : 1
                
                Text {
                    anchors.centerIn: parent
                    text: modelData.name
                    color: isFocused ? songSelectorDialog.focusColor : (isSelected ? "#fff" : "#ccc")
                    font.pixelSize: 14
                    font.bold: isFocused || isSelected
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        songSelectorDialog.selectedCategory = modelData.name
                        songSelectorDialog.selectedCategoryIndex = index
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
            
            // Scroll vers l'élément sélectionné
            onModelChanged: {
                if (songSelectorDialog.encoderFocusIndex === 1 && selectedFileIndex >= 0) {
                    Qt.callLater(function() {
                        fileList.positionViewAtIndex(selectedFileIndex, ListView.Center)
                    })
                }
            }
            
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
                property bool isFocused: songSelectorDialog.encoderFocusIndex === 1 && songSelectorDialog.selectedFileIndex === index
                color: "#2a2a2a"
                border.color: isFocused ? songSelectorDialog.focusColor : "#555"
                border.width: isFocused ? 2 : 1
                
                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    
                    Text {
                        text: modelData.title || modelData.path
                        color: isFocused ? songSelectorDialog.focusColor : "#eee"
                        font.pixelSize: 14
                        font.bold: isFocused
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        songSelectorDialog.selectedFileIndex = index
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


