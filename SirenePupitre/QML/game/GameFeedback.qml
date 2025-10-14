import QtQuick
import QtQuick.Controls

/**
 * Feedback visuel pour les hits (Perfect/Good/Miss)
 * Affiche une animation au centre de l'écran
 */
Item {
    id: root
    
    width: 400
    height: 200
    
    property int lastRating: -1
    property int lastScore: 0
    
    // Afficher le feedback
    function show(rating, score) {
        lastRating = rating
        lastScore = score
        
        // Déclencher l'animation
        feedbackAnimation.restart()
        particleSystem.burst(rating === 2 ? 50 : 20)  // Plus de particules pour Perfect
    }
    
    // Animation de feedback
    SequentialAnimation {
        id: feedbackAnimation
        
        PropertyAnimation {
            target: feedbackText
            property: "opacity"
            from: 0
            to: 1
            duration: 100
        }
        
        PropertyAnimation {
            target: feedbackText
            property: "scale"
            from: 0.5
            to: 1.5
            duration: 200
            easing.type: Easing.OutBack
        }
        
        PauseAnimation { duration: 400 }
        
        PropertyAnimation {
            target: feedbackText
            property: "opacity"
            from: 1
            to: 0
            duration: 200
        }
        
        PropertyAnimation {
            target: feedbackText
            property: "scale"
            from: 1.5
            to: 0.5
            duration: 200
        }
    }
    
    // Texte de feedback
    Item {
        id: feedbackText
        anchors.centerIn: parent
        opacity: 0
        scale: 1
        
        Column {
            anchors.centerIn: parent
            spacing: 10
            
            // Texte du rating
            Text {
                text: root.lastRating === 2 ? "PERFECT!" :
                      root.lastRating === 1 ? "GOOD" :
                      root.lastRating === 0 ? "OK" :
                      "MISS"
                font.pixelSize: 80
                font.bold: true
                color: root.lastRating === 2 ? "#FFD700" :  // Or
                       root.lastRating === 1 ? "#00FF00" :  // Vert
                       root.lastRating === 0 ? "#FFFF00" :  // Jaune
                       "#FF0000"  // Rouge
                style: Text.Outline
                styleColor: "#000000"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            // Score gagné
            Text {
                text: "+" + root.lastScore
                font.pixelSize: 40
                font.bold: true
                color: "#FFFFFF"
                style: Text.Outline
                styleColor: "#000000"
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.lastScore > 0
            }
        }
    }
    
    // Système de particules (effet visuel)
    Item {
        id: particleSystem
        anchors.centerIn: parent
        
        function burst(count) {
            for (var i = 0; i < count; i++) {
                var particle = particleComponent.createObject(particleSystem, {
                    "startX": 0,
                    "startY": 0,
                    "angle": Math.random() * 360,
                    "speed": 100 + Math.random() * 200,
                    "particleColor": root.lastRating === 2 ? "#FFD700" : "#00CED1"
                })
            }
        }
    }
    
    // Composant particule
    Component {
        id: particleComponent
        
        Rectangle {
            id: particle
            width: 8
            height: 8
            radius: 4
            
            property real startX: 0
            property real startY: 0
            property real angle: 0
            property real speed: 150
            property color particleColor: "#FFD700"
            
            color: particleColor
            opacity: 1
            
            Component.onCompleted: {
                x = startX
                y = startY
                particleAnimation.start()
            }
            
            ParallelAnimation {
                id: particleAnimation
                
                NumberAnimation {
                    target: particle
                    property: "x"
                    from: particle.startX
                    to: particle.startX + Math.cos(particle.angle * Math.PI / 180) * particle.speed
                    duration: 800
                    easing.type: Easing.OutQuad
                }
                
                NumberAnimation {
                    target: particle
                    property: "y"
                    from: particle.startY
                    to: particle.startY + Math.sin(particle.angle * Math.PI / 180) * particle.speed
                    duration: 800
                    easing.type: Easing.OutQuad
                }
                
                NumberAnimation {
                    target: particle
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: 800
                }
                
                onFinished: {
                    particle.destroy()
                }
            }
        }
    }
}
