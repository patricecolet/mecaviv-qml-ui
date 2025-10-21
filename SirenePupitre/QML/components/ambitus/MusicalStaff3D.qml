import QtQuick
import QtQuick3D
import "../../../../shared/qml/common"

Node {
    id: root
    property var configController: null
    
    property int localUpdateCounter: configController ? configController.updateCounter : 0
    
    // Propriété pour recevoir sirenInfo
    property var sirenInfo: null
    // Propriétés de base (avec valeurs par défaut ou depuis sirenInfo)
    property real lineSpacing: 20
    property real lineThickness: 1
    property real staffWidth: 1800
    property real staffPosX: 0
    property string clef: sirenInfo ? sirenInfo.clef : "treble"
    property color lineColor: {
        if (configController && configController.updateCounter >= 0) {
            var hexColor = configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "lines", "color"])
            if (hexColor) {
                var color = Qt.color(hexColor)
                return Qt.rgba(color.r, color.g, color.b, color.a)
            }
        }
        return Qt.rgba(0.8, 0.8, 0.8, 1)
    }
    
    // Propriétés musicales avec gestion du mode restricted
    required property real currentNoteMidi
    
    property real ambitusMin: sirenInfo ? sirenInfo.ambitus.min : 48.0
    property real ambitusMax: {
        if (!sirenInfo) return 84.0
        // Si on est en mode restricted, utiliser restrictedMax
        if (sirenInfo.mode === "restricted" && sirenInfo.restrictedMax !== undefined) {
            return sirenInfo.restrictedMax
        }
        // Sinon utiliser la valeur max normale
        return sirenInfo.ambitus.max
    }
    property int octaveOffset: sirenInfo && sirenInfo.displayOctaveOffset !== undefined ? sirenInfo.displayOctaveOffset : 0
    
    // Options d'affichage par défaut (peuvent être surchargées par config)
    property bool showCursor: true
    property bool showProgressBar: true
    property bool showAmbitus: true
    property bool showNoteNames: false
    
    // Accès à la config depuis configController
    property var staffConfig: {
        if (!configController) return {}
        var dummy = configController.updateCounter  // Force la mise à jour
        return configController.getConfigValue("displayConfig.components.musicalStaff", {})
    }
    property var ambitusConfig: staffConfig.ambitus || {}
    property var cursorConfig: staffConfig.cursor || {}
    property var progressConfig: staffConfig.progressBar || {}
    property var clefConfig: staffConfig.clef || {}
    property var keySignatureConfig: staffConfig.keySignature || {}
    
    // Calcul dynamique des offsets
    property bool showClef: clefConfig.visible !== false // true par défaut
    property bool showKeySignature: keySignatureConfig.visible === true // false par défaut
    property real clefWidth: showClef ? (clefConfig.width || 100) : 0
    property real keySignatureWidth: showKeySignature ? (keySignatureConfig.width || 80) : 0
    property real ambitusOffset: clefWidth + keySignatureWidth
    // Après les autres propriétés, ajoutez :
    property bool noteNameVisible: {
        if (!configController) return ambitusConfig.showNoteNames === true || showNoteNames
        var dummy = configController.updateCounter
        var noteNameVis = configController.getConfigValue("displayConfig.components.musicalStaff.noteName.visible", undefined)
        if (noteNameVis !== undefined) return noteNameVis
        return ambitusConfig.showNoteNames === true || showNoteNames
    }
    
    // Les 5 lignes de la portée
    Repeater3D {
        model: 5
        Model {
            source: "#Cube"
            scale: Qt.vector3d(root.staffWidth / 100, root.lineThickness / 100, 0.01)
            position: Qt.vector3d(root.staffPosX, (index - 2) * root.lineSpacing, 0)
            materials: PrincipledMaterial {
                baseColor: root.lineColor
                metalness: 0.0
                roughness: 0.9
            }
        }
    }
    
    // La clé (3D) est temporairement désactivée au profit d'un overlay 2D
     Clef3D {
         visible: root.showClef
         clefType: root.clef
         staffWidth: root.staffWidth
         lineSpacing: root.lineSpacing
         clefColor: root.lineColor
         // Position personnalisée
         clefOffsetX: 0
         clefOffsetY: 0
     }
    
    // Affichage de l'ambitus (les notes)
    AmbitusDisplay3D {
        visible: {
            if (!configController) return root.showAmbitus
            var dummy = configController.updateCounter
            return root.showAmbitus && configController.getConfigValue("displayConfig.components.musicalStaff.ambitus.visible", true)
        }
        ambitusMin: Math.floor(root.ambitusMin)
        ambitusMax: Math.ceil(root.ambitusMax)
        staffWidth: root.staffWidth - root.ambitusOffset
        staffPosX: root.staffPosX + root.ambitusOffset/2
        lineSpacing: root.lineSpacing
        lineThickness: root.lineThickness
        clef: root.clef
        octaveOffset: root.octaveOffset
        
        showOnlyNaturals: ambitusConfig.noteFilter === "natural" || ambitusConfig.noteFilter === undefined
        
        noteScale: {
            if (configController) {
                var dummy = configController.updateCounter;
                return configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "ambitus", "noteSize"], 0.15);
            }
            return 0.15;
        }
        
            noteColor: {
                // Forcer la mise à jour avec updateCounter
                if (configController) {
                    var dummy = configController.updateCounter
                }
                if (ambitusConfig.noteColor) {
                    var color = Qt.color(ambitusConfig.noteColor)
                    return Qt.rgba(color.r, color.g, color.b, color.a)
                }
                return Qt.rgba(0.9, 0.6, 0.6, 0.9)
            }
        
        showDebugLabels: {
            if (configController) {
                var dummy = configController.updateCounter
                // Vérifier d'abord noteName.visible
                var noteNameVisible = configController.getConfigValue("displayConfig.components.musicalStaff.noteName.visible", undefined)
                if (noteNameVisible !== undefined) return noteNameVisible
            }
            // Sinon utiliser la logique existante
            return ambitusConfig.showNoteNames === true || root.showNoteNames
        }
    }
    
    // Le curseur
    NoteCursor3D {
        visible: {
            if (!configController) return root.showCursor
            var dummy = configController.updateCounter
            return root.showCursor && configController.getConfigValue("displayConfig.components.musicalStaff.cursor.visible", true)
        }
        currentNoteMidi: root.currentNoteMidi
        staffWidth: root.staffWidth - root.ambitusOffset
        staffPosX: root.staffPosX + root.ambitusOffset/2
        lineSpacing: root.lineSpacing
        lineThickness: root.lineThickness
        clef: root.clef
        ambitusMin: root.ambitusMin
        ambitusMax: root.ambitusMax
        octaveOffset: root.octaveOffset
        
        // REMPLACER les propriétés de configuration par des bindings dynamiques
        cursorColor: {
            if (configController) {
                var dummy = configController.updateCounter;
                var colorValue = configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "color"], "#FF3333");
                
                // Si c'est une string hexadécimale
                if (typeof colorValue === "string") {
                    var color = Qt.color(colorValue);
                    return Qt.rgba(color.r, color.g, color.b, color.a);
                }
                // Si c'est un array [r,g,b,a] (ancien format)
                else if (Array.isArray(colorValue)) {
                    return Qt.rgba(colorValue[0], colorValue[1], colorValue[2], colorValue[3]);
                }
                // Fallback
                return Qt.rgba(1, 0.2, 0.2, 0.8);
            }
            return Qt.rgba(1, 0.2, 0.2, 0.8);
        }
        
        cursorWidth: {
            if (configController) {
                var dummy = configController.updateCounter;
                return configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "width"], 3);
            }
            return 3;
        }
        
        cursorOffsetY: {
            if (configController) {
                var dummy = configController.updateCounter;
                return configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "offsetY"], 30);
            }
            return 30;
        }
        
        showNoteHighlight: {
            if (configController) {
                var dummy = configController.updateCounter;
                return configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "showNoteHighlight"], true);
            }
            return true;
        }
        
        // AJOUTER les bindings pour le highlight
        highlightColor: {
            if (configController) {
                var dummy = configController.updateCounter;
                var colorValue = configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "highlightColor"], "#FFFF00");
                
                
                // Si c'est une string hexadécimale
                if (typeof colorValue === "string") {
                    var color = Qt.color(colorValue);
                    return Qt.rgba(color.r, color.g, color.b, color.a);
                }
                // Si c'est un array [r,g,b,a]
                else if (Array.isArray(colorValue)) {
                    return Qt.rgba(colorValue[0], colorValue[1], colorValue[2], colorValue[3]);
                }
                return Qt.rgba(1, 1, 0, 0.6);
            }
            return Qt.rgba(1, 1, 0, 0.6);
        }
        
        highlightSize: {
            if (configController) {
                var dummy = configController.updateCounter;
                return configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "highlightSize"], 0.25);
            }
            return 0.25;
        }
    }
    
    // La barre de progression
    NoteProgressBar3D {
        visible: {
            if (!configController) return root.showProgressBar
            var dummy = configController.updateCounter
            return root.showProgressBar && configController.getConfigValue("displayConfig.components.musicalStaff.progressBar.visible", true)
        }
        currentNoteMidi: root.currentNoteMidi
        ambitusMin: root.ambitusMin
        ambitusMax: root.ambitusMax
        staffWidth: root.staffWidth - root.ambitusOffset
        staffPosX: root.staffPosX + root.ambitusOffset/2
        
        // Propriétés pour le positionnement
        lineSpacing: root.lineSpacing
        clef: root.clef
        octaveOffset: root.octaveOffset // Passer l'offset
        
        // Configuration depuis config.js ou valeurs par défaut
        barHeight: progressConfig.barHeight || 5
        barOffsetY: progressConfig.barOffsetY || 30
        backgroundColor: {
            if (progressConfig.colors && progressConfig.colors.background) {
                var color = Qt.color(progressConfig.colors.background)
                return Qt.rgba(color.r, color.g, color.b, color.a)
            }
            return Qt.rgba(0.2, 0.2, 0.2, 0.5)
        }
        progressColor: {
            if (progressConfig.colors && progressConfig.colors.progress) {
                var color = Qt.color(progressConfig.colors.progress)
                return Qt.rgba(color.r, color.g, color.b, color.a)
            }
            return Qt.rgba(0.2, 0.8, 0.2, 0.8)
        }
        cursorColor: {
            if (progressConfig.colors && progressConfig.colors.cursor) {
                var color = Qt.color(progressConfig.colors.cursor)
                return Qt.rgba(color.r, color.g, color.b, color.a)
            }
            return Qt.rgba(1, 1, 1, 0.9)
        }
        cursorSize: progressConfig.cursorSize || 10
        showPercentage: progressConfig.showPercentage !== false
    }
    
    // Indicateur GearShift déplacé dans SirenDisplay (overlay 2D)
}
