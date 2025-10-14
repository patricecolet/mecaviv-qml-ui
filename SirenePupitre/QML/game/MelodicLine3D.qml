import QtQuick
import QtQuick3D

Node {
    id: root
    
    // Propriétés
    property var lineSegments: []
    property real lineSpacing: 20
    property real ambitusMin: 48.0
    property real ambitusMax: 84.0
    property real fallSpeed: 150  // Vitesse de chute
    property real spawnHeight: 500  // Hauteur de départ
    
    // Propriétés calculées
    readonly property real ambitusRange: ambitusMax - ambitusMin
    readonly property real staffHeight: ambitusRange * lineSpacing
    
    // Component pour créer les cubes (créé une seule fois)
    Component {
        id: cubeComponent
        FallingCube {
        }
    }
    
    // Fonction pour convertir une note MIDI en position Y sur la portée
    function noteToY(note) {
        var normalized = (note - ambitusMin) / ambitusRange
        return staffHeight * (1 - normalized) - staffHeight / 2
    }
    
    // Fonction pour calculer la position X de la note sur la portée
    function noteToX(note) {
        var normalized = (note - ambitusMin) / ambitusRange
        return (normalized - 0.5) * 1600
    }
    
    // Fonction pour obtenir une couleur selon la hauteur de la note
    function noteToColor(note) {
        var normalized = (note - ambitusMin) / ambitusRange
        var hue = 240 - (normalized * 180)  // 240 (bleu) -> 60 (rouge)
        return Qt.hsla(hue / 360, 0.8, 0.6, 1.0)
    }
    
    // Fonction pour créer un cube
    function createCube(segment) {
        var vel = segment.velocity
        
        // Filtrer les noteOff (vélocité = 0 ou undefined)
        if (vel === 0 || vel === undefined) {
            return  // Ne pas créer de cube pour noteOff
        }
        
        cubeComponent.createObject(root, {
            "targetY": noteToY(segment.note),
            "targetX": noteToX(segment.note),
            "spawnHeight": root.spawnHeight,
            "fallSpeed": root.fallSpeed,
            "cubeColor": noteToColor(segment.note),
            "velocity": vel
        })
    }
    
    // Surveiller les changements de lineSegments
    onLineSegmentsChanged: {
        // Créer un cube seulement pour le dernier segment (nouveau)
        if (lineSegments.length > 0) {
            var lastSegment = lineSegments[lineSegments.length - 1]
            createCube(lastSegment)
        }
    }
}
