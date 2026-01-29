import QtQuick

Item {
    id: root
    
    property string text: ""
    property real letterSpacing: 40
    property real letterHeight: 30
    property color textColor: "#00ff00"
    property color offColor: "transparent"
    property real segmentWidth: 3
    property real segmentDepth: 2  // Non utilisé en 2D, gardé pour compatibilité
    
    // Définition des segments (identique à LEDText3D)
    property var segmentDefinitions: {
        // Segments horizontaux
        "a": {x: 0, y: 28, r: 90, l: 16},
        "d": {x: 0, y: 0, r: 90, l: 16},
        "g1": {x: -4, y: 14, r: 90, l: 8},
        "g2": {x: 4, y: 14, r: 90, l: 8},
        "a1": {x: -4, y: 28, r: 90, l: 8},
        "a2": {x: 4, y: 28, r: 90, l: 8},
        "d1": {x: -4, y: 0, r: 90, l: 8},
        "d2": {x: 4, y: 0, r: 90, l: 8},
        // Segments verticaux
        "b": {x: 8, y: 21, r: 0, l: 14},
        "c": {x: 8, y: 7, r: 0, l: 14},
        "e": {x: -8, y: 7, r: 0, l: 14},
        "f": {x: -8, y: 21, r: 0, l: 14},
        "i": {x: 0, y: 21, r: 0, l: 14},
        "l": {x: 0, y: 7, r: 0, l: 14},
        // Segments verticaux divisés
        "b1": {x: 8, y: 24.5, r: 0, l: 7},
        "b2": {x: 8, y: 17.5, r: 0, l: 7},
        "c1": {x: 8, y: 10.5, r: 0, l: 7},
        "c2": {x: 8, y: 3.5, r: 0, l: 7},
        "e1": {x: -8, y: 10.5, r: 0, l: 7},
        "e2": {x: -8, y: 3.5, r: 0, l: 7},
        "f1": {x: -8, y: 24.5, r: 0, l: 7},
        "f2": {x: -8, y: 17.5, r: 0, l: 7},
        "i1": {x: 0, y: 24.5, r: 0, l: 7},
        "i2": {x: 0, y: 17.5, r: 0, l: 7},
        "l1": {x: 0, y: 10.5, r: 0, l: 7},
        "l2": {x: 0, y: 3.5, r: 0, l: 7},
        // Segments diagonaux
        "h": {x: -4, y: 21, r: 35, l: 14},
        "j": {x: 4, y: 21, r: -35, l: 14},
        "k": {x: -4, y: 8, r: -35, l: 14},
        "m": {x: 4, y: 8, r: 35, l: 14},
        // Segments additionnels pour grille 4x4
        "n1": {x: -6, y: 21, r: 90, l: 4},
        "n2": {x: -2, y: 21, r: 90, l: 4},
        "n3": {x: -4, y: 25, r: 0, l: 7},
        "n4": {x: -4, y: 17, r: 0, l: 7},
        "n5": {x: 2, y: 21, r: 90, l: 4},
        "n6": {x: 6, y: 21, r: 90, l: 4},
        "n7": {x: 4, y: 25, r: 0, l: 7},
        "n8": {x: 4, y: 17, r: 0, l: 7},
        "n9": {x: -6, y: 7, r: 90, l: 4},
        "n10": {x: -2, y: 7, r: 90, l: 4},
        "n11": {x: -4, y: 11, r: 0, l: 7},
        "n12": {x: -4, y: 3, r: 0, l: 7},
        "n13": {x: 2, y: 7, r: 90, l: 4},
        "n14": {x: 6, y: 7, r: 90, l: 4},
        "n15": {x: 4, y: 11, r: 0, l: 7},
        "n16": {x: 4, y: 3, r: 0, l: 7}
    }
    
    // Définition des caractères (identique à LEDText3D)
    property var characterDefinitions: {
        'A': ["a", "b", "c", "e", "f", "g1", "g2"],
        'B': ["a", "b", "c", "d", "e", "f", "g2", "i", "l"],
        'C': ["a", "d", "e", "f"],
        'D': ["a", "b", "c", "d", "e", "f"],
        'E': ["a", "d", "e", "f", "g1", "g2"],
        'F': ["a", "e", "f", "g1", "g2"],
        'G': ["a", "c", "d", "e", "f", "g2"],
        'H': ["b", "c", "e", "f", "g1", "g2"],
        'I': ["a", "d", "i", "l"],
        'J': ["b", "c", "d", "e"],
        'K': ["e", "f", "g1", "j", "m"],
        'L': ["d", "e", "f"],
        'M': ["b", "c", "e", "f", "h", "j"],
        'N': ["b", "c", "e", "f", "h", "m"],
        'O': ["a", "b", "c", "d", "e", "f"],
        'P': ["a", "b", "e", "f", "g1", "g2"],
        'Q': ["a", "b", "c", "d", "e", "f", "m"],
        'R': ["a", "b", "e", "f", "g1", "g2", "m"],
        'S': ["a", "c", "d", "f", "g1", "g2"],
        'T': ["a", "i", "l"],
        'U': ["b", "c", "d", "e", "f"],
        'V': ["e", "f", "k", "j"],
        'W': ["b", "c", "e", "f", "k", "m"],
        'X': ["h", "j", "k", "m"],
        'Y': ["h", "j", "l"],
        'Z': ["a", "d", "j", "k"],
        'a': ["g1", "l", "d1", "e2", "n9", "n10"],
        'b': ["c", "d", "e", "f", "g1", "g2", "l"],
        'c': ["d", "e", "g1", "g2"],
        'd': ["b", "c", "d", "e", "g1", "g2"],
        'e': ["g1", "l1", "n9", "n10", "e", "d1"],
        'f': ["a", "f", "g1", "i", "l"],
        'g': ["a", "b", "c", "d", "f", "g1", "g2"],
        'h': ["c", "e", "f", "g1", "g2", "l"],
        'i': ["l"],
        'j': ["b", "c", "d"],
        'k': ["e", "f", "i", "l", "m"],
        'l': ["e", "f"],
        'm': ["c", "e", "g1", "g2", "i", "l"],
        'n': ["c", "e", "g1", "g2", "l"],
        'o': ["c", "d", "e", "g1", "g2"],
        'p': ["a", "b", "e", "f", "g1", "g2", "l"],
        'q': ["a", "b", "c", "f", "g1", "g2"],
        'r': ["e", "g1", "g2"],
        's': ["a", "c", "d", "f", "g1", "g2"],
        't': ["d", "e", "f", "g1", "g2"],
        'u': ["c", "d", "e"],
        'v': ["e", "k"],
        'w': ["c", "e", "k", "m"],
        'x': ["g1", "g2", "h", "j", "k", "m"],
        'y': ["b", "c", "d", "f", "g2"],
        'z': ["a", "d", "j", "k"],
        '0': ["a", "b", "c", "d", "e", "f", "j", "k"],
        '1': ["b", "c"],
        '2': ["a", "b", "d", "e", "g1", "g2"],
        '3': ["a", "b", "c", "d", "g1", "g2"],
        '4': ["b", "c", "f", "g1", "g2"],
        '5': ["a", "c", "d", "f", "g1", "g2"],
        '6': ["a", "c", "d", "e", "f", "g1", "g2"],
        '7': ["a", "b", "c"],
        '8': ["a", "b", "c", "d", "e", "f", "g1", "g2"],
        '9': ["a", "b", "c", "d", "f", "g1", "g2"],
        '+': ["g1", "g2", "i", "l"],
        '-': ["g1", "g2"],
        '*': ["g1", "g2", "h", "j", "k", "m"],
        '/': ["j", "k"],
        '=': ["g1", "g2", "d"],
        '<': ["j", "m"],
        '>': ["h", "k"],
        '!': ["b", "c"],
        '?': ["a", "b", "g2", "l"],
        '_': ["d"],
        '|': ["i", "l"],
        '.': ["d"],
        ',': ["k"],
        '(': ["j", "m"],
        ')': ["h", "k"],
        '[': ["a", "d", "e", "f"],
        ']': ["a", "b", "c", "d"],
        '#': ["n3", "n4", "n11", "n12", "n7", "n8", "n15", "n16", "n1", "n2", "n5", "n6", "n9", "n10", "n13", "n14"],
        '@': ["a", "b", "c", "d", "e", "g1", "g2", "i"],
        '&': ["a", "c", "d", "e", "f", "g1", "h", "m"],
        '$': ["a", "c", "d", "f", "g1", "g2", "i", "l"],
        '%': ["a", "f", "g1", "g2", "c", "d", "j", "k"],
        '^': ["h", "j"],
        '°': ["a", "b", "f", "g1"],
        '♯': ["n3", "n4", "n11", "n12", "n7", "n8", "n15", "n16", "n1", "n2", "n5", "n6", "n9", "n10", "n13", "n14"],
        '♭': ["c", "d", "e", "f", "g1", "g2", "l"],
        '♮': ["e", "f", "g1", "g2", "i", "l"],
        ' ': []
    }
    
    // Conversion des caractères accentués (identique à LEDText3D)
    function removeAccents(inputText) {
        var accentMap = {
            'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'æ': 'ae',
            'ç': 'c',
            'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
            'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
            'ñ': 'n',
            'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'œ': 'oe',
            'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
            'ý': 'y', 'ÿ': 'y',
            'À': 'A', 'Á': 'A', 'Â': 'A', 'Ä': 'A', 'Æ': 'AE',
            'Ç': 'C',
            'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E',
            'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I',
            'Ñ': 'N',
            'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Ö': 'O', 'Œ': 'OE',
            'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U',
            'Ý': 'Y'
        };
        
        return inputText.split('').map(function(character) {
            return accentMap[character] || character;
        }).join('');
    }
    
    // Fonction pour obtenir les segments d'un caractère
    function getCharacterSegments(inputCharacter) {
        var cleanCharacter = removeAccents(inputCharacter);
        
        if (characterDefinitions[cleanCharacter] !== undefined) {
            return characterDefinitions[cleanCharacter];
        } else if (characterDefinitions[cleanCharacter.toUpperCase()] !== undefined) {
            return characterDefinitions[cleanCharacter.toUpperCase()];
        }
        return [];
    }
    
    // Créer les lettres une par une
    Repeater {
        model: root.text.length
        
        Item {
            property string currentCharacter: root.text[index]
            property var activeSegments: root.getCharacterSegments(currentCharacter)
            
            x: index * root.letterSpacing - (root.text.length * root.letterSpacing / 2)
            
            Repeater {
                model: Object.keys(root.segmentDefinitions)
                
                LEDSegment2D {
                    property var currentSegmentData: root.segmentDefinitions[modelData]
                    property bool isActive: activeSegments.indexOf(modelData) !== -1
                    
                    x: currentSegmentData.x
                    y: currentSegmentData.y - root.letterHeight/2
                    segmentLength: currentSegmentData.l
                    segmentWidth: root.segmentWidth
                    segmentColor: root.textColor
                    segmentActive: isActive
                    rotationAngle: currentSegmentData.r
                }
            }
        }
    }
}
