import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property var configController: null
    
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // Menu latéral
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 200
            color: "#1a1a1a"
            border.color: "#333"
            border.width: 0
            
            ListView {
                id: menuList
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5
                
                property int currentIndex: 0
                
                model: ListModel {
                    ListElement { name: "Affichages principaux"; section: "main" }
                    ListElement { name: "Portée musicale"; section: "staff" }
                    ListElement { name: "Contrôleurs"; section: "controllers" }
                }
                
                delegate: Rectangle {
                    width: parent.width
                    height: 40
                    color: menuList.currentIndex === index ? "#2a2a2a" : "transparent"
                    border.color: menuList.currentIndex === index ? "#FFD700" : "transparent"
                    border.width: 1
                    radius: 5
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: menuList.currentIndex = index
                    }
                    
                    Text {
                        text: name
                        color: menuList.currentIndex === index ? "#FFD700" : "#888"
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 15
                    }
                }
            }
        }
        
        // Séparateur
        Rectangle {
            Layout.fillHeight: true
            width: 1
            color: "#333"
        }
        
        // Contenu principal
        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true
            
            // Loader pour les sous-composants
            Loader {
                id: contentLoader
                anchors.fill: parent
                source: {
                    var section = menuList.model.get(menuList.currentIndex).section
                    switch(section) {
                        case "main": 
                            return "qrc:/QML/admin/visibility/VisibilityMainDisplays.qml"
                        case "staff": 
                            return "qrc:/QML/admin/visibility/VisibilityMusicalStaff.qml"
                        case "controllers": 
                            return "qrc:/QML/admin/visibility/VisibilityControllers.qml"
                        default: 
                            return "qrc:/QML/admin/visibility/VisibilityMainDisplays.qml"
                    }
                }
                
                onLoaded: {
                    if (item && configController) {
                        item.configController = configController
                    }
                }
                
                onSourceChanged: {
                    console.log("Loading visibility section:", source)
                }
            }
        }
    }
    
    // Debug pour vérifier le chargement
    onConfigControllerChanged: {
        if (configController) {
            console.log("VisibilitySection - configController maintenant disponible:", configController)
            
            // Forcer la mise à jour du Loader si nécessaire
            if (contentLoader.item) {
                contentLoader.item.configController = configController
            }
        }
    }
}
