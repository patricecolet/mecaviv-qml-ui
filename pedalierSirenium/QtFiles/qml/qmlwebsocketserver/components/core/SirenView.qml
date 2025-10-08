import QtQuick
import QtQuick3D
import "../monitoring/midi-display"

Node {
    id: sirenViewRoot
    
    // Propriétés
    property var sirenNodes: []
    property color inactiveColor: "#333333"
    property var sirenController
    property bool configMode: false  // Mode configuration global
    property bool scenesMode: false  // Mode gestionnaire de scènes
    property int selectedPedalId: 1
    onSelectedPedalIdChanged: {
        // Propager à toutes les sirènes
        for (let i = 0; i < sirenNodes.length; i++) {
            sirenNodes[i].selectedPedalId = selectedPedalId;
        }
    }
    property var pedalConfigController: null
    property var webSocketController: null
    // Provider de spécifications des sirènes
    property var sirenSpecProvider: null
    
    // Signal pour les changements de valeur des knobs
    signal knobValueChanged(int pedalId, int sirenId, int controllerIndex, real value)
    
    // Fonction pour basculer le mode d'affichage
    function toggleConfigMode(pedalId) {
        configMode = !configMode;
        selectedPedalId = pedalId;
        
        // Fermer le mode scènes si ouvert
        if (configMode && scenesMode) {
            scenesMode = false;
        }
        
        // Mettre à jour toutes les sirènes
        for (let i = 0; i < sirenNodes.length; i++) {
            sirenNodes[i].showKnobs = configMode;
            sirenNodes[i].selectedPedalId = pedalId;
        }
    }
    
    // Fonction pour basculer le mode scènes
    function toggleScenesMode() {
        scenesMode = !scenesMode;
        
        // Fermer le mode config si ouvert
        if (scenesMode && configMode) {
            configMode = false;
            // Masquer les knobs sur toutes les sirènes
            for (let i = 0; i < sirenNodes.length; i++) {
                sirenNodes[i].showKnobs = false;
                // En mode scènes, masquer aussi le monitoring par sirène
                sirenNodes[i].showMonitoring = false;
            }
        }
        // Si on quitte le mode scènes, réactiver le monitoring
        if (!scenesMode) {
            for (let i = 0; i < sirenNodes.length; i++) {
                sirenNodes[i].showMonitoring = true;
            }
        }
    }
    
    // Créer les sirènes
    SirenColumn {
        id: siren1
        sirenController: sirenViewRoot.sirenController
        pedalConfigController: sirenViewRoot.pedalConfigController
        sphereId: 1
        sphereText: "S1"
        position: Qt.vector3d(-525, 500, 100)
        inactiveColor: sirenViewRoot.inactiveColor
        sirenSpec: sirenViewRoot.sirenSpecProvider && sirenViewRoot.sirenSpecProvider.spec ? sirenViewRoot.sirenSpecProvider.spec.siren1 : ({})
        
        onKnobValueChanged: function(sirenId, controllerIndex, value) {
            sirenViewRoot.knobValueChanged(sirenViewRoot.selectedPedalId, sirenId, controllerIndex, value)
        }
        
        Component.onCompleted: {
            sirenViewRoot.sirenNodes.push(this);
        }
        // Câblage MIDI live
        Connections {
            target: sirenViewRoot.webSocketController ? sirenViewRoot.webSocketController.midiMonitorController : null
            function onMidiDataChanged(note, velocity, bend, channel) {
                siren1.applyMidi(note, velocity, bend, channel)
            }
        }
    }
    
    SirenColumn {
        id: siren2
        sirenController: sirenViewRoot.sirenController
        pedalConfigController: sirenViewRoot.pedalConfigController
        sphereId: 2
        sphereText: "S2"
        position: Qt.vector3d(-350, 500, 100)
        inactiveColor: sirenViewRoot.inactiveColor
        sirenSpec: sirenViewRoot.sirenSpecProvider && sirenViewRoot.sirenSpecProvider.spec ? sirenViewRoot.sirenSpecProvider.spec.siren2 : ({})
        
        onKnobValueChanged: function(sirenId, controllerIndex, value) {
            sirenViewRoot.knobValueChanged(sirenViewRoot.selectedPedalId, sirenId, controllerIndex, value)
        }
        
        Component.onCompleted: {
            sirenViewRoot.sirenNodes.push(this);
        }
        Connections {
            target: sirenViewRoot.webSocketController ? sirenViewRoot.webSocketController.midiMonitorController : null
            function onMidiDataChanged(note, velocity, bend, channel) {
                siren2.applyMidi(note, velocity, bend, channel)
            }
        }
    }
    
    SirenColumn {
        id: siren3
        sirenController: sirenViewRoot.sirenController
        pedalConfigController: sirenViewRoot.pedalConfigController
        sphereId: 3
        sphereText: "S3"
        position: Qt.vector3d(-175, 500, 100)
        inactiveColor: sirenViewRoot.inactiveColor
        sirenSpec: sirenViewRoot.sirenSpecProvider && sirenViewRoot.sirenSpecProvider.spec ? sirenViewRoot.sirenSpecProvider.spec.siren3 : ({})
        
        onKnobValueChanged: function(sirenId, controllerIndex, value) {
            sirenViewRoot.knobValueChanged(sirenViewRoot.selectedPedalId, sirenId, controllerIndex, value)
        }
        
        Component.onCompleted: {
            sirenViewRoot.sirenNodes.push(this);
        }
        Connections {
            target: sirenViewRoot.webSocketController ? sirenViewRoot.webSocketController.midiMonitorController : null
            function onMidiDataChanged(note, velocity, bend, channel) {
                siren3.applyMidi(note, velocity, bend, channel)
            }
        }
    }
    
    SirenColumn {
        id: siren4
        sirenController: sirenViewRoot.sirenController
        pedalConfigController: sirenViewRoot.pedalConfigController
        sphereId: 4
        sphereText: "S4"
        position: Qt.vector3d(0, 500, 100)
        inactiveColor: sirenViewRoot.inactiveColor
        sirenSpec: sirenViewRoot.sirenSpecProvider && sirenViewRoot.sirenSpecProvider.spec ? sirenViewRoot.sirenSpecProvider.spec.siren4 : ({})
        
        onKnobValueChanged: function(sirenId, controllerIndex, value) {
            sirenViewRoot.knobValueChanged(sirenViewRoot.selectedPedalId, sirenId, controllerIndex, value)
        }
        
        Component.onCompleted: {
            sirenViewRoot.sirenNodes.push(this);
        }

        // Monitoring par sirène désormais géré dans SirenColumn (voir SirenColumn.qml)
        Connections {
            target: sirenViewRoot.webSocketController ? sirenViewRoot.webSocketController.midiMonitorController : null
            function onMidiDataChanged(note, velocity, bend, channel) {
                siren4.applyMidi(note, velocity, bend, channel)
            }
        }
    }
    
    SirenColumn {
        id: siren5
        sirenController: sirenViewRoot.sirenController
        pedalConfigController: sirenViewRoot.pedalConfigController
        sphereId: 5
        sphereText: "S5"
        position: Qt.vector3d(175, 500, 100)
        inactiveColor: sirenViewRoot.inactiveColor
        sirenSpec: sirenViewRoot.sirenSpecProvider && sirenViewRoot.sirenSpecProvider.spec ? sirenViewRoot.sirenSpecProvider.spec.siren5 : ({})
        
        onKnobValueChanged: function(sirenId, controllerIndex, value) {
            sirenViewRoot.knobValueChanged(sirenViewRoot.selectedPedalId, sirenId, controllerIndex, value)
        }
        
        Component.onCompleted: {
            sirenViewRoot.sirenNodes.push(this);
        }
        Connections {
            target: sirenViewRoot.webSocketController ? sirenViewRoot.webSocketController.midiMonitorController : null
            function onMidiDataChanged(note, velocity, bend, channel) {
                siren5.applyMidi(note, velocity, bend, channel)
            }
        }
    }
    
    SirenColumn {
        id: siren6
        sirenController: sirenViewRoot.sirenController
        pedalConfigController: sirenViewRoot.pedalConfigController
        sphereId: 6
        sphereText: "S6"
        position: Qt.vector3d(350, 500, 100)
        inactiveColor: sirenViewRoot.inactiveColor
        sirenSpec: sirenViewRoot.sirenSpecProvider && sirenViewRoot.sirenSpecProvider.spec ? sirenViewRoot.sirenSpecProvider.spec.siren6 : ({})
        
        onKnobValueChanged: function(sirenId, controllerIndex, value) {
            sirenViewRoot.knobValueChanged(sirenViewRoot.selectedPedalId, sirenId, controllerIndex, value)
        }
        
        Component.onCompleted: {
            sirenViewRoot.sirenNodes.push(this)
        }
        Connections {
            target: sirenViewRoot.webSocketController ? sirenViewRoot.webSocketController.midiMonitorController : null
            function onMidiDataChanged(note, velocity, bend, channel) {
                siren6.applyMidi(note, velocity, bend, channel)
            }
        }
    }
    
    SirenColumn {
        id: siren7
        sirenController: sirenViewRoot.sirenController
        pedalConfigController: sirenViewRoot.pedalConfigController
        sphereId: 7
        sphereText: "S7"
        position: Qt.vector3d(525, 500, 100)
        inactiveColor: sirenViewRoot.inactiveColor
        sirenSpec: sirenViewRoot.sirenSpecProvider && sirenViewRoot.sirenSpecProvider.spec ? sirenViewRoot.sirenSpecProvider.spec.siren7 : ({})
        
        onKnobValueChanged: function(sirenId, controllerIndex, value) {
            sirenViewRoot.knobValueChanged(sirenViewRoot.selectedPedalId, sirenId, controllerIndex, value)
        }
        
        Component.onCompleted: {
            sirenViewRoot.sirenNodes.push(this);
        }
        Connections {
            target: sirenViewRoot.webSocketController ? sirenViewRoot.webSocketController.midiMonitorController : null
            function onMidiDataChanged(note, velocity, bend, channel) {
                siren7.applyMidi(note, velocity, bend, channel)
            }
        }
    }    
    // Méthodes pour accéder aux sirènes
    function getSiren(sirenId) {
        switch(sirenId) {
            case 1: return siren1;
            case 2: return siren2;
            case 3: return siren3;
            case 4: return siren4;
            case 5: return siren5;
            case 6: return siren6;
            case 7: return siren7;
            default: return null;
        }
    }
    
    // Nouvelle méthode pour définir les valeurs des knobs
    function setKnobValues(pedalId, sirenId, values) {
        let siren = getSiren(sirenId);
        if (siren) {
            for (let i = 0; i < values.length && i < siren.controllerTypes.length; i++) {
                siren.setKnobValue(i, values[i]);
            }
        }
    }
}
