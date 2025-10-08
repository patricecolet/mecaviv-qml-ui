import QtQuick
import "../../utils" as Utils
import "../../config.js" as Config

pragma ComponentBehavior: Bound

Item {
    id: root
    z: 0
    property var knobValues: []
    property int sirenId: 0
    property bool showLabels: true
    property var webSocketController
    
    signal knobValueChanged(int sirenId, int controllerIndex, real value)
    
    width: 250
    height: 600  // ← Réduire la hauteur
    
    layer.enabled: true
    layer.smooth: true
    
    Column {
        spacing: 15  // ← Réduire l'espacement entre sections
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 10  // ← Réduire la marge du haut
        
        // Section Volume
        ControlSection {
            id: volumeSection
            label: root.showLabels ? "VOLUME" : ""
            labelColor: "#ffff66"
            indicatorColor: "#ffff66"
            knobCount: 1
            values: root.knobValues
            startIndex: 0
            knobLabels: ["volume"]
            showKnobLabels: root.showLabels
            
            onValueChanged: function(index, value) {
                root.knobValueChanged(root.sirenId, index, value)
            }
        }
        
        // Section Vibrato
        ControlSection {
            id: vibratoSection
            label: root.showLabels ? "VIBRATO" : ""
            labelColor: "#6699ff"
            indicatorColor: "#6699ff"
            knobCount: 2
            values: root.knobValues
            startIndex: 1
            knobLabels: ["vibratoSpeed", "vibratoDepth"]
            showKnobLabels: root.showLabels
            
            onValueChanged: function(index, value) {
                root.knobValueChanged(root.sirenId, index, value)
            }
        }
        
        // Section Tremolo
        ControlSection {
            id: tremoloSection
            label: root.showLabels ? "TREMOLO" : ""
            labelColor: "#ff9966"
            indicatorColor: "#ff9966"
            knobCount: 2
            values: root.knobValues
            startIndex: 3
            knobLabels: ["tremoloSpeed", "tremoloDepth"]
            showKnobLabels: root.showLabels
            
            onValueChanged: function(index, value) {
                root.knobValueChanged(root.sirenId, index, value)
            }
        }
        
        // Section Enveloppe
        ControlSection {
            id: enveloppeSection
            label: root.showLabels ? "ENVELOPPE" : ""
            labelColor: "#66ff99"
            indicatorColor: "#66ff99"
            knobCount: 2
            values: root.knobValues
            startIndex: 5
            knobLabels: ["attack", "release"]
            showKnobLabels: root.showLabels
            
            onValueChanged: function(index, value) {
                root.knobValueChanged(root.sirenId, index, value)
            }
        }
        
        // Section Transpose
        ControlSection {
            id: transposeSection
            label: root.showLabels ? "TRANSPOSE" : ""
            labelColor: "#ff66ff"
            indicatorColor: "#ff66ff"
            knobCount: 1
            values: root.knobValues
            startIndex: 7
            knobLabels: ["voice"]
            showKnobLabels: root.showLabels
            
            onValueChanged: function(index, value) {
                root.knobValueChanged(root.sirenId, index, value)
            }
        }
    }
    
    // Méthode pour mettre à jour tous les knobs explicitement
    function setKnobValues(values) {
        if (!values || values.length < Config.controllers.order.length) return;
        
        // Mettre à jour chaque section
        volumeSection.setValues(values.slice(0, 1));
        vibratoSection.setValues(values.slice(1, 3));
        tremoloSection.setValues(values.slice(3, 5));
        enveloppeSection.setValues(values.slice(5, 7));
        transposeSection.setValues(values.slice(7, 8));
    }
    
    // Initialiser les knobs quand le panel devient visible
    onVisibleChanged: {
        if (visible) {
            // Délai pour s'assurer que les knobs sont créés
            Qt.callLater(function() {
                if (parent && parent.updateKnobValues) {
                    parent.updateKnobValues();
                }
            });
        }
    }
    
    Component.onCompleted: {
        if (logger) logger.debug("INIT", "PedalConfigPanel S" + sirenId + " dimensions:", width, "x", height)
        // Demander le preset en cours au serveur
        if (root.webSocketController) {
            if (logger) logger.debug("PRESET", "Demande du preset en cours pour S" + sirenId);
            root.webSocketController.requestCurrentPreset();
        }
    }
}
