import QtQuick
import QtQuick.Controls
import "../utils"

/**
 * HUD (Head-Up Display) du mode jeu
 * Affiche score, combo, précision et leaderboard
 */
Rectangle {
    id: root
    
    property int score: 0
    property int combo: 0
    property int accuracy: 0  // 0-100%
    property var leaderboard: []
    property int pupitreId: 1
    
    color: "#20000000"
    
    Row {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 20
        
        // Score (gauche)
        Item {
            width: 300
            height: parent.height
            
            Column {
                anchors.centerIn: parent
                spacing: 5
                
                Text {
                    text: "SCORE"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#888888"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                LEDText3D {
                    text: root.score.toString().padStart(6, '0')
                    letterHeight: 40
                    letterSpacing: 25
                    textColor: "#FFD700"  // Or
                }
            }
        }
        
        // Combo (centre gauche)
        Item {
            width: 200
            height: parent.height
            
            Column {
                anchors.centerIn: parent
                spacing: 5
                
                Text {
                    text: "COMBO"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#888888"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 5
                    
                    Text {
                        text: "×"
                        font.pixelSize: 30
                        font.bold: true
                        color: root.combo >= 10 ? "#00FF00" : "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    LEDText3D {
                        text: root.combo.toString().padStart(3, '0')
                        letterHeight: 35
                        letterSpacing: 22
                        textColor: root.combo >= 10 ? "#00FF00" : "#00CED1"
                    }
                }
            }
        }
        
        // Précision (centre)
        Item {
            width: 200
            height: parent.height
            
            Column {
                anchors.centerIn: parent
                spacing: 5
                
                Text {
                    text: "PRÉCISION"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#888888"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 5
                    
                    LEDText3D {
                        text: root.accuracy.toString().padStart(3, ' ')
                        letterHeight: 35
                        letterSpacing: 22
                        textColor: root.accuracy >= 90 ? "#00FF00" : 
                                  root.accuracy >= 75 ? "#FFD700" : "#FF6600"
                    }
                    
                    Text {
                        text: "%"
                        font.pixelSize: 30
                        font.bold: true
                        color: "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                // Barre de progression
                Rectangle {
                    width: 180
                    height: 8
                    color: "#333333"
                    radius: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    Rectangle {
                        width: parent.width * (root.accuracy / 100.0)
                        height: parent.height
                        color: root.accuracy >= 90 ? "#00FF00" : 
                               root.accuracy >= 75 ? "#FFD700" : "#FF6600"
                        radius: 4
                        
                        Behavior on width {
                            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
        }
        
        // Spacer
        Item {
            width: parent.width - 1050  // 300 + 200 + 200 + 350
            height: parent.height
        }
        
        // Leaderboard (droite)
        Item {
            width: 350
            height: parent.height
            
            Column {
                anchors.fill: parent
                spacing: 3
                
                Text {
                    text: "CLASSEMENT"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#888888"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                ListView {
                    width: parent.width
                    height: parent.height - 20
                    clip: true
                    spacing: 2
                    
                    model: root.leaderboard
                    
                    delegate: Rectangle {
                        width: parent ? parent.width : 0
                        height: 20
                        color: modelData.pupitreId === root.pupitreId ? "#40FFD700" : "#20FFFFFF"
                        radius: 3
                        border.color: modelData.rank === 1 ? "#FFD700" : 
                                     modelData.rank === 2 ? "#C0C0C0" :
                                     modelData.rank === 3 ? "#CD7F32" : "transparent"
                        border.width: 2
                        
                        Row {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 10
                            
                            // Rang
                            Text {
                                width: 30
                                text: "#" + modelData.rank
                                font.pixelSize: 14
                                font.bold: true
                                color: modelData.rank === 1 ? "#FFD700" : 
                                       modelData.rank === 2 ? "#C0C0C0" :
                                       modelData.rank === 3 ? "#CD7F32" : "#FFFFFF"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            // Pupitre ID
                            Text {
                                width: 50
                                text: "P" + modelData.pupitreId
                                font.pixelSize: 14
                                font.bold: modelData.pupitreId === root.pupitreId
                                color: "#00CED1"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            // Score
                            Text {
                                width: 80
                                text: modelData.score.toString()
                                font.pixelSize: 13
                                color: "#FFFFFF"
                                horizontalAlignment: Text.AlignRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            // Combo
                            Text {
                                width: 60
                                text: "×" + modelData.combo
                                font.pixelSize: 12
                                color: "#00FF00"
                                horizontalAlignment: Text.AlignRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            // Accuracy
                            Text {
                                width: 50
                                text: modelData.accuracy + "%"
                                font.pixelSize: 12
                                color: modelData.accuracy >= 90 ? "#00FF00" : "#FFD700"
                                horizontalAlignment: Text.AlignRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}

