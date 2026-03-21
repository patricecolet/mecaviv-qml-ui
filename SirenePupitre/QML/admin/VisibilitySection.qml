import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property var configController: null
    // Focus encodeur dans le panneau Admin (reçu depuis AdminPanel)
    property int adminFocusIndex: -1
    property color focusColor: "#00BFFF"

    // Index de la section sélectionnée dans le menu latéral (0, 1, 2)
    property int selectedMenuIndex: 0

    // Index relatif pour les sous-composants (adminFocusIndex - 2, car 0=TabBar, 1=modeSwitch, 2=menu, 3+=contenu)
    // Les sous-composants utilisent adminFocusIndex === 1 pour leur premier élément
    readonly property int contentFocusIndex: (root.adminFocusIndex >= 3) ? (root.adminFocusIndex - 2) : -1

    // Exposer pour NavigationManager
    property alias contentLoader: contentLoader

    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // Menu latéral — entouré en bleu quand l'encodeur est sur le focus 2
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 200
            color: "#1a1a1a"
            border.color: root.adminFocusIndex === 2 ? root.focusColor : "#333"
            border.width: root.adminFocusIndex === 2 ? 2 : 0
            radius: 3
            
            Column {
                id: menuColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5
                
                Repeater {
                    model: [
                        { name: "Affichages principaux", section: "main" },
                        { name: "Portée musicale",       section: "staff" },
                        { name: "Contrôleurs",           section: "controllers" }
                    ]
                    
                    delegate: Rectangle {
                        width: menuColumn.width
                        height: 40
                        property bool isSelected: root.selectedMenuIndex === index
                        color: isSelected ? "#2a2a2a" : "transparent"
                        border.color: isSelected ? "#FFD700" : "transparent"
                        border.width: isSelected ? 2 : 0
                        radius: 5
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.selectedMenuIndex = index
                        }
                        
                        Text {
                            text: modelData.name
                            color: parent.isSelected ? "#FFD700" : "#888"
                            font.pixelSize: 14
                            font.bold: parent.isSelected
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 15
                        }
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
            
            Loader {
                id: contentLoader
                anchors.fill: parent
                source: {
                    switch(root.selectedMenuIndex) {
                        case 0: return "qrc:/QML/admin/visibility/VisibilityMainDisplays.qml"
                        case 1: return "qrc:/QML/admin/visibility/VisibilityMusicalStaff.qml"
                        case 2: return "qrc:/QML/admin/visibility/VisibilityControllers.qml"
                        default: return "qrc:/QML/admin/visibility/VisibilityMainDisplays.qml"
                    }
                }
                
                onLoaded: {
                    if (item) {
                        if (configController)
                            item.configController = configController
                        // Passer l'index relatif aux sous-composants (décalé de 2)
                        if (item.hasOwnProperty("adminFocusIndex"))
                            item.adminFocusIndex = Qt.binding(function() { return root.contentFocusIndex })
                        if (item.hasOwnProperty("focusColor"))
                            item.focusColor = Qt.binding(function() { return root.focusColor })
                    }
                }
            }
        }
    }
    
    onConfigControllerChanged: {
        if (configController && contentLoader.item) {
            contentLoader.item.configController = configController
        }
    }
}
