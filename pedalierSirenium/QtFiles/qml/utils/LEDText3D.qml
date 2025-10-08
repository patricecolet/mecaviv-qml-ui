import QtQuick
import QtQuick3D

Node {
    id: root
    
    property string text: ""
    property real letterSpacing: 40
    property real letterHeight: 30
    property color textColor: "#00ff00"
    property real segmentWidth: 3
    property real segmentDepth: 2
    
    // Définition des lettres avec leurs segments
    // Utilisation d'un système simple pour positionner les segments
    property var letterDefinitions: {
        'A': [{x: -10, y: 0, r: 90, l: 20}, {x: 10, y: 0, r: 90, l: 20}, 
              {x: -10, y: 15, r: 90, l: 20}, {x: 10, y: 15, r: 90, l: 20},
              {x: 0, y: 30, r: 0, l: 20}, {x: 0, y: 15, r: 0, l: 20}],
        'B': [{x: -10, y: 0, r: 90, l: 30}, {x: 0, y: 30, r: 0, l: 20},
              {x: 0, y: 15, r: 0, l: 20}, {x: 0, y: 0, r: 0, l: 20},
              {x: 10, y: 22.5, r: 90, l: 15}, {x: 10, y: 7.5, r: 90, l: 15}],
        'C': [{x: -10, y: 0, r: 90, l: 30}, {x: 0, y: 30, r: 0, l: 20},
              {x: 0, y: 0, r: 0, l: 20}],
        'D': [{x: -10, y: 0, r: 90, l: 30}, {x: 0, y: 30, r: 0, l: 20},
              {x: 0, y: 0, r: 0, l: 20}, {x: 10, y: 15, r: 90, l: 30}],
        'E': [{x: -10, y: 0, r: 90, l: 30}, {x: 0, y: 30, r: 0, l: 20},
              {x: 0, y: 15, r: 0, l: 15}, {x: 0, y: 0, r: 0, l: 20}],
        'H': [{x: -10, y: 0, r: 90, l: 30}, {x: 10, y: 0, r: 90, l: 30},
              {x: 0, y: 15, r: 0, l: 20}],
        'L': [{x: -10, y: 0, r: 90, l: 30}, {x: 0, y: 0, r: 0, l: 20}],
        'P': [{x: -10, y: 0, r: 90, l: 30}, {x: 0, y: 30, r: 0, l: 20},
              {x: 0, y: 15, r: 0, l: 20}, {x: 10, y: 22.5, r: 90, l: 15}],
        'R': [{x: -10, y: 0, r: 90, l: 30}, {x: 0, y: 30, r: 0, l: 20},
              {x: 0, y: 15, r: 0, l: 20}, {x: 10, y: 22.5, r: 90, l: 15},
              {x: 10, y: 7.5, r: 135, l: 15}],
        'S': [{x: 0, y: 30, r: 0, l: 20}, {x: -10, y: 22.5, r: 90, l: 15},
              {x: 0, y: 15, r: 0, l: 20}, {x: 10, y: 7.5, r: 90, l: 15},
              {x: 0, y: 0, r: 0, l: 20}],
        'T': [{x: 0, y: 30, r: 0, l: 30}, {x: 0, y: 0, r: 90, l: 30}],
        'V': [{x: -10, y: 10, r: 80, l: 25}, {x: 10, y: 10, r: 100, l: 25},
              {x: -5, y: 30, r: 70, l: 15}, {x: 5, y: 30, r: 110, l: 15}],
        ' ': [],
        '1': [{x: 0, y: 0, r: 90, l: 30}],
        '2': [{x: 0, y: 30, r: 0, l: 20}, {x: 10, y: 22.5, r: 90, l: 15},
              {x: 0, y: 15, r: 0, l: 20}, {x: -10, y: 7.5, r: 90, l: 15},
              {x: 0, y: 0, r: 0, l: 20}],
        '3': [{x: 0, y: 30, r: 0, l: 20}, {x: 10, y: 15, r: 90, l: 30},
              {x: 0, y: 15, r: 0, l: 20}, {x: 0, y: 0, r: 0, l: 20}],
        '4': [{x: -10, y: 15, r: 90, l: 15}, {x: 10, y: 0, r: 90, l: 30},
              {x: 0, y: 15, r: 0, l: 20}],
        '5': [{x: 0, y: 30, r: 0, l: 20}, {x: -10, y: 22.5, r: 90, l: 15},
              {x: 0, y: 15, r: 0, l: 20}, {x: 10, y: 7.5, r: 90, l: 15},
              {x: 0, y: 0, r: 0, l: 20}],
        '6': [{x: -10, y: 0, r: 90, l: 30}, {x: 0, y: 30, r: 0, l: 20},
              {x: 0, y: 15, r: 0, l: 20}, {x: 10, y: 7.5, r: 90, l: 15},
              {x: 0, y: 0, r: 0, l: 20}],
        '7': [{x: 0, y: 30, r: 0, l: 20}, {x: 10, y: 0, r: 90, l: 30}]
    }
    
    function generatePositions() {
        var positions = [];
        var xPos = 0;
        
        for (var i = 0; i < root.text.length; i++) {
            var letter = root.text[i].toUpperCase();
            if (root.letterDefinitions[letter]) {
                positions.push({char: letter, x: xPos});
                xPos += root.letterSpacing;
            }
        }
        return positions;
    }
    
    Repeater3D {
        model: generatePositions()
        
        Node {
            x: modelData.x - (root.text.length * root.letterSpacing / 2)
            
            Repeater3D {
                model: root.letterDefinitions[modelData.char]
                
                LEDSegment {
                    x: modelData.x
                    y: modelData.y - root.letterHeight/2
                    eulerRotation.z: modelData.r
                    segmentLength: modelData.l
                    segmentWidth: root.segmentWidth
                    segmentDepth: root.segmentDepth
                    segmentColor: root.textColor
                }
            }
        }
    }
}
