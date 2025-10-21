import QtQuick
import QtQuick3D
import "../../../shared/qml/common"

Node {
    id: root
    
    // Propriétés requises
    required property real currentNoteMidi
    property real ambitusMin: 43
    property real ambitusMax: 86
    property bool gameMode: false  // NOUVEAU : pour ajuster en mode jeu
    
    // Configuration visuelle
    property color cylinderColor: "white"
    property color textColor: "black"
    property color indicatorColor: "red"
    property real cylinderRadius: 100     // Rayon du cylindre
    property real noteCylinderLength: 100  // Longueur du cylindre des notes (réduite)
    property real octaveCylinderLength: 60 // Longueur du cylindre des octaves (plus petit)
    property int visibleNotesCount: 5     // Nombre de notes visibles à travers la fenêtre
    
    // Ajustement de la position du cadre selon le mode
    property real frameYOffset: gameMode ? 4 : 0  // Légèrement plus haut en mode jeu
    
    // Rotation continue (accumule sans reset pour éviter les sauts)
    property real degreesPerSemitone: 30
    property real accumulatedRotation: 0
    property real previousNoteMidi: currentNoteMidi
    
    onCurrentNoteMidiChanged: {
        var noteDiff = currentNoteMidi - previousNoteMidi
        
        // Gérer les sauts d'octave (Si → Do)
        if (noteDiff > 6) {
            noteDiff -= 12  // Si on saute vers le haut (Si3 → Do4)
        } else if (noteDiff < -6) {
            noteDiff += 12  // Si on saute vers le bas (Do4 → Si3)
        }
        
        accumulatedRotation -= noteDiff * degreesPerSemitone
        previousNoteMidi = currentNoteMidi
    }
    
    property real targetRotation: accumulatedRotation
    
    // Instances utilitaires
    MusicUtils {
        id: musicUtils
    }
    
    Component.onCompleted: {
        // Initialiser la rotation selon la note actuelle
        var noteInOctave = currentNoteMidi - Math.floor(currentNoteMidi / 12) * 12
        accumulatedRotation = -noteInOctave * degreesPerSemitone
    }
    
    // === CYLINDRE DES NOTES (gauche) ===
    Node {
        id: notesCylinderNode
        x: -20  // Décalé à gauche
        eulerRotation.z: 90  // Horizontal
        
        // Container qui tourne
        Node {
            id: notesRotatingContainer
            eulerRotation.y: root.targetRotation  // Rotation instantanée, ultra-réactive
            
            // Cylindre blanc des notes
            Model {
                source: "#Cylinder"
                scale: Qt.vector3d(
                    root.cylinderRadius / 50,
                    root.noteCylinderLength / 100,
                    root.cylinderRadius / 50
                )
                materials: PrincipledMaterial {
                    baseColor: root.cylinderColor
                    metalness: 0.1
                    roughness: 0.7
                }
            }
            
            // Afficher 12 notes chromatiques (une octave complète)
            Repeater3D {
            model: 12  // 12 notes chromatiques
            
            Node {
                id: noteNode
                
                // Index de la note (0-11)
                property int noteIndex: index
                
                // Nom de la note (juste Do, Ré, Mi... sans octave)  
                property string noteName: musicUtils.noteNames[noteIndex]
                
                // Angle de cette note autour du cylindre
                // Offset de -90° pour que index 0 (Do) soit face caméra (Z positif)
                property real angle: (index * 30) + 10  // -90° pour Do face caméra à index 0
                property real angleRad: angle * Math.PI / 180
                
                // Position sur la surface du cylindre (coordonnées cylindriques)
                // Le cylindre est VERTICAL dans ce référentiel (avant rotation Z:90 du parent)
                property real xPos: root.cylinderRadius * Math.sin(angleRad)
                property real yPos: 0  // Toutes à la même hauteur
                property real zPos: root.cylinderRadius * Math.cos(angleRad)
                
                position: Qt.vector3d(xPos, yPos, zPos)
                
                // Rotation pour que le texte face vers l'extérieur (autour de Y)
                eulerRotation.y: angle
                
                Component.onCompleted: {
                }
                
                // Texte de la note en LED 3D
                LEDText3D {
                    id: noteLED
                    text: noteNode.noteName
                    
                    // LEDText3D se centre automatiquement en interne via sa ligne 203
                    // Avec eulerRotation Z:270°, les axes sont transformés :
                    // - Pour déplacer le long du cylindre : ajustez Y
                    // - Pour rapprocher/éloigner du cylindre : ajustez Z
                    // - Pour monter/descendre (hauteur) : ajustez X
                    position: Qt.vector3d(-23, -10, 2)
                    eulerRotation: Qt.vector3d(0, 0, 270)
                    letterHeight: 12
                    letterSpacing: 25
                    segmentWidth: 3
                    segmentDepth: 1.5
                    textColor: "#000000"
                    offColor: "white"
                }
            }
            }
        }
    }
    
    // === CYLINDRE DES OCTAVES (droite) ===
    Node {
        id: octavesCylinderNode
        x: 80  // Décalé à droite
        eulerRotation.z: 90  // Horizontal
        
        // Rotation basée sur l'octave actuelle
        property int currentOctave: Math.floor(root.currentNoteMidi / 12) - 1  // -1 car octave 0 = MIDI 12-23
        property real octaveRotation: -currentOctave * 45  // 8 octaves = 360° / 8 = 45° par octave
        
        // Container qui tourne
        Node {
            eulerRotation.y: parent.octaveRotation  // Rotation instantanée, ultra-réactive
            
            // Cylindre blanc des octaves (plus petit)
            Model {
                source: "#Cylinder"
                scale: Qt.vector3d(
                    root.cylinderRadius / 50,
                    root.octaveCylinderLength / 100,
                    root.cylinderRadius / 50
                )
                materials: PrincipledMaterial {
                    baseColor: root.cylinderColor
                    metalness: 0.1
                    roughness: 0.7
                }
            }
            
            // Afficher 8 octaves (0-7)
            Repeater3D {
                model: 8
                
                Node {
                    property int octaveNumber: index
                    
                    // Angle autour du cylindre (360° / 8 = 45° par octave)
                    property real angle: (index * 45) - 7  // Même offset que les notes
                    property real angleRad: angle * Math.PI / 180
                    
                    // Position cylindrique
                    property real xPos: root.cylinderRadius * Math.sin(angleRad)
                    property real yPos: 0
                    property real zPos: root.cylinderRadius * Math.cos(angleRad)
                    
                    position: Qt.vector3d(xPos, yPos, zPos)
                    eulerRotation.y: angle
                    
                    // Texte de l'octave
                    LEDText3D {
                        id: octaveLED
                        text: "" + parent.octaveNumber  // Convertir en string
                        
                        // LEDText3D se centre automatiquement
                        // Même transformation d'axes qu'au-dessus
                        position: Qt.vector3d(7, 0, 2)
                        eulerRotation: Qt.vector3d(0, 0, 270)
                        letterHeight: 12
                        letterSpacing: 25
                        segmentWidth: 3
                        segmentDepth: 1.5
                        textColor: "#000000"
                    }
                }
            }
        }
    }
    
    // === CADRES ROUGES ===
    
    // Cadre autour du cylindre des notes (gauche)
    property real frameHeight: 0.40
    property real frameHalfHeight: frameHeight * 100 / 2
    
    // Barre haut (notes)
    Model {
        source: "#Cube"
        scale: Qt.vector3d(noteCylinderLength / 100 + 0.3, 0.03, 0.03)
        position: Qt.vector3d(-20, frameHalfHeight + root.frameYOffset, cylinderRadius + 15)
        
        materials: PrincipledMaterial {
            baseColor: root.indicatorColor
            metalness: 0.4
            roughness: 0.5
        }
    }
    
    // Barre bas (notes)
    Model {
        source: "#Cube"
        scale: Qt.vector3d(noteCylinderLength / 100 + 0.3, 0.03, 0.03)
        position: Qt.vector3d(-20, -frameHalfHeight + root.frameYOffset, cylinderRadius + 15)
        
        materials: PrincipledMaterial {
            baseColor: root.indicatorColor
            metalness: 0.4
            roughness: 0.5
        }
    }
    
    // Barre gauche (notes)
    Model {
        source: "#Cube"
        scale: Qt.vector3d(0.03, frameHeight, 0.03)
        position: Qt.vector3d(-20 - noteCylinderLength/2, root.frameYOffset, cylinderRadius + 15)
        
        materials: PrincipledMaterial {
            baseColor: root.indicatorColor
            metalness: 0.4
            roughness: 0.5
        }
    }
    
    // Barre droite (notes)
    Model {
        source: "#Cube"
        scale: Qt.vector3d(0.03, frameHeight, 0.03)
        position: Qt.vector3d(-20 + noteCylinderLength/2, root.frameYOffset, cylinderRadius + 15)
        
        materials: PrincipledMaterial {
            baseColor: root.indicatorColor
            metalness: 0.4
            roughness: 0.5
        }
    }
    
    // === CADRE OCTAVES ===
    
    // Barre haut (octaves)
    Model {
        source: "#Cube"
        scale: Qt.vector3d(octaveCylinderLength / 100 + 0.3, 0.03, 0.03)
        position: Qt.vector3d(80, frameHalfHeight + root.frameYOffset, cylinderRadius + 15)
        
        materials: PrincipledMaterial {
            baseColor: root.indicatorColor
            metalness: 0.4
            roughness: 0.5
        }
    }
    
    // Barre bas (octaves)
    Model {
        source: "#Cube"
        scale: Qt.vector3d(octaveCylinderLength / 100 + 0.3, 0.03, 0.03)
        position: Qt.vector3d(80, -frameHalfHeight + root.frameYOffset, cylinderRadius + 15)
        
        materials: PrincipledMaterial {
            baseColor: root.indicatorColor
            metalness: 0.4
            roughness: 0.5
        }
    }
    
    // Barre gauche (octaves)
    Model {
        source: "#Cube"
        scale: Qt.vector3d(0.03, frameHeight, 0.03)
        position: Qt.vector3d(75 - octaveCylinderLength/2, root.frameYOffset, cylinderRadius + 15)
        
        materials: PrincipledMaterial {
            baseColor: root.indicatorColor
            metalness: 0.4
            roughness: 0.5
        }
    }
    
    // Barre droite (octaves)
    Model {
        source: "#Cube"
        scale: Qt.vector3d(0.03, frameHeight, 0.03)
        position: Qt.vector3d(80 + octaveCylinderLength/2, root.frameYOffset, cylinderRadius + 15)
        
        materials: PrincipledMaterial {
            baseColor: root.indicatorColor
            metalness: 0.4
            roughness: 0.5
        }
    }
}

