import QtQuick
import QtQuick3D

Node {
    id: root
    
    property string text: ""
    property real letterSpacing: 40
    property real letterHeight: 30
    property color textColor: "#00ff00"    // Couleur des segments allumés
    property color offColor: "transparent"     // Nouvelle propriété pour segments éteints
    property real segmentWidth: 3
    property real segmentDepth: 2
    
    // NOTE: L'affichage des accents sera implémenté dans la Phase 6
    // Pour l'instant, les caractères accentués sont convertis en caractères sans accent
    
    // Définition des 14 segments selon le standard
    property var segmentDefinitions: {
        // Segments horizontaux
        "a": {x: 0, y: 28, r: 90, l: 16},      // haut
        "d": {x: 0, y: 0, r: 90, l: 16},       // bas
        "g1": {x: -4, y: 14, r: 90, l: 8},     // milieu gauche
        "g2": {x: 4, y: 14, r: 90, l: 8},      // milieu droite
        
        // Segments verticaux
        "b": {x: 8, y: 21, r: 0, l: 14},       // droite haut
        "c": {x: 8, y: 7, r: 0, l: 14},        // droite bas
        "e": {x: -8, y: 7, r: 0, l: 14},       // gauche bas
        "f": {x: -8, y: 21, r: 0, l: 14},      // gauche haut
        "i": {x: 0, y: 21, r: 0, l: 14},       // centre haut
        "l": {x: 0, y: 7, r: 0, l: 14},        // centre bas
        
        // Segments diagonaux
        "h": {x: -4, y: 21, r: 35, l: 14},     // diagonale haut gauche
        "j": {x: 4, y: 21, r: -35, l: 14},     // diagonale haut droite
        "k": {x: -4, y: 8, r: -35, l: 14},     // diagonale bas gauche
        "m": {x: 4, y: 8, r: 35, l: 14}        // diagonale bas droite
    }
    
    // Définition des lettres selon le standard 14 segments
    property var characterDefinitions: {
        // Majuscules
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
        
        // Minuscules
        'a': ["d", "e", "g1", "l"],
        'b': ["c", "d", "e", "f", "g1", "g2", "l"],
        'c': ["d", "e", "g1", "g2"],
        'd': ["b", "c", "d", "e", "g1", "g2"],
        'e': ["a", "d", "e", "f", "g1", "g2"],
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
        
        // Chiffres
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
        
        // Symboles mathématiques
        '+': ["g1", "g2", "i", "l"],
        '-': ["g1", "g2"],
        '*': ["g1", "g2", "h", "j", "k", "m"],
        '/': ["j", "k"],
        '=': ["g1", "g2", "d"],
        '<': ["j", "m"],
        '>': ["h", "k"],
        
        // Ponctuation
        '!': ["b", "c"],
        '?': ["a", "b", "g2", "l"],
        '_': ["d"],
        '|': ["i", "l"],
        '.': ["d"],
        ',': ["k"],
        
        // Parenthèses et crochets
        '(': ["j", "m"],
        ')': ["h", "k"],
        '[': ["a", "d", "e", "f"],
        ']': ["a", "b", "c", "d"],
        
        // Symboles spéciaux
        '#': ["b", "c", "e", "f", "g1", "g2"],
        '@': ["a", "b", "c", "d", "e", "g1", "g2", "i"],
        '&': ["a", "c", "d", "e", "f", "g1", "h", "m"],
        '$': ["a", "c", "d", "f", "g1", "g2", "i", "l"],
        '%': ["a", "f", "g1", "g2", "c", "d", "j", "k"],
        '^': ["h", "j"],
        '°': ["a", "b", "f", "g1"],
        
        // Symboles musicaux
        '♯': ["b", "c", "e", "f", "g1", "g2"],  // dièse
        '♭': ["c", "d", "e", "f", "g1", "g2", "l"],  // bémol
        '♮': ["e", "f", "g1", "g2", "i", "l"],  // bécarre
        
        // Espace
        ' ': []
    }
    
    // Conversion des caractères accentués vers non-accentués
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
        // Enlever les accents si nécessaire
        var cleanCharacter = removeAccents(inputCharacter);
        
        // Si le caractère existe tel quel, le retourner
        if (characterDefinitions[cleanCharacter] !== undefined) {
            return characterDefinitions[cleanCharacter];
        }
        // Sinon essayer en majuscule
        else if (characterDefinitions[cleanCharacter.toUpperCase()] !== undefined) {
            return characterDefinitions[cleanCharacter.toUpperCase()];
        }
        // Sinon retourner un tableau vide
        return [];
    }
    
    // Créer les lettres une par une
    Repeater3D {
        model: root.text.length
        
        Node {
            property string currentCharacter: root.text[index]
            property var activeSegments: root.getCharacterSegments(currentCharacter)
            
            x: index * root.letterSpacing - (root.text.length * root.letterSpacing / 2)
            
            Repeater3D {
                model: Object.keys(root.segmentDefinitions)
                LEDSegment {
                    property var currentSegmentData: root.segmentDefinitions[modelData]
                    property bool isActive: activeSegments.indexOf(modelData) !== -1
                    
                    x: currentSegmentData.x
                    y: currentSegmentData.y - root.letterHeight/2
                    eulerRotation.z: currentSegmentData.r
                    segmentLength: currentSegmentData.l
                    segmentWidth: root.segmentWidth
                    segmentDepth: root.segmentDepth
                    segmentColor: isActive ? root.textColor : root.offColor
                }
            }
        }
    }
}
