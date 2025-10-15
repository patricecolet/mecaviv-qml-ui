import QtQuick
import QtQuick3D

// FallingNote avec géométrie segmentée pour queue de release lisse
Node {
    id: noteModel
    
    // Propriétés publiques (identiques à FallingCube)
    property real targetY: 0
    property real targetX: 0
    property real spawnHeight: 500
    property real fallSpeed: 150
    property color cubeColor: "#00CED1"
    property real velocity: 127  // Vélocité de la note (0-127)
    property real duration: 1000  // Durée en ms
    property real releaseTime: 500  // Durée du release en ms
    
    // Position
    property real currentY: spawnHeight + totalHeight
    property real currentX: targetX
    property real cubeZ: -50
    property real cubeSize: 0.4  // Taille proportionnelle à la vélocité
    
    // Calculs de hauteurs
    property real sustainHeight: Math.max(0.1, (duration / 1000.0) * fallSpeed / 2.0)
    property real releaseHeight: Math.max(0.05, (releaseTime / 1000.0) * fallSpeed / 2.0)
    property real totalHeight: sustainHeight + releaseHeight
    
    // Paramètres de segmentation
    property int sustainSegments: 1  // Nombre de segments pour le sustain
    property int releaseSegments: 4  // Nombre de segments pour la queue (déformable)
    
    // Calcul des hauteurs de segment
    property real sustainSegmentHeight: sustainHeight / sustainSegments
    property real releaseSegmentHeight: releaseHeight / releaseSegments
    
    // Largeur de base
    property real baseWidth: (velocity / 127.0 * 0.8 + 0.2) * cubeSize
    
    // Position du Node
    position: Qt.vector3d(currentX, currentY, cubeZ)
    
    // ========== SEGMENTS DE SUSTAIN ==========
    Instantiator {
        model: sustainSegments
        
        delegate: Node {
            required property int index
            parent: noteModel
            
            // IMPORTANT : Le Node doit être à (0,0,0) en local
            position: Qt.vector3d(0, 0, 0)
            
            Model {
                // Position verticale du segment (en bas)
                property real segmentY: -noteModel.totalHeight + (parent.index * noteModel.sustainSegmentHeight) + noteModel.sustainSegmentHeight / 2
                
                source: "#Cube"
                position: Qt.vector3d(0, segmentY, 0)
                
                Component.onCompleted: {
                    console.log("SUSTAIN", parent.index, "- Position locale:", position, "- Scale:", scale,
                               "- Parent:", parent, "- Visible:", visible)
                }
                
                scale: Qt.vector3d(
                    noteModel.baseWidth,
                    noteModel.sustainSegmentHeight * noteModel.cubeSize / 20,
                    noteModel.cubeSize
                )
                
                materials: [
                    CustomMaterial {
                        vertexShader: "shaders/tremolo_vibrato.vert"
                        fragmentShader: "shaders/bend.frag"
                        
                        property color baseColor: noteModel.cubeColor
                        property real metalness: 0.7
                        property real roughness: 0.2
                        property real time: 0
                        
                        property real tremoloIntensity: 0.15
                        property real vibratoIntensity: 1.12
                        property real tremoloSpeed: 4.0
                        property real vibratoSpeed: 5.0
                        
                        shadingMode: CustomMaterial.Shaded
                        
                        NumberAnimation on time {
                            from: 0; to: 100000
                            duration: 100000
                            running: true
                            loops: Animation.Infinite
                        }
                    }
                ]
            }
        }
    }
    
    // ========== SEGMENTS DE RELEASE (queue effilée) ==========
    Instantiator {
        model: releaseSegments
        
        delegate: Node {
            required property int index
            parent: noteModel
            
            // IMPORTANT : Le Node doit être à (0,0,0) en local car il hérite de noteModel.position
            position: Qt.vector3d(0, 0, 0)
            
            Component.onCompleted: {
                console.log("Release Node", index, "position:", position, "scenePosition:", scenePosition)
            }
            
            // Progression dans la queue (0.0 = bas, 1.0 = pointe)
            property real releaseProgress: (index + 0.5) / noteModel.releaseSegments
            
            // Facteur de rétrécissement (1.0 = pleine largeur, 0.05 = pointe)
            property real taperFactor: 1.0 - (releaseProgress * 0.95)
            
            // Facteur d'assombrissement
            property real brightness: 1.0 - (releaseProgress * 0.4)  // 100% → 60%
            
            // Stocker la couleur localement pour éviter les problèmes de binding
            property color localColor: noteModel.cubeColor
            
            Model {
                id: releaseModel
                
                // Position verticale du segment (au-dessus du sustain)
                property real segmentY: -noteModel.totalHeight + noteModel.sustainHeight + (parent.index * noteModel.releaseSegmentHeight) + noteModel.releaseSegmentHeight / 2
                
                // Stocker les valeurs du parent Node dans le Model
                property real modelBrightness: parent.brightness
                property color modelColor: parent.localColor
                property real modelTaperFactor: parent.taperFactor
                
                source: "#Cube"
                position: Qt.vector3d(0, segmentY, 0)
                
                Component.onCompleted: {
                    console.log("RELEASE", parent.index, "- Position locale:", position, "- Scale:", scale, 
                               "- Visible:", visible, "- Opacity:", opacity,
                               "- Brightness:", parent.brightness, "- TaperFactor:", parent.taperFactor,
                               "- Material baseColor:", materials[0].baseColor)
                }
                
                scale: Qt.vector3d(
                    noteModel.baseWidth * releaseModel.modelTaperFactor,
                    noteModel.releaseSegmentHeight * noteModel.cubeSize / 20,
                    noteModel.cubeSize * releaseModel.modelTaperFactor
                )
                
                materials: [
                    CustomMaterial {
                        vertexShader: "shaders/tremolo_vibrato.vert"
                        fragmentShader: "shaders/release_segment.frag"
                        
                        property color baseColor: releaseModel.modelColor
                        property real brightness: releaseModel.modelBrightness
                        property real metalness: 0.7
                        property real roughness: 0.2
                        property real time: 0
                        
                        property real tremoloIntensity: 0.15 * releaseModel.modelTaperFactor
                        property real vibratoIntensity: 1.12 * releaseModel.modelTaperFactor
                        property real tremoloSpeed: 4.0
                        property real vibratoSpeed: 5.0
                        
                        shadingMode: CustomMaterial.Shaded
                        
                        NumberAnimation on time {
                            from: 0; to: 100000
                            duration: 100000
                            running: true
                            loops: Animation.Infinite
                        }
                    }
                ]
            }
        }
    }
    
    // Animation de chute
    NumberAnimation on currentY {
        id: fallAnimation
        from: currentY
        to: targetY - totalHeight
        duration: Math.max(100, (spawnHeight - (targetY - totalHeight * 2)) / fallSpeed * 1000)
        running: false
        
        onFinished: {
            noteModel.destroy()
        }
    }
    
    Component.onCompleted: {
        console.log("NoteModel cubeColor:", cubeColor)
        fallAnimation.start()
    }
}

