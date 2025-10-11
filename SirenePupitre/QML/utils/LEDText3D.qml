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
        "a": {x: 0, y: 28, r: 90, l: 16},      // haut (complet)
        "d": {x: 0, y: 0, r: 90, l: 16},       // bas (complet)
        "g1": {x: -4, y: 14, r: 90, l: 8},     // milieu gauche
        "g2": {x: 4, y: 14, r: 90, l: 8},      // milieu droite
        
        // Segments horizontaux divisés en deux
        "a1": {x: -4, y: 28, r: 90, l: 8},     // haut gauche
        "a2": {x: 4, y: 28, r: 90, l: 8},      // haut droite
        "d1": {x: -4, y: 0, r: 90, l: 8},      // bas gauche
        "d2": {x: 4, y: 0, r: 90, l: 8},       // bas droite
        
        // Segments verticaux
        "b": {x: 8, y: 21, r: 0, l: 14},       // droite haut (complet)
        "c": {x: 8, y: 7, r: 0, l: 14},        // droite bas (complet)
        "e": {x: -8, y: 7, r: 0, l: 14},       // gauche bas (complet)
        "f": {x: -8, y: 21, r: 0, l: 14},      // gauche haut (complet)
        "i": {x: 0, y: 21, r: 0, l: 14},       // centre haut (complet)
        "l": {x: 0, y: 7, r: 0, l: 14},        // centre bas (complet)
        
        // Segments verticaux divisés en deux (pour "e" minuscule, etc.)
        "b1": {x: 8, y: 24.5, r: 0, l: 7},     // droite haut-supérieur
        "b2": {x: 8, y: 17.5, r: 0, l: 7},     // droite haut-inférieur
        "c1": {x: 8, y: 10.5, r: 0, l: 7},     // droite bas-supérieur
        "c2": {x: 8, y: 3.5, r: 0, l: 7},      // droite bas-inférieur
        "e1": {x: -8, y: 10.5, r: 0, l: 7},    // gauche bas-supérieur
        "e2": {x: -8, y: 3.5, r: 0, l: 7},     // gauche bas-inférieur
        "f1": {x: -8, y: 24.5, r: 0, l: 7},    // gauche haut-supérieur
        "f2": {x: -8, y: 17.5, r: 0, l: 7},    // gauche haut-inférieur
        "i1": {x: 0, y: 24.5, r: 0, l: 7},     // centre haut-supérieur
        "i2": {x: 0, y: 17.5, r: 0, l: 7},     // centre haut-inférieur
        "l1": {x: 0, y: 10.5, r: 0, l: 7},     // centre bas-supérieur
        "l2": {x: 0, y: 3.5, r: 0, l: 7},      // centre bas-inférieur
        
        // Segments diagonaux
        "h": {x: -4, y: 21, r: 35, l: 14},     // diagonale haut gauche
        "j": {x: 4, y: 21, r: -35, l: 14},     // diagonale haut droite
        "k": {x: -4, y: 8, r: -35, l: 14},     // diagonale bas gauche
        "m": {x: 4, y: 8, r: 35, l: 14},       // diagonale bas droite
        
        // === Segments additionnels pour grille 4x4 (16 segments) ===
        // Chaque case contient un "+" formé de 4 segments :
        // - 2 horizontaux (gauche/droite) : __ __
        // - 2 verticaux (haut/bas) : | au-dessus et en-dessous
        
        // Case 1 (Haut-Gauche) - Centre (-4, 21)
        "n1": {x: -6, y: 21, r: 90, l: 4},     // horizontal gauche
        "n2": {x: -2, y: 21, r: 90, l: 4},     // horizontal droite
        "n3": {x: -4, y: 25, r: 0, l: 7},      // vertical haut (allongé)
        "n4": {x: -4, y: 17, r: 0, l: 7},      // vertical bas (allongé)
        
        // Case 2 (Haut-Droite) - Centre (4, 21)
        "n5": {x: 2, y: 21, r: 90, l: 4},      // horizontal gauche
        "n6": {x: 6, y: 21, r: 90, l: 4},      // horizontal droite
        "n7": {x: 4, y: 25, r: 0, l: 7},       // vertical haut (allongé)
        "n8": {x: 4, y: 17, r: 0, l: 7},       // vertical bas (allongé)
        
        // Case 3 (Bas-Gauche) - Centre (-4, 7)
        "n9": {x: -6, y: 7, r: 90, l: 4},      // horizontal gauche
        "n10": {x: -2, y: 7, r: 90, l: 4},     // horizontal droite
        "n11": {x: -4, y: 11, r: 0, l: 7},     // vertical haut (allongé)
        "n12": {x: -4, y: 3, r: 0, l: 7},      // vertical bas (allongé)
        
        // Case 4 (Bas-Droite) - Centre (4, 7)
        "n13": {x: 2, y: 7, r: 90, l: 4},      // horizontal gauche
        "n14": {x: 6, y: 7, r: 90, l: 4},      // horizontal droite
        "n15": {x: 4, y: 11, r: 0, l: 7},      // vertical haut (allongé)
        "n16": {x: 4, y: 3, r: 0, l: 7}        // vertical bas (allongé)
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
        'a': ["g1", "l", "d1", "e2", "n9", "n10"],  // a minuscule : barre milieu + vertical central bas + bas gauche + vertical gauche inférieur + barre interne
        'b': ["c", "d", "e", "f", "g1", "g2", "l"],
        'c': ["d", "e", "g1", "g2"],
        'd': ["b", "c", "d", "e", "g1", "g2"],
        'e': ["g1", "l1", "n9", "n10", "e", "d1"],  // e minuscule : barre milieu gauche + centre bas-sup + barre interne + vertical gauche + bas gauche
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
        '#': [
            // Même définition que ♯ : 2 colonnes verticales + 2 lignes horizontales
            "n3", "n4", "n11", "n12",    // colonne gauche (x=-4)
            "n7", "n8", "n15", "n16",    // colonne droite (x=4)
            "n1", "n2", "n5", "n6",      // ligne haute (y=21)
            "n9", "n10", "n13", "n14"    // ligne basse (y=7)
        ],
        '@': ["a", "b", "c", "d", "e", "g1", "g2", "i"],
        '&': ["a", "c", "d", "e", "f", "g1", "h", "m"],
        '$': ["a", "c", "d", "f", "g1", "g2", "i", "l"],
        '%': ["a", "f", "g1", "g2", "c", "d", "j", "k"],
        '^': ["h", "j"],
        '°': ["a", "b", "f", "g1"],
        
        // Symboles musicaux
        '♯': [
            // 2 colonnes verticales (gauche et droite)
            "n3", "n4", "n11", "n12",    // colonne gauche (x=-4)
            "n7", "n8", "n15", "n16",    // colonne droite (x=4)
            // 2 lignes horizontales (haute et basse)
            "n1", "n2", "n5", "n6",      // ligne haute (y=21)
            "n9", "n10", "n13", "n14"    // ligne basse (y=7)
        ],  // dièse
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
                    segmentColor: root.textColor     // Toujours la couleur du texte
                    segmentActive: isActive          // Contrôle la visibilité
                }
            }
        }
    }
}
