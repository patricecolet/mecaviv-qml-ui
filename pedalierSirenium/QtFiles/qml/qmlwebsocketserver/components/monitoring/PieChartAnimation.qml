import QtQuick
import QtQuick3D

Model {
    id: pieChart
    
    // Propriétés publiques
    property var siren
    property color activeColor: "lime"
    property color inactiveColor: "#333333"
    property color recordingColor: "red"
    property bool running: false
    property real radius: 60
    property bool isRecording: false
    
    // Propriétés de compatibilité avec SegmentAnimation
    property int loopDuration: 2000  // Pour compatibilité avec BeatController
    
    // Propriétés pour la logique interne
    property real internalProgress: 0
    property real currentProgress: 0
    property real lastCurrentBarTime: 0
    property int estimatedBPM: 120
    
    // Progress final (lecture seule)
    property real progress: internalProgress
    
    // Timer simple pour progression fluide
    Timer {
        id: animationTimer
        interval: 16  // 60 FPS
        running: pieChart.running
        repeat: true
        onTriggered: updateProgress()
    }
    
    // Fonction simple et fiable
    function updateProgress() {
        if (!siren || !running || !siren.loopSize) {
            return;
        }
        
        // Fallback si lastCurrentBarTime n'est pas initialisé
        if (lastCurrentBarTime === 0) {
            lastCurrentBarTime = Date.now();
            return;
        }
        
        let currentTime = Date.now();
        let msPerBar = (60000 / estimatedBPM) * 4;
        
        let timeSinceLastBar = currentTime - lastCurrentBarTime;
        let progressInCurrentBar = Math.min(timeSinceLastBar / msPerBar, 1.0);
        
        // CORRECTION : currentBar 1-based → 0-based
        let zeroBasedCurrentBar = (siren.currentBar - 1) % siren.loopSize;
        
        // Progression totale
        let totalProgress = (zeroBasedCurrentBar + progressInCurrentBar) / siren.loopSize;
        
        // Mettre à jour la propriété interne (pas progress directement)
        internalProgress = totalProgress % 1.0;
    }
    
    // Position EXACTE du test qui fonctionnait
    source: "#Rectangle"
    scale: Qt.vector3d(2, 2, 1)  // Même taille que le test
    position: Qt.vector3d(0, 0, 0)  // Même position que le test
    eulerRotation: Qt.vector3d(0, 0, 0)
    
    // Utiliser visualProgress dans le shader au lieu de progress directement
    materials: CustomMaterial {
        shadingMode: CustomMaterial.Shaded
        fragmentShader: "piechartfinal.frag"
        cullMode: Material.NoCulling
        
        property real uProgress: pieChart.progress  // Direct, sans lissage
        property color uActiveColor: pieChart.isRecording ? pieChart.recordingColor : pieChart.activeColor
        property color uInactiveColor: pieChart.inactiveColor
        property bool uIsRecording: pieChart.isRecording
    }
    
    // ========== LOGIQUE BASÉE SUR current_bar ==========
    
    // Watcher pour current_bar de la sirène
    Connections {
        target: siren
        function onCurrentBarChanged() {
            if (running && siren) {
                // updateProgressFromCurrentBar(); // Supprimé
            }
        }
    }
    
    // Simplifier - supprimer la logique complexe
    // Supprimer : lastProgress, revolutionOffset, timer continu
    
    // Fonction pour mettre à jour la progression en continu
    // function updateContinuousProgress() { // Supprimé
    //     if (!siren || !running) return;
    //     
    //     let currentTime = Date.now();
    //     let msPerBar = (60000 / estimatedBPM) * 4;
    //     
    //     // Debug timing
    //     let timeSinceLastBar = currentTime - lastCurrentBarTime;
    //     if (timeSinceLastBar > msPerBar * 2) {
    //         // Supprimé: console.log debug
    //     }
    //     
    //     let progressInCurrentBar = (currentTime - lastCurrentBarTime) / msPerBar;
    //     let totalProgress = totalElapsedBars + progressInCurrentBar;
    //     progress = (totalProgress % siren.loopSize) / siren.loopSize;
    // }
    
    // Écouter les changements de currentBar
    Connections {
        target: siren
        function onCurrentBarChanged() {
            if (siren && running) {
                lastCurrentBarTime = Date.now();
                // Pas de reset, juste mise à jour du timestamp
            }
        }
    }
    
    // Gestionnaire pour mettre à jour isAnimating dans la sirène
    onRunningChanged: {
        // Supprimé: console.log debug
        if (siren) {
            siren.isAnimating = running;
        }
        
        // Initialiser le timestamp quand l'animation démarre
        if (running && lastCurrentBarTime === 0) {
            lastCurrentBarTime = Date.now();
        }
    }

    // ========== FONCTIONS DE CONTRÔLE ==========

    function start() {
        if (!running) {
            internalProgress = 0;  // ← Changer ici aussi
            lastCurrentBarTime = Date.now();
        }
        
        running = true;
        isRecording = false;
        
        // S'assurer que isAnimating est mis à jour
        if (siren) {
            siren.isAnimating = true;
        }
    }

    function stop() {
        running = false;
        internalProgress = 0;  // ← Et ici
        isRecording = false;
        
        // S'assurer que isAnimating est mis à jour
        if (siren) {
            siren.isAnimating = false;
        }
    }
    
    function resetAnimation() {
        // Reset
        running = false;
        // progress = 0; // Supprimé
        isRecording = false;
        
        // Restart
        running = true;
        // updateProgressFromCurrentBar(); // Supprimé
        
        // S'assurer que isAnimating est mis à jour
        if (siren) {
            siren.isAnimating = true;
        }
    }

    function stopAnimation() {
        stop();
    }

    // Fonctions de compatibilité (pour ne pas casser le BeatController)
    function setPosition(relativePosition) {
        // progress = relativePosition; // Supprimé
    }
    
    function updateDuration(newDuration) {
        // Plus nécessaire avec current_bar // Supprimé
    }
    
    // ========== FONCTIONS DE COMPATIBILITÉ AVEC SEGMENTRING ==========
    
    function setSegmentColor(segmentId, color) {
        // Compat: ignorer l'index et flasher rouge si demandé
        if (color === "red") flashRecording();
    }
    
    function pulseSegments(color) {
        if (color === "red") flashRecording();
    }
    
    Timer {
        id: recordingTimer
        interval: 300
        onTriggered: {
            isRecording = false;
        }
    }

    function flashRecording() {
        isRecording = true;
        recordingTimer.restart();
    }
    
    Component.onCompleted: {
        // Supprimé: console.log debug
        if (siren) {
            estimatedBPM = 120; // valeur par défaut
        }
    }
    
    // Debug du scaling
    onScaleChanged: {
        // Supprimé: console.log debug
    }
} 