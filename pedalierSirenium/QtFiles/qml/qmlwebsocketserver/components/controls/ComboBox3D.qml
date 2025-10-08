import QtQuick
import QtQuick3D
import QtQuick.Controls

Node {
    id: root

    // Propriétés exposées
    property string title: "Title"
    property var model: ["Item 1", "Item 2", "Item 3"]
    property int currentIndex: 0
    property string currentText: model[currentIndex]
    property int width: 150
    property color titleColor: "white"
    property color backgroundColor: "black"
    property color textColor: "white"
    property int fontSize: 14

    // Signal émis lorsque la sélection change
    signal selectionChanged(string newValue)

    // Nœud pour contenir les éléments UI
    Node {
        // Utiliser un Item comme conteneur pour les contrôles Qt Quick
        Item {
            width: root.width
            height: 70  // Hauteur suffisante pour le titre et le ComboBox

            Column {
                spacing: 5
                width: parent.width

                // Titre du ComboBox
                Text {
                    text: root.title
                    color: root.titleColor
                    font.pixelSize: root.fontSize
                    font.bold: true
                }

                // ComboBox
                ComboBox {
                    id: comboBox
                    width: parent.width
                    model: root.model
                    currentIndex: root.currentIndex

                    // Style personnalisé pour le ComboBox
                    background: Rectangle {
                        color: root.backgroundColor
                        border.color: "gray"
                        border.width: 1
                        radius: 2
                    }

                    contentItem: Text {
                        text: comboBox.displayText
                        color: root.textColor
                        font.pixelSize: root.fontSize
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                    }

                    // Style pour le menu déroulant
                    popup: Popup {
                        y: comboBox.height
                        width: comboBox.width
                        implicitHeight: contentItem.implicitHeight
                        padding: 1

                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: comboBox.popup.visible ? comboBox.delegateModel : null

                            ScrollIndicator.vertical: ScrollIndicator {}
                        }

                        background: Rectangle {
                            color: root.backgroundColor
                            border.color: "gray"
                            border.width: 1
                            radius: 2
                        }
                    }

                    delegate: ItemDelegate {
                        width: comboBox.width
                        contentItem: Text {
                            text: modelData
                            color: root.textColor
                            font.pixelSize: root.fontSize
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 10
                        }
                        highlighted: comboBox.highlightedIndex === index

                        background: Rectangle {
                            color: highlighted ? "darkgray" : root.backgroundColor
                        }
                    }

                    onCurrentIndexChanged: {
                        if (root.currentIndex !== currentIndex) {
                            root.currentIndex = currentIndex;
                            root.currentText = model[currentIndex];
                            root.selectionChanged(root.currentText);
                        }
                    }
                }
            }

            // Activer le layer pour que les contrôles soient visibles dans la scène 3D
            layer.enabled: true
            layer.smooth: true
        }
    }

    // Méthode pour définir la valeur actuelle
    function setValue(value) {
        for (let i = 0; i < model.length; i++) {
            if (model[i] === value) {
                currentIndex = i;
                break;
            }
        }
    }
}
