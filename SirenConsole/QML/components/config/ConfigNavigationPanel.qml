import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: configNavigationPanel
    
    // Propriétés publiques
    property int currentTabIndex: 0
    
    // Signal émis quand un onglet est sélectionné
    signal tabSelected(int index)
    
    Layout.preferredWidth: 200
    Layout.fillHeight: true
    color: "#333333"
    border.color: "#666666"
    border.width: 1
    radius: 6
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10
        
        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            text: "Sirènes"
            highlighted: configNavigationPanel.currentTabIndex === 0
            onClicked: {
                configNavigationPanel.currentTabIndex = 0
                configNavigationPanel.tabSelected(0)
            }
            
            background: Rectangle {
                color: parent.highlighted ? "#4a90e2" : (parent.hovered ? "#3a3a3a" : "#2a2a2a")
                border.color: parent.highlighted ? "#6bb6ff" : "#555555"
                border.width: 1
                radius: 4
            }
            
            contentItem: Text {
                text: parent.text
                color: parent.highlighted ? "#ffffff" : "#cccccc"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 14
            }
        }
        
        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            text: "Contrôleurs"
            highlighted: configNavigationPanel.currentTabIndex === 1
            onClicked: {
                configNavigationPanel.currentTabIndex = 1
                configNavigationPanel.tabSelected(1)
            }
            
            background: Rectangle {
                color: parent.highlighted ? "#4a90e2" : (parent.hovered ? "#3a3a3a" : "#2a2a2a")
                border.color: parent.highlighted ? "#6bb6ff" : "#555555"
                border.width: 1
                radius: 4
            }
            
            contentItem: Text {
                text: parent.text
                color: parent.highlighted ? "#ffffff" : "#cccccc"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 14
            }
        }
        
        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            text: "Sorties"
            highlighted: configNavigationPanel.currentTabIndex === 2
            onClicked: {
                configNavigationPanel.currentTabIndex = 2
                configNavigationPanel.tabSelected(2)
            }
            
            background: Rectangle {
                color: parent.highlighted ? "#4a90e2" : (parent.hovered ? "#3a3a3a" : "#2a2a2a")
                border.color: parent.highlighted ? "#6bb6ff" : "#555555"
                border.width: 1
                radius: 4
            }
            
            contentItem: Text {
                text: parent.text
                color: parent.highlighted ? "#ffffff" : "#cccccc"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 14
            }
        }
        Item {
            Layout.fillHeight: true
        }
    }
}
