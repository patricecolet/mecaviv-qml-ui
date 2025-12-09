import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SirenManager
import "../components"

Rectangle {
    id: root
    color: "#000000"
    
    property int currentPage: 0  // 0 ou 1 (2 pages de 24 slots chacune)
    property int selectedSlot: -1
    property int playingSlot: -1
    property bool isPlaying: false
    property bool isLooping: false
    
    // Données pour les 48 slots (24 par page)
    property var slotsData: []
    
    Component.onCompleted: {
        // Initialiser les 48 slots
        var data = []
        for (var i = 0; i < 48; i++) {
            data.push({
                index: i,
                name: "seq" + i,
                loop: false,
                chain: false
            })
        }
        slotsData = data
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        // ==================== PARTIE HAUTE : BARRES DE LECTURE ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: "#1a1a1a"
            border.color: "#444444"
            border.width: 1
            radius: 5
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 30
                
                // Label Timing (00:00)
                Column {
                    spacing: 5
                    
                    Text {
                        text: "Timing"
                        color: "#888888"
                        font.pixelSize: 14
                        font.family: "AmericanTypewriter-Condensed"
                    }
                    
                    Text {
                        id: timingLabel
                        text: "00:00"
                        color: "#FFFFFF"
                        font.pixelSize: 30
                        font.family: "AmericanTypewriter-Condensed"
                        font.bold: true
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // Label Séquence en cours
                Column {
                    spacing: 5
                    
                    Text {
                        text: "Séquence"
                        color: "#888888"
                        font.pixelSize: 14
                        font.family: "AmericanTypewriter-Condensed"
                    }
                    
                    Text {
                        id: currentSeqLabel
                        text: "seq..."
                        color: "#FFFFFF"
                        font.pixelSize: 20
                        font.family: "AmericanTypewriter-Condensed"
                        font.bold: true
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // Label Temps séquence (00:00)
                Column {
                    spacing: 5
                    
                    Text {
                        text: "Temps"
                        color: "#888888"
                        font.pixelSize: 14
                        font.family: "AmericanTypewriter-Condensed"
                    }
                    
                    Text {
                        id: seqTimeLabel
                        text: "00:00"
                        color: "#FFFFFF"
                        font.pixelSize: 30
                        font.family: "AmericanTypewriter-Condensed"
                        font.bold: true
                    }
                }
            }
        }
        
        // ==================== PARTIE MILIEU : GRID DE SLOTS ====================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                
                // TabBar pour pagination (2 pages)
                TabBar {
                    id: pageTabBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    currentIndex: root.currentPage
                    
                    onCurrentIndexChanged: {
                        root.currentPage = currentIndex
                    }
                    
                    TabButton {
                        text: "Page 1 (1-24)"
                        width: pageTabBar.width / 2
                    }
                    
                    TabButton {
                        text: "Page 2 (25-48)"
                        width: pageTabBar.width / 2
                    }
                }
                
                // Grille de slots (6 colonnes x 4 lignes = 24 slots par page)
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    GridLayout {
                        id: slotsGrid
                        columns: 6
                        rowSpacing: 10
                        columnSpacing: 10
                        
                        Repeater {
                            model: 24  // 24 slots par page
                            
                            PlaylistSlot {
                                id: slotItem
                                property int globalIndex: root.currentPage * 24 + index
                                
                                Layout.preferredWidth: 160
                                Layout.preferredHeight: 130
                                
                                slotIndex: globalIndex
                                filename: slotsData[globalIndex] ? slotsData[globalIndex].name : ""
                                boucle: slotsData[globalIndex] ? slotsData[globalIndex].loop : false
                                enchain: slotsData[globalIndex] ? slotsData[globalIndex].chain : false
                                isSelected: root.selectedSlot === globalIndex
                                isActive: root.playingSlot === globalIndex && root.isPlaying
                                
                                onSlotClicked: {
                                    root.selectedSlot = slotIndex
                                }
                                
                                onSlotDoubleClicked: {
                                    // Toggle loop
                                    if (slotsData[slotIndex]) {
                                        slotsData[slotIndex].loop = !slotsData[slotIndex].loop
                                        slotsData = slotsData  // Trigger update
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // ==================== PARTIE BASSE : SLIDER + TOUS LES BOUTONS ====================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: "#1a1a1a"
            border.color: "#444444"
            border.width: 1
            radius: 5
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10
                
                // Slider de progression temporelle (en haut)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    Slider {
                        id: progressSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: 0
                        
                        background: Rectangle {
                            x: progressSlider.leftPadding
                            y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 8
                            width: progressSlider.availableWidth
                            height: implicitHeight
                            radius: 4
                            color: "#333333"
                            
                            Rectangle {
                                width: progressSlider.visualPosition * parent.width
                                height: parent.height
                                color: "#8B4513"  // Brown
                                radius: 4
                            }
                        }
                        
                        handle: Rectangle {
                            x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                            y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                            implicitWidth: 16
                            implicitHeight: 16
                            radius: 8
                            color: progressSlider.pressed ? "#f0f0f0" : "#f6f6f6"
                            border.color: "#666666"
                            border.width: 2
                        }
                    }
                    
                    BusyIndicator {
                        id: progressIndicator
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        running: root.isPlaying
                        visible: root.isPlaying
                    }
                }
                
                // TOUS LES BOUTONS EN UNE SEULE LIGNE (en bas)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    // BOUCLE
                    Button {
                        id: loopButton
                        text: "BOUCLE"
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 35
                        checkable: true
                        checked: root.isLooping
                        
                        background: Rectangle {
                            color: loopButton.checked ? "#FFD700" : "#444444"
                            border.color: "#666666"
                            border.width: 2
                            radius: 5
                        }
                        
                        contentItem: Text {
                            text: loopButton.text
                            color: loopButton.checked ? "#000000" : "#FFFFFF"
                            font.pixelSize: 13
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onCheckedChanged: {
                            root.isLooping = checked
                        }
                    }
                    
                    // STOP
                    Button {
                        id: stopButton
                        text: "STOP"
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 35
                        
                        background: Rectangle {
                            color: "#444444"
                            border.color: "#666666"
                            border.width: 2
                            radius: 5
                        }
                        
                        contentItem: Text {
                            text: stopButton.text
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            root.isPlaying = false
                            root.playingSlot = -1
                        }
                    }
                    
                    // RESET
                    Button {
                        id: resetButton
                        text: "RESET"
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 35
                        
                        background: Rectangle {
                            color: "#444444"
                            border.color: "#666666"
                            border.width: 2
                            radius: 5
                        }
                        
                        contentItem: Text {
                            text: resetButton.text
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            // Reset logic
                        }
                    }
                    
                    // ST
                    Button {
                        id: stButton
                        text: "ST"
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 35
                        checkable: true
                        
                        background: Rectangle {
                            color: stButton.checked ? "#4444FF" : "#444444"
                            border.color: "#666666"
                            border.width: 2
                            radius: 5
                        }
                        
                        contentItem: Text {
                            text: stButton.text
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    
                    // SYNC (bouton avec icône - action de synchronisation)
                    Button {
                        id: syncButton
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 35
                        
                        background: Rectangle {
                            color: syncButton.pressed ? "#555555" : "#444444"
                            border.color: "#666666"
                            border.width: 2
                            radius: 5
                        }
                        
                        contentItem: Text {
                            text: "🔄"  // Icône de synchronisation
                            color: "#FFFFFF"
                            font.pixelSize: 18
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            console.log("SYNC clicked - sending CMD_ASKSYNCHRO")
                            // udpController.sendAskSynchro(MachineType.LinuxMaitre)
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Contrôles de reprise
                    Text {
                        text: "Index:"
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                    }
                    
                    SpinBox {
                        id: indexSpinBox
                        from: 1
                        to: 48
                        value: 1
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 30
                    }
                    
                    Text {
                        text: "Mesure:"
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                    }
                    
                    TextField {
                        id: measureField
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 30
                        text: "0"
                        validator: IntValidator { bottom: 0 }
                    }
                    
                    Button {
                        id: resumeButton
                        text: "REPRENDRE"
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 30
                        
                        background: Rectangle {
                            color: resumeButton.pressed ? "#555555" : "#444444"
                            border.color: "#666666"
                            border.width: 2
                            radius: 5
                        }
                        
                        contentItem: Text {
                            text: resumeButton.text
                            color: "#FFFFFF"
                            font.pixelSize: 12
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            console.log("REPRENDRE from Index: " + indexSpinBox.value + ", Mesure: " + measureField.text)
                        }
                    }
                }
            }
        }
    }
}
