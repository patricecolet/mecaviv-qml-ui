import QtQuick

QtObject {
    id: scoringEngine
    
    // Propriétés de scoring
    property int score: 0
    property int combo: 0
    property int maxCombo: 0
    property real accuracy: 0.0  // 0.0-1.0
    
    // Compteurs
    property int perfectCount: 0
    property int goodCount: 0
    property int missCount: 0
    property int totalNotes: 0
    
    // État du jeu
    property bool gameActive: false
    property int gameStartTime: 0
    
    // Signaux pour recevoir les événements
    signal noteStart(int note, int timestamp)
    signal noteEnd(int note, int timestamp)
    signal controlChange(int ccNumber, int ccValue)
    
    // Signaux pour notifier les changements
    signal scoreChanged(int newScore)
    signal comboChanged(int newCombo)
    signal accuracyChanged(real newAccuracy)
    signal noteHit(string rating, int points)  // rating: "perfect", "good", "miss"
    
    // Méthodes publiques
    function startGame() {
        gameActive = true;
        gameStartTime = Date.now();
        resetScore();
    }
    
    function stopGame() {
        gameActive = false;
    }
    
    function resetScore() {
        score = 0;
        combo = 0;
        maxCombo = 0;
        accuracy = 0.0;
        perfectCount = 0;
        goodCount = 0;
        missCount = 0;
        totalNotes = 0;
    }
    
    // Logique de scoring (à implémenter)
    function evaluateNoteHit(expectedNote, actualNote, timingMs) {
        if (!gameActive) return;
        
        totalNotes++;
        
        // Tolérance timing (en ms)
        var perfectWindow = 50;   // ±50ms = Perfect
        var goodWindow = 150;     // ±150ms = Good
        
        var absTiming = Math.abs(timingMs);
        var noteDiff = Math.abs(expectedNote - actualNote);
        
        var rating = "";
        var points = 0;
        
        // Évaluation simple (à affiner)
        if (noteDiff === 0 && absTiming < perfectWindow) {
            rating = "perfect";
            points = 100;
            perfectCount++;
            combo++;
        } else if (noteDiff <= 1 && absTiming < goodWindow) {
            rating = "good";
            points = 50;
            goodCount++;
            combo++;
        } else {
            rating = "miss";
            points = 0;
            missCount++;
            combo = 0;
        }
        
        // Mise à jour du score
        score += points * (1 + combo * 0.1);  // Bonus combo
        if (combo > maxCombo) {
            maxCombo = combo;
        }
        
        // Calcul précision
        if (totalNotes > 0) {
            accuracy = (perfectCount + goodCount * 0.5) / totalNotes;
        }
        
        // Émettre les signaux
        scoreChanged(score);
        comboChanged(combo);
        accuracyChanged(accuracy);
        noteHit(rating, points);
    }
    
    // Connexions aux événements MIDI
    Component.onCompleted: {
        noteStart.connect(function(note, timestamp) {
            // À implémenter: stocker les notes attendues
        });
        
        noteEnd.connect(function(note, timestamp) {
            // À implémenter: évaluer le timing
        });
        
        controlChange.connect(function(ccNumber, ccValue) {
            // À implémenter: gérer les modulations
        });
    }
}


