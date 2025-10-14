import QtQuick
import QtQuick3D

/**
 * Ligne mélodique défilante (encodage visuel des contrôleurs)
 * Représente un segment de la séquence musicale qui défile vers le curseur
 */
Node {
    id: root
    
    property var event: null  // {timestamp, note, velocity, controllers}
    property real gameTime: 0
    
    // Position calculée selon le temps
    property real timeUntilPlay: event ? (event.timestamp - gameTime) : 0
    
    // Position Z (profondeur 3D)
    z: -timeUntilPlay * 0.5  // Plus c'est loin, plus c'est profond
    
    // Opacité (fade avec la distance)
    opacity: Math.max(0.3, Math.min(1.0, 1 - (Math.abs(z) / 2000)))
    
    // Hauteur sur la portée (note MIDI → position Y)
    y: event ? noteToY(event.note) : 0
    
    // Convertir note MIDI en position Y
    function noteToY(note) {
        // Centré sur A4 (69)
        var centerNote = 69
        var semitoneHeight = 0.5  // Espacement entre demi-tons
        return (note - centerNote) * semitoneHeight
    }
    
    // Encodage visuel des contrôleurs
    property real lineWidth: event && event.controllers ? calculateLineWidth() : 2
    property color lineColor: event && event.controllers ? calculateLineColor() : "#00CED1"
    property bool isWavy: event && event.controllers?.vibrato || false
    property bool isSegmented: event && event.controllers?.tremolo || false
    
    // Calculer l'épaisseur (volume = fader)
    function calculateLineWidth() {
        if (!event || !event.controllers || !event.controllers.fader) return 2
        
        var faderValue = event.controllers.fader.value || 64
        return Math.max(1, (faderValue / 127) * 10)  // 1-10 pixels
    }
    
    // Calculer la couleur (selon proximité du curseur)
    function calculateLineColor() {
        if (Math.abs(timeUntilPlay) < 100) {
            // Très proche du curseur
            return "#FFD700"  // Or
        } else if (Math.abs(timeUntilPlay) < 500) {
            // Proche
            return "#00FF00"  // Vert
        } else {
            // Loin
            return "#00CED1"  // Cyan
        }
    }
    
    // Modèle 3D de la ligne
    Model {
        id: lineModel
        
        source: isWavy ? wavyLineGeometry : straightLineGeometry
        
        scale: Qt.vector3d(50, lineWidth * 0.1, 1)  // Longueur de 50 unités
        
        materials: PrincipledMaterial {
            baseColor: lineColor
            emissiveFactor: Qt.vector3d(lineColor.r, lineColor.g, lineColor.b)
            lighting: PrincipledMaterial.NoLighting
            opacity: root.opacity
        }
        
        // Animation de pulsation pour les notes importantes
        SequentialAnimation on scale {
            running: event && event.velocity > 100
            loops: Animation.Infinite
            
            NumberAnimation {
                from: Qt.vector3d(50, lineWidth * 0.1, 1)
                to: Qt.vector3d(50, lineWidth * 0.12, 1)
                duration: 300
            }
            NumberAnimation {
                from: Qt.vector3d(50, lineWidth * 0.12, 1)
                to: Qt.vector3d(50, lineWidth * 0.1, 1)
                duration: 300
            }
        }
    }
    
    // Géométrie ligne droite (simple cube allongé)
    property var straightLineGeometry: "#Cube"
    
    // Géométrie ligne ondulée (pour vibrato)
    // TODO: Implémenter avec CustomGeometry si besoin
    property var wavyLineGeometry: "#Cube"
    
    // Segments pour tremolo (points ou tirets)
    Repeater {
        model: isSegmented ? 10 : 0
        
        Model {
            source: "#Sphere"
            x: (index - 5) * 5  // Espacement de 5 unités
            scale: Qt.vector3d(lineWidth * 0.05, lineWidth * 0.05, lineWidth * 0.05)
            
            materials: PrincipledMaterial {
                baseColor: lineColor
                emissiveFactor: Qt.vector3d(lineColor.r, lineColor.g, lineColor.b)
                lighting: PrincipledMaterial.NoLighting
                opacity: root.opacity
            }
        }
    }
}

