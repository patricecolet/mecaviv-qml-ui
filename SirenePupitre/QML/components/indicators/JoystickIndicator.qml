import QtQuick
import QtQuick3D

Node {
    id: root
    
    // Propriétés publiques - Valeurs normalisées (-1 à 1)
    property real xValue: 0      // Position X (-1 à 1)
    property real yValue: 0      // Position Y (-1 à 1)
    property real zValue: 0      // Position Z (-1 à 1) rotation
    property bool button: false  // État du bouton
    
    // Ajoutez ces handlers de changement :
    onXValueChanged: {
        console.log("[9] JoystickIndicator xValue changed:", Date.now(), "ms, value:", xValue);
    }
    
    onZValueChanged: {
        console.log("[10] JoystickIndicator zValue changed:", Date.now(), "ms, value:", zValue);
    }
    
    Component.onCompleted: {
        console.log("[INIT] JoystickIndicator créé");
    }
    // Paramètre de taille globale
    property real globalScale: 1.7  // Facteur d'échelle global de l'objet
    
    // Propriétés visuelles (tailles de base avant mise à l'échelle)
    property real baseRadius: 30
    property real innerRadius: 25
    property real stickLength: 35
    property real maxAngle: 25
    property color baseColor: Qt.rgba(0.15, 0.15, 0.2, 1)
    property color ringColor: Qt.rgba(0.3, 0.3, 0.4, 1)
    property color stickColor: Qt.rgba(0.7, 0.7, 0.8, 1)
    property color markingColor: Qt.rgba(0.5, 0.5, 0.6, 1)
    property color buttonIdleColor: Qt.rgba(0.4, 0.1, 0.1, 1)
    property color buttonActiveColor: Qt.rgba(1, 0.2, 0.2, 1)
    
    // Propriétés d'éclairage
    property bool lightEnabled: true
    property real lightBrightness: 40
    property color lightColor: Qt.rgba(0.9, 0.9, 1, 1)
    property bool showValues:true
    // Rotation pour vue légèrement inclinée vers le bas
    eulerRotation: Qt.vector3d(90, 10, 0)
    
    // Conteneur principal avec mise à l'échelle globale
    Node {
        id: mainContainer
        scale: Qt.vector3d(root.globalScale, root.globalScale, root.globalScale)
        
        // Lumière principale
        PointLight {
            visible: root.lightEnabled
            position: Qt.vector3d(0, 60, 60)
            brightness: root.lightBrightness
            color: root.lightColor
        }
        
        // Lumière d'ambiance
        DirectionalLight {
            eulerRotation: Qt.vector3d(-45, -45, 0)
            brightness: 0.3
            color: Qt.rgba(0.8, 0.8, 1, 1)
        }
        
        // Base principale du joystick
        Model {
            source: "#Cylinder"
            scale: Qt.vector3d(root.baseRadius / 50, 0.15, root.baseRadius / 50)
            position: Qt.vector3d(0, -22, 0)
            materials: PrincipledMaterial {
                baseColor: root.baseColor
                metalness: 0.7
                roughness: 0.3
            }
        }
        
        // Anneau externe décoratif
        Model {
            source: "#Cylinder"
            scale: Qt.vector3d(root.baseRadius / 50, 0.05, root.baseRadius / 50)
            position: Qt.vector3d(0, -19, 0)
            materials: PrincipledMaterial {
                baseColor: root.ringColor
                metalness: 0.9
                roughness: 0.1
            }
        }
        
        // Cercle de limitation (visuel uniquement)
        Model {
            source: "#Cylinder"
            scale: Qt.vector3d(root.innerRadius / 50, 0.02, root.innerRadius / 50)
            position: Qt.vector3d(0, -18.5, 0)
            materials: PrincipledMaterial {
                baseColor: Qt.rgba(0.1, 0.1, 0.15, 1)
                metalness: 0.5
                roughness: 0.5
            }
        }
        
        // Marquages directionnels
        Repeater3D {
            model: 4
            Node {
                eulerRotation: Qt.vector3d(0, index * 90, 0)
                
                // Ligne directionnelle
                Model {
                    source: "#Cube"
                    scale: Qt.vector3d(0.2, 0.01, 0.01)
                    position: Qt.vector3d(root.innerRadius * 0.7, -18.4, 0)
                    materials: PrincipledMaterial {
                        baseColor: root.markingColor
                        metalness: 0.3
                        roughness: 0.5
                        emissiveFactor: Qt.vector3d(0.1, 0.1, 0.1)
                    }
                }
                
                // Marqueur de direction (plus grand pour X/Y)
                Model {
                    visible: index === 0 || index === 1
                    source: "#Cube"
                    scale: Qt.vector3d(0.06, 0.01, 0.03)
                    position: Qt.vector3d(root.innerRadius * 0.9, -18.4, 0)
                    materials: PrincipledMaterial {
                        baseColor: index === 0 ? Qt.rgba(1, 0.5, 0.5, 1) : Qt.rgba(0.5, 1, 0.5, 1)
                        metalness: 0.5
                        roughness: 0.3
                        emissiveFactor: index === 0 ? Qt.vector3d(0.3, 0, 0) : Qt.vector3d(0, 0.3, 0)
                    }
                }
            }
        }
        
        // Centre de la base (socket)
        Model {
            source: "#Sphere"
            scale: Qt.vector3d(0.16, 0.08, 0.16)
            position: Qt.vector3d(0, -19, 0)
            materials: PrincipledMaterial {
                baseColor: Qt.rgba(0.2, 0.2, 0.25, 1)
                metalness: 0.8
                roughness: 0.2
            }
        }
        
        // Noeud pivot pour la tige (inclinaison X/Y seulement)
        Node {
            position: Qt.vector3d(0, -20, 0)
            eulerRotation: Qt.vector3d(
                -root.xValue * root.maxAngle,  // X reçu → mouvement Y inversé
                0,  // Pas de rotation Y ici
                root.yValue * root.maxAngle  // Y reçu → mouvement X inversé
            )
            
            // Noeud pour la rotation Z du stick
            Node {
                eulerRotation: Qt.vector3d(0, 90 - root.zValue * 180, 0)  // Rotation inversée + 90° de base
                
                // Manche du joystick
                Model {
                    source: "#Cylinder"
                    scale: Qt.vector3d(0.1, root.stickLength / 50, 0.1)
                    position: Qt.vector3d(0, root.stickLength/2, 0)
                    materials: PrincipledMaterial {
                        baseColor: root.stickColor
                        metalness: 0.9
                        roughness: 0.1
                    }
                }
                
                // Anneaux décoratifs sur le manche
                Repeater3D {
                    model: 3
                    Model {
                        source: "#Cylinder"
                        scale: Qt.vector3d(0.12, 0.02, 0.12)
                        position: Qt.vector3d(0, 10 + index * 8, 0)
                        materials: PrincipledMaterial {
                            baseColor: Qt.rgba(0.4, 0.4, 0.5, 1)
                            metalness: 0.8
                            roughness: 0.2
                        }
                    }
                }
                
                // Poignée principale
                Model {
                    source: "#Sphere"
                    scale: Qt.vector3d(0.18, 0.15, 0.18)
                    position: Qt.vector3d(0, root.stickLength - 2, 0)
                    materials: PrincipledMaterial {
                        baseColor: Qt.rgba(0.25, 0.25, 0.3, 1)
                        metalness: 0.6
                        roughness: 0.3
                    }
                }
                
                // Indicateur de rotation Z
                Node {
                    position: Qt.vector3d(0, root.stickLength, 0)
                    
                    // Corps de la flèche
                    Model {
                        source: "#Cylinder"
                        scale: Qt.vector3d(0.02, 0.08, 0.02)
                        position: Qt.vector3d(10, 0, 0)
                        eulerRotation: Qt.vector3d(0, 0, -90)
                        materials: PrincipledMaterial {
                            baseColor: Qt.rgba(1, 0.8, 0, 1)
                            metalness: 0.5
                            roughness: 0.3
                            emissiveFactor: Qt.vector3d(0.5, 0.4, 0)
                        }
                    }
                    
                    // Pointe de la flèche
                    Model {
                        source: "#Cone"
                        scale: Qt.vector3d(0.04, 0.06, 0.04)
                        position: Qt.vector3d(14, 0, 0)
                        eulerRotation: Qt.vector3d(0, 0, -90)
                        materials: PrincipledMaterial {
                            baseColor: Qt.rgba(1, 0.8, 0, 1)
                            metalness: 0.5
                            roughness: 0.3
                            emissiveFactor: Qt.vector3d(0.5, 0.4, 0)
                        }
                    }
                    
                    // Base de la flèche
                    Model {
                        source: "#Cylinder"
                        scale: Qt.vector3d(0.05, 0.01, 0.05)
                        position: Qt.vector3d(0, 0, 0)
                        materials: PrincipledMaterial {
                            baseColor: Qt.rgba(0.8, 0.6, 0, 1)
                            metalness: 0.7
                            roughness: 0.2
                        }
                    }
                }

// Un disque émissif sous le bouton pour simuler la lumière
              
                // Bouton principal
                Model {
                    source: "#Cylinder"
                    scale: Qt.vector3d(0.12, 0.04, 0.12)
                    position: Qt.vector3d(0, root.stickLength + 7, 0)
                    materials: PrincipledMaterial {
                        baseColor: root.button ? root.buttonActiveColor : root.buttonIdleColor
                        //baseColor: "red"
                        metalness: 0.4
                        roughness: 0.3
                        emissiveFactor: root.button ? Qt.vector3d(2, 0, 0) : Qt.vector3d(0, 0, 0)
                    }
                }
                
                // Capuchon du bouton
                Model {
                    source: "#Sphere"
                    scale: Qt.vector3d(0.1, 0.05, 0.1)
                    position: Qt.vector3d(0, root.stickLength + 8.5, 0)
                    materials: PrincipledMaterial {
                        baseColor: root.button ? Qt.rgba(1, 0.3, 0.3, 1) : Qt.rgba(0.5, 0.15, 0.15, 1)
                        //baseColor: "red"
                        metalness: 0.6
                        roughness: 0.2
                        emissiveFactor: root.button ? Qt.vector3d(0.5, 0, 0) : Qt.vector3d(0, 0, 0)
                    }
                }
                
                //Indicateur LED du bouton (halo)
                Model {
                    visible: root.button
                    source: "#Cylinder"
                    scale: Qt.vector3d(0.16, 0.01, 0.16)
                    position: Qt.vector3d(0, root.stickLength + 5.5, 0)
                    materials: PrincipledMaterial {
                        baseColor: Qt.rgba(1, 0, 0, 0.6)
                        metalness: 0.1
                        roughness: 0.8
                        emissiveFactor: Qt.vector3d(1, 0, 0)
                    }
                }
            }
        }
    }
}
