import QtQuick 2.15
import QtQuick3D
import "../../utils"
Node {
    id: root
    
    // Propriétés requises
    required property int ambitusMin
    required property int ambitusMax
    required property real staffWidth
    required property real staffPosX
    required property real lineSpacing
    required property real lineThickness
    required property string clef
    
    // Propriétés optionnelles
    property color noteColor: Qt.rgba(0.9, 0.6, 0.6, 0.9)
    property real noteScale: 0.15
    property bool showOnlyNaturals: true
    property bool showLedgerLines: true
    property bool showDebugLabels: false  // Corrigé pour éviter l'erreur de propriété manquante
    required property int octaveOffset
    
    property color ledgerLineColor: Qt.rgba(0.8, 0.8, 0.8, 1.0)  // Couleur par défaut au lieu de parent.lineColor
    property bool forceRefresh: false
    
    onNoteScaleChanged: {
        forceRefresh = !forceRefresh;
    }
    
    // Instances
    NotePositionCalculator {
        id: noteCalc
    }
    
    MusicUtils {
        id: musicUtils
    }
    
    // Afficher toutes les notes de l'ambitus
    Repeater3D {
        model: root.ambitusMax - root.ambitusMin + 1
        
        Node {
            property int noteMidi: root.ambitusMin + index
            property real noteY: {
                var offsetNote = noteMidi + (root.octaveOffset * 12)
                return noteCalc.calculateNoteYPosition(offsetNote, root.lineSpacing, root.clef)
            }
            property real noteX: noteCalc.calculateNoteXPosition(noteMidi, root.ambitusMin, root.ambitusMax, root.staffPosX, root.staffWidth)
            property bool isNatural: noteCalc.isNaturalNote(noteMidi)
            property string noteName: musicUtils.noteNames[noteMidi % 12]
            
            visible: !root.showOnlyNaturals || isNatural
            
            // La note
            Model {
                source: "#Sphere"
                scale: Qt.vector3d(root.noteScale, root.noteScale * 0.75, root.noteScale)
                position: Qt.vector3d(noteX, noteY, -0.5)
                materials: PrincipledMaterial {
                    baseColor: root.noteColor
                    metalness: 0.0
                    roughness: 0.8
                }
            }
            
            // Label de débogage
            LEDText3D {
                visible: root.showDebugLabels  // ← CHANGÉ : utilise le binding
                text: parent.noteName
                position: Qt.vector3d(parent.noteX, parent.noteY + 25, -0.1)
                letterSpacing: 20
                letterHeight: 15
                segmentWidth: 3
                segmentDepth: 0.5
                textColor: Qt.rgba(1, 1, 0.5, 1)
            }
                        // Lignes supplémentaires
            LedgerLines3D {
                visible: root.showLedgerLines && (noteY < -2 * root.lineSpacing || noteY > 2 * root.lineSpacing)
                noteY: parent.noteY
                noteX: parent.noteX
                lineSpacing: root.lineSpacing
                lineThickness: root.lineThickness
                lineColor: root.ledgerLineColor  // Utilise la propriété avec binding
            }
            
        }
    }
    
}
