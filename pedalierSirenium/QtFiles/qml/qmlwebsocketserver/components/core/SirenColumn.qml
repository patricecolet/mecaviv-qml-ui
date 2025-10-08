import QtQuick
import QtQuick3D
import "../../utils" as Utils
import "../controls"
import "../monitoring"
import "../monitoring/midi-display"

Node {
    id: columnContainer
    
    // Propriétés existantes
    property var sirenController
    property int sphereId: 0
    property string sphereText: "Sphere"
    property bool isActive: false
    property bool isCurrent: false
    property bool pedalActive: false
    property int loopSize: 16
    property int revolutionCount: 0
    property color inactiveColor
    property int segmentCount: 48
    property bool isAnimating: false
    property int currentBar: 1
    property real defaultScale: 0.5
    property real selectedScale: 1.2
    property real unselectedScale: 0.7
    
    // Propriétés pour les knobs
    property bool showKnobs: false
    property int selectedPedalId: 1
    property var pedalConfigController
    // Affichage monitoring par sirène (activé hors config et hors mode scènes)
    property bool showMonitoring: true

    // Spécification musicale par sirène (injectée depuis SirenView)
    property var sirenSpec: ({})
    property int bendCenter: 4096
    
    signal knobValueChanged(int sirenId, int controllerIndex, real value)
    
    // Panel de configuration
    PedalConfigPanel {
        id: configPanel
        visible: columnContainer.showKnobs
        x: columnContainer.sphereId === 1 ? -160 : -60
        y: 30   // ← Remonter pour réduire l'espace avec les titres
        
        sirenId: columnContainer.sphereId
        showLabels: columnContainer.sphereId === 1
        
        onKnobValueChanged: function(sirenId, controllerIndex, value) {
            columnContainer.knobValueChanged(sirenId, controllerIndex, value)
        }
    }
    
    // Fonction simple pour mettre à jour les knobs via setValue()
    function updateKnobValues() {
        if (pedalConfigController && configPanel.visible) {
            let values = pedalConfigController.getValuesForSiren(selectedPedalId, sphereId);
            configPanel.setKnobValues(values);
        }
    }
    
    // Connexion pour mettre à jour les knobs 
    Connections {
        target: columnContainer.pedalConfigController
        enabled: columnContainer.pedalConfigController !== null
        
        function onUpdateCounterChanged() {
            columnContainer.updateKnobValues();
        }
    }
    
    // Mettre à jour quand la pédale change
    onSelectedPedalIdChanged: {
        updateKnobValues();
    }
    
    // Initialiser quand on devient visible
    onShowKnobsChanged: {
        if (showKnobs) {
            // Délai pour s'assurer que les knobs sont créés
            Qt.callLater(function() {
                updateKnobValues();
            });
        }
    }
    
    // Titre de la colonne
    Node {
        id: titleNode
        position: Qt.vector3d(0, 50, 0)
        visible: true
        
        Text {
            text: columnContainer.sphereText
            color: columnContainer.isCurrent ? "white" : "#cccccc"
            font.pixelSize: 36
            font.bold: true
            anchors.centerIn: parent
            layer.enabled: true
            layer.smooth: true
        }
    }
    
    // Contenu scalable (sans PieChartAnimation)
    Node {
        id: scalableContent
        visible: !columnContainer.showKnobs
        
        scale: Qt.vector3d(
            columnContainer.isActive ? 
                (columnContainer.isCurrent ? columnContainer.selectedScale : columnContainer.unselectedScale) : 
                columnContainer.defaultScale,
            columnContainer.isActive ? 
                (columnContainer.isCurrent ? columnContainer.selectedScale : columnContainer.unselectedScale) : 
                columnContainer.defaultScale,
            columnContainer.isActive ? 
                (columnContainer.isCurrent ? columnContainer.selectedScale : columnContainer.unselectedScale) : 
                columnContainer.defaultScale
        )
        
        SphereSet {
            id: sphereSet
            isActive: columnContainer.isActive
            isCurrent: columnContainer.isCurrent
            pedalActive: columnContainer.pedalActive
            inactiveColor: columnContainer.inactiveColor
        }
        
        RevolutionCounter3D {
            id: revolutionCounter
            position: Qt.vector3d(0, -200, 0)
            value: columnContainer.revolutionCount
            digitCount: 2
            digitSpacing: 30
        }
        
        RevolutionCounter3D {
            id: barCounter
            
            // Position dynamique pour compenser le scaling et laisser place au pieChart
            position: Qt.vector3d(
                0, 
                columnContainer.isCurrent ? 
                    0 :           // Position normale quand sélectionné
                    -40,          // Descendre un peu quand pas sélectionné (place pour pieChart)
                0
            )
            
            value: columnContainer.currentBar
            digitCount: 2
            digitSpacing: 30
            activeColor: columnContainer.isCurrent ? "#ffd500" : "#888888"
            scale: Qt.vector3d(0.7, 0.7, 0.7)
        }

        // Panneau de monitoring MIDI par sirène (minimal pour placement)
        SirenChannelMonitor3D {
            id: sirenMonitorPanel
            visible: columnContainer.showMonitoring && !columnContainer.showKnobs
            sirenId: columnContainer.sphereId
            channel: columnContainer.sphereId - 1
            // spec injectée plus tard via provider global; pour l’instant nulle
            position: Qt.vector3d(0, -330, 0)
            // Rétablir les proportions du panneau (pas d'étirement Y)
            scale: Qt.vector3d(0.2, 0.4, 0.2)
            // Appliquer spec et centre de bend
            spec: columnContainer.sirenSpec
            bendCenter: columnContainer.bendCenter
            accent: (columnContainer.sirenSpec && columnContainer.sirenSpec.color) ? columnContainer.sirenSpec.color : "#FFFFFF"
        }
    }
    
    // PieChart avec le MÊME zoom que scalableContent mais indépendant
    PieChartAnimation {
        id: pieChartDisplay
        siren: columnContainer
        inactiveColor: columnContainer.inactiveColor
        activeColor: "lime"
        recordingColor: "red"
        visible: !columnContainer.showKnobs
        
        // Position dynamique selon l'état
        position: columnContainer.isCurrent ? 
            Qt.vector3d(0, -115, 0) :  // Autour de la sphère si sélectionnée
            Qt.vector3d(0, -20, 0)       // Autour du currentBar sinon
        
        // Scaling personnalisé (plus grand que les autres composants)
        scale: Qt.vector3d(
            columnContainer.isActive ? 
                (columnContainer.isCurrent ? columnContainer.selectedScale * 1.7 : columnContainer.unselectedScale * 1.3) : 
                columnContainer.defaultScale * 1.2,
            columnContainer.isActive ? 
                (columnContainer.isCurrent ? columnContainer.selectedScale * 1.7 : columnContainer.unselectedScale * 1.3) : 
                columnContainer.defaultScale * 1.2,
            columnContainer.isActive ? 
                (columnContainer.isCurrent ? columnContainer.selectedScale * 1.7 : columnContainer.unselectedScale * 1.3) : 
                columnContainer.defaultScale * 1.2
        )
    }

    // Fonction pour que BeatController puisse contrôler cette animation
    function getPieChartAnimation() {
        return pieChartDisplay;
    }

// Fonctions existantes
function setActive(active) {
    columnContainer.isActive = active;
}

function setCurrent(current) {
    columnContainer.isCurrent = current;
}

function incrementRevolutionCount() {
    revolutionCount++;
    if (logger) logger.debug("ANIMATION", "Nouvelle révolution pour sirène", sphereId);
    if (sirenController) {
        sirenController.ensureSegmentAnimationContinues(sphereId);
    }
}

function startAnimation() {
    if (!isAnimating) {
        isAnimating = true;
        if (sirenController) {
            sirenController.ensureSegmentAnimationContinues(sphereId);
        }
    }
}

function stopAnimation() {
    if (isAnimating) {
        isAnimating = false;
    }
}

function restoreAnimation() {
    if (sirenController) {
        let hasAnimation = sirenController.hasSegmentAnimation(sphereId);
        if (hasAnimation) {
            sirenController.resetSegmentAnimation(sphereId);
            isAnimating = true;
        }
    }
}

function resetSegmentAnimations() {
    if (sirenController) {
        sirenController.resetSegmentAnimation(sphereId);
    }
}

function resetRevolutionCount() {
    revolutionCount = 0;
}

function setRevolutionCount(count) {
    if (count !== undefined && count !== null && !isNaN(Number(count))) {
        revolutionCount = count;
    } else {
        if (logger) logger.warn("ANIMATION", "SirenColumn: Tentative d'assigner une valeur invalide à revolutionCount:", count);
        revolutionCount = 0;
    }
}

function pulseSphere(isFirstBeat, duration) {
    sphereSet.pulseSphere(isFirstBeat, duration);
}

function pulseSegments(color) {
    pieChartDisplay.pulseSegments(color);
}

function setSegmentColor(segmentId, color) {
    pieChartDisplay.setSegmentColor(segmentId, color);
}

// MIDI live pour le panneau de cette sirène
function applyMidi(note, velocity, bend, channel) {
    if (channel !== (sphereId - 1)) return;
    sirenMonitorPanel.note = note;
    sirenMonitorPanel.velocity = velocity;
    sirenMonitorPanel.bend = bend;
}
}
